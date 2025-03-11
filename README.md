# ZFS Advanced Snapshot Manager v2.4
**Author**: Wojciech Król & DeepSeek-R1 | **Last Update**: 2024-09-16  
**Key Innovation**: Smart incremental transfers (-I) with conflict detection

-----------------------------------------
## snapsend.sh - Core Features
-----------------------------------------
- 🚀 **Adaptive Transfer Modes**  
  - Automatically uses `zfs send -I` when common snapshot exists  
  - Falls back to full send (`zfs send -c`) when no base snapshot  
  - Validates timestamps with 120s tolerance window

- 🔍 **Deep Inspection**  
  - Recursive child dataset verification (-r)  
  - Multi-level conflict detection:  
    - Name collisions  
    - Timestamp mismatches  
    - Orphaned child datasets

- 🛡️ **Safety Mechanisms**  
  - Dry-run mode (-n) for pre-flight checks  
  - Buffered transfers (mbuffer)  
  - SSH compression (-C) + pigz pipeline (-z)

-----------------------------------------
## Options Reference
-----------------------------------------

### Main Parameters
| Flag | Argument      | Operational Impact                  |
|------|---------------|-------------------------------------|
| `-m` | TEXT          | Snapshot prefix (e.g., "hourly_")    |
| `-e` | -             | Reuse last matching snapshot        |
| `-z` | -             | Enable pigz compression             |
| `-l` | 1-9           | Compression ratio (default:6)       |
| `-v` | 0-3           | Verbosity: 0=silent, 3=debug        |
| `-r` | -             | Recursive child processing          |
| `-n` | -             | Simulation mode (no writes)         |

### Advanced Network
| Parameter         | Format                  | Example                    |
|-------------------|-------------------------|----------------------------|
| Remote Target     | [user@]host:[dataset]    | `backup@192.168.1.10:backup_pool` |
| SSH Port          | Edit PORT variable      | `PORT=2222` in script       |

-----------------------------------------
## Usage Scenarios
-----------------------------------------

### 1. Initial Seed Transfer (Full)
```bash
./snapsend.sh -v3 -m INITIAL -z -r hdd/prod_db backup@192.168.1.100:
```
**Behavior**:  
- Creates `hdd/prod_db@INITIAL_<timestamp>`  
- Compressed full send to remote pool  
- Verifies dataset structure recursively

### 2. Incremental Update (-I)
```bash
./snapsend.sh -e -r -m HOURLY hdd/prod_db backup@192.168.1.100:
```
**Optimizations**:  
- Finds last common snapshot automatically  
- Sends only changed blocks since last sync  
- Reuses existing "HOURLY_" snapshots

### 3. Disaster Recovery Check
```bash
./snapsend.sh -n -v3 -r hdd/prod_db backup@192.168.1.100:
```
**Output**:  
- Lists all conflicting snapshots  
- Verifies transfer parameters  
- Zero write operations

### 4. Local Snapshot Only
```bash
./snapsend.sh -m DAILY -r hdd/important_data
```
**Result**:  
- Creates `hdd/important_data@DAILY_<timestamp>`  
- Recursively snapshots child datasets  
- No transfer performed

### 5. Bandwidth-Optimized Transfer
```bash
./snapsend.sh -z -l3 -m LOW_BW -r hdd/vms user@vpn-host:
```
**Tuning**:  
- Uses faster gzip level 3  
- Combines SSH + pigz compression  
- mbuffer prevents pipe stalls

-----------------------------------------
## delsnaps.sh - Precision Cleanup
-----------------------------------------

### Key Features
- ⏳ **Temporal Granularity**: Mix years/months/weeks/days/hours
- 🧹 **Pattern Matching**: Regex-compatible snapshot filter
- 🧠 **Safety Checks**:  
  - Confirms creation dates  
  - Dry-run capability (-n)  
  - Child dataset protection

### Usage Examples
```bash
# Delete non-recursive older than 6mo
./delsnaps.sh hdd/temp_snapshots "temp_" -m6

# Nuclear option - recursive 2y+
./delsnaps.sh -R hdd/archive "bak_" -y2 -m0 -w1

# Emergency space reclaim
./delsnaps.sh -R rpool/data "emergency_" -h48```

-----------------------------------------
## Technical Notes
-----------------------------------------
- **Incremental Logic**:  
  ```bash
  if [ "$common_snapshot" != "null" ]; then
    zfs send -I ${common}@snap...
  else
    zfs send -c...
  fi
  ```
- **Conflict Types**:  
  1. Orphaned snapshots (exist only on target)  
  2. Timestamp drift >120s  
  3. Name collisions with different contents

> 💡 **Pro Tip**: Combine `-e` and `-m` to maintain consistent  
> snapshot chains for reliable incrementals!