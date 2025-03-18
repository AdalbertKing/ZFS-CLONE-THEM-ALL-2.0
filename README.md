 # SnapSend & DelSnap - Advanced ZFS Snapshot Management
 
 ## Author
 **Wojciech Król** (lurk@lurk.com.pl) with contributions from **DeepSeek R1** and **ChatGPT**
 
 **Script Version: 2.7**
 
 ---
 
 ## Overview
 **SnapSend (`snapsend.sh`)** automates the creation and synchronization of **ZFS snapshots** between hosts in a **Proxmox Cluster**.
 
 **DelSnap (`delsnaps.sh`)** manages the cleanup of outdated snapshots based on predefined time retention policies.
 
 Together with a configured **cron job**, they create a powerful, automated snapshot management system.
 
 ---
 
 ## System Modes
 
 SnapSend operates in multiple modes depending on the use case:
 
 1. **only.snapshot** - Creates a local snapshot without sending it anywhere.
 2. **local.backup** - Creates a local snapshot and sends it to a secondary local dataset for redundancy.
 3. **remote.synchro** - Creates a local snapshot and synchronizes it to a remote server.
 4. **remote.backup** - Synchronizes existing snapshots from a primary node to a backup node.
 
 Each mode can be tailored with specific options to enhance backup flexibility and reliability.
 
 ---
 
 ## Use Case: Proxmox Cluster Setup
 
 - Two nodes: `pve1` and `pve2`.
 - `pve1` stores VM datasets.
 - `pve2` serves as a **backup node** with an **HDD storage** (`hdd/backups`).
 - `snapsend.sh` synchronizes **snapshots** from `pve1` to `pve2`.
 - `delsnaps.sh` ensures old snapshots are automatically **pruned**.
 
 ---
 
 ## snapsend.sh - ZFS Snapshot Management
 
 ### Usage
 ```bash
 snapsend.sh [options] <source_datasets> <target_dataset>
 ```
 
 ### Options
 - `-m <name>`: Prefix for snapshot name (e.g., `automated_`).
 - `-e`       : Enable **external replication** to another node.
 - `-z`       : Enable **ZFS send** with compression.
 - `-v <num>` : Verbosity level (1-3, where 3 is the most detailed output).
 - `-r`       : Recursive mode, applies to all child datasets.
 - `-n`       : Dry run, does not perform actual changes, but prints intended actions.
 
 ### Example
 Backup synchronized snapshots from `pve1` to `pve2`:
 ```bash
 snapsend.sh -m automated_ -e -z -v 3 rpool/data/vm100-disk-0 hdd/backups
 ```
 
 ---
 
 ## Practical Use of `-n` (Dry Run) for Troubleshooting
 
 The `-n` option is extremely useful for debugging and ensuring the correct snapshots will be deleted or synchronized before executing real changes.
 
 ### Example: Checking problematic snapshots (Remote Mode)
 ```bash
 ./snapsend.sh -n -e -r rpool/test 192.168.11.11: | sort -u | xargs -I{} ssh 192.168.11.11 "zfs destroy {}"
 ```
 
 **Explanation:**
 1. `-n` ensures that the script only prints the list of snapshots that would be sent.
 2. `-e -r rpool/test 192.168.11.11:` lists snapshots intended for the remote node.
 3. `sort -u` removes duplicate entries from the list.
 4. `xargs -I{} ssh 192.168.11.11 "zfs destroy {}"` executes a **remote snapshot deletion** on `192.168.11.11`.
 
 This method is useful when removing outdated or orphaned snapshots on remote backup nodes.
 
 ---
 
 ## delsnaps.sh - ZFS Snapshot Cleanup
 
 ### Usage
 ```bash
 delsnaps.sh [options] <dataset_pattern>
 ```
 
 ### Options
 - `-R <datasets>`: Comma-separated list of datasets to clean.
 - `-h <hours>`  : Remove snapshots older than X **hours**.
 - `-d <days>`   : Remove snapshots older than X **days**.
 - `-w <weeks>`  : Remove snapshots older than X **weeks**.
 - `-m <months>` : Remove snapshots older than X **months**.
 
 ### Example
 Remove **hourly** snapshots older than **24 hours** from multiple datasets:
 ```bash
 delsnaps.sh -R hdd/backup,hdd/kopie,hdd/lxc automated_hourly -h24
 ```
 
 ---
 
 ## CRON Configuration
 
 **Example entries from `cron.txt`:**
 
 **Snapshot Creation & Synchronization**
 ```cron
 59 * * * * /root/scripts/snapsend.sh -m automated_ -e -z -v 3 rpool/data/vm100-disk-0 hdd/backups 2>>/root/scripts/cron.log
 ```
 
 **Snapshot Cleanup**
 ```cron
 49 * * * * /root/scripts/delsnaps.sh -R hdd/backup,hdd/kopie,hdd/lxc automated_hourly -h24 2>>/root/scripts/cron.log
 ```
 
 ---
 
 ## Summary
 - `snapsend.sh` automates **ZFS snapshot replication**.
 - `delsnaps.sh` manages **snapshot expiration**.
 - Together with **cron**, they form a complete **snapshot lifecycle system**.
 - The `-n` dry-run mode helps to debug and troubleshoot snapshots before applying changes.
 
 **This setup ensures automated, secure, and efficient snapshot management in a Proxmox Cluster.**
