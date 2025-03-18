 # SnapSend & DelSnap - Advanced ZFS Snapshot Management
 
 ## Author
 **Wojciech Król** (lurk@lurk.com.pl) with contributions from **DeepSeek R1** and **ChatGPT**
 
 **Script Version: 2.7**
 
 ---
 
 ## Overview
 **SnapSend (`snapsend.sh`)** automates the creation and synchronization of **ZFS snapshots** between hosts ex.: in a **Proxmox Cluster**.
 
 **DelSnap (`delsnaps.sh`)** manages the cleanup of outdated snapshots based on predefined time retention policies.
 
 Together with a configured **cron job**, they create a powerful, automated snapshot management system.
 
 ---
 
 ## System Modes
 
 SnapSend operates in multiple modes depending on the use case:
 
 1. **only.snapshot** - Creates a local snapshot without sending it anywhere.
 2. **local.backup** - Creates a local snapshot and sends it to a secondary local dataset for redundancy.
 3. **remote.synchro** - Creates a local snapshot and synchronizes it to a remote server.
 4. **remote.backup** - Creates a local snapshot and sends it to a secondary node into remote dataset.
 
 Each mode can be tailored with specific options to enhance backup flexibility and reliability.
 
 ---
 
 ## Use Case: Proxmox Cluster Setup
 
 - Two nodes: `pve1` and `pve2`.
 - `pve1` stores VM datasets.
 - `pve2` additionaly serves as a **backup node** with an **HDD storage** (`hdd/backups`).
 - `snapsend.sh` backups **snapshots** synchronized between `pve1` nad `pve2` by corosync into backup dataset on pve2.
 - `delsnaps.sh` ensures old snapshots are automatically **pruned**.
 
 ---
 
 ## snapsend.sh - ZFS Snapshot Management
 
 ### Usage
 ```bash
 snapsend.sh [options] <source_datasets> <target_dataset>
 ```
 
 ### Options
 - `-m <name>`: Prefix for snapshot name (e.g., `automated_hourly`).
 - `-e`       : Process last snapshot without creating new. Importand in second node in Proxmox Cluster
 - `-z`       : Enable **ZFS send** with compression.
 - `-v <num>` : Verbosity level (1-4, where 4 is the most detailed output).
 - `-r`       : Recursive mode, applies to all child datasets, but requires careful handling as child datasets may inherit unwanted snapshots.
 - `-n`       : Dry run, does not perform actual changes, but prints intended actions.
 - `-I`       : Sends all snapshots between snapshot points, not only last. Important in full mode sent.
 - `-F`       : Forces full synchronization if incremental replication is not possible.
 
 ### Automatic Timestamping and Naming
 
 SnapSend automatically generates snapshots with a **timestamp** (YYYY-MM-DD_HH-MM-SS) to facilitate easier management.
 Example snapshot name with default mask:
 ```
 rpool/data@automated_2025-03-18_12-45-00
 ```
 
 **Example Usage:**
 ```bash
 snapsend.sh -m automated_ -e -I -F -z -v 3 rpool/data hdd/backups
 ```
 
 This ensures that **incremental snapshots** are sent whenever possible (`-I`), and if they fail, a full backup is forced (`-F`).
 
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
 59 * * * * /root/scripts/snapsend.sh -m automated_ -e -I -F -z -v 3 rpool/data/vm100-disk-0 hdd/backups 2>>/root/scripts/cron.log
 ```
 
 **Snapshot Cleanup**
 ```cron
 49 * * * * /root/scripts/delsnaps.sh -R hdd/backup,hdd/kopie,hdd/lxc automated_hourly -h24 2>>/root/scripts/cron.log
 ```
 
 ---
 
 ## Summary
 - `snapsend.sh` automates **ZFS snapshot replication**, ensuring timestamps for proper sorting.
 - `delsnaps.sh` manages **snapshot expiration**.
 - Together with **cron**, they form a complete **snapshot lifecycle system**.
 - The `-n` dry-run mode helps to debug and troubleshoot snapshots before applying changes.
 - Recursive mode (`-r`) requires special handling to avoid inheriting unwanted child datasets.
 - The combination of `-I` (incremental) and `-F` (force full) ensures robust backup strategies.
 
 **This setup ensures automated, secure, and efficient snapshot management in a Proxmox Cluster.**
