#!/bin/bash
# snapsend.sh v3.0
# Smart ZFS Snapshot Transfer with Adaptive Compression
# Author: Wojciech Król (lurk@lurk.com.pl) with DeepSeek-R1

###############################################################################
# GLOBAL CONFIGURATION
###############################################################################
MESSAGE=""
VERBOSE=0
COMPRESSION_MODE="auto"       # auto/zfs/pigz/none
COMPRESSION_LEVEL=6           # 1-9 (pigz only)
BUFFER_SIZE="128k"            # mbuffer settings
MEMORY="1G"
PORT=22
RECURSIVE=0
DRY_RUN=0
UNMOUNT=0
FORCE_FULL_SEND=0

###############################################################################
# HELPER FUNCTIONS
###############################################################################
log() {
    [ "$VERBOSE" -ge "$1" ] && shift && echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
}

die() {
    log 0 "ERROR: $*"
    exit 1
}

validate_remote_host() {
    local remote="$1"
    [ -z "$remote" ] && return 0

    local local_host=$(hostname -f)
    local remote_host=$(ssh -o StrictHostKeyChecking=no -p "$PORT" "$remote" "hostname -f" 2>/dev/null)
    
    if [ "$local_host" = "$remote_host" ]; then
        die "Remote host matches local ($local_host). Use local mode instead."
    fi
}

###############################################################################
# CORE FUNCTIONS
###############################################################################
create_snapshot() {
    local dataset="$1"
    local snapname="${dataset}@${MESSAGE}$(date '+%Y%m%d-%H%M%S')"
    local flags=""

    [ $RECURSIVE -eq 1 ] && flags="-r"
    
    log 1 "Creating snapshot: $snapname"
    zfs snapshot $flags "$snapname" || die "Snapshot creation failed"
    echo "$snapname"
}

build_compression_pipeline() {
    local dataset="$1"
    local remote="$2"
    
    local zfs_comp=$(zfs get -H -o value compression "$dataset" 2>/dev/null)
    local compress_cmd=""
    local decompress_cmd=""

    case "$COMPRESSION_MODE" in
        "auto")
            if [[ "$zfs_comp" =~ (lz4|zstd) ]]; then
                log 2 "Using ZFS-native compression ($zfs_comp)"
                ZFS_FLAGS="-c"
            elif [ -n "$remote" ]; then
                log 2 "Enabling pigz compression for remote transfer"
                compress_cmd=" | pigz -$COMPRESSION_LEVEL"
                decompress_cmd="pigz -d | "
            fi
            ;;
        "zfs")
            ZFS_FLAGS="-c"
            ;;
        "pigz")
            compress_cmd=" | pigz -$COMPRESSION_LEVEL"
            decompress_cmd="pigz -d | "
            ;;
        "none")
            ;;
        *)
            die "Invalid compression mode: $COMPRESSION_MODE"
    esac

    echo "$compress_cmd||$decompress_cmd"
}

transfer_data() {
    local src_snap="$1"
    local tgt="$2"
    
    IFS='|' read -r compress_pipe decompress_pipe <<< "$(build_compression_pipeline "${src_snap%%@*}" "$tgt")"
    
    # Build base command
    local send_cmd="zfs send $ZFS_FLAGS $src_snap"
    local recv_cmd="${decompress_pipe}zfs recv -F ${UNMOUNT:+-u} ${RECURSIVE:+-s} ${tgt#*:}"
    
    # Add compression and buffering
    send_cmd+="$compress_pipe | mbuffer -q -s $BUFFER_SIZE -m $MEMORY"
    
    # Remote transfer handling
    if [[ "$tgt" == *":"* ]]; then
        validate_remote_host "${tgt%:*}"
        send_cmd+=" | ssh -o Compression=no -p $PORT ${tgt%:*} 'mbuffer -q -s $BUFFER_SIZE -m $MEMORY | $recv_cmd'"
    else
        send_cmd+=" | mbuffer -q -s $BUFFER_SIZE -m $MEMORY | $recv_cmd"
    fi

    log 2 "Executing: $send_cmd"
    eval "$send_cmd" || die "Transfer failed"
}

###############################################################################
# MAIN EXECUTION
###############################################################################
while getopts "m:C:l:v:rnuf" opt; do
    case $opt in
        m) MESSAGE="$OPTARG" ;;
        C) COMPRESSION_MODE="$OPTARG" ;;
        l) COMPRESSION_LEVEL="$OPTARG" ;;
        v) VERBOSE="$OPTARG" ;;
        r) RECURSIVE=1 ;;
        n) DRY_RUN=1 ;;
        u) UNMOUNT=1 ;;
        f) FORCE_FULL_SEND=1 ;;
        *) die "Invalid option: -$OPTARG" ;;
    esac
done
shift $((OPTIND-1))

[ $# -ge 1 ] || die "Usage: $0 [options] source_dataset [user@host:target]"

# Parse source and target
src_dataset="$1"
remote_target="${2:-}"
tgt_dataset="${remote_target#*:}"
remote_host="${remote_target%:*}"

# Create new snapshot
snapshot=$(create_snapshot "$src_dataset")

# Dry-run mode
if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY RUN] Would transfer: $snapshot -> ${remote_target:-local}"
    echo "Command: $(build_compression_pipeline "$src_dataset" "$remote_host")"
    exit 0
fi

# Perform actual transfer
transfer_data "$snapshot" "$remote_target"

log 0 "Operation completed successfully"
exit 0