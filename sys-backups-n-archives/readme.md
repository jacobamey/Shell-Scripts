2.  **MySQL Server:** A running MySQL instance.
3.  **MySQL Client Utilities:** `mysql` and `mysqladmin` commands must be available in the system's PATH.
4.  **`getopt`:** For robust command-line argument parsing (usually pre-installed).
5.  **`logger`:** For sending output to syslog (usually pre-installed).
6.  **`tar` and `gzip`:** For archiving and compression (usually pre-installed).
7.  **Root Privileges:** The script must be run as `root` to manage LVM snapshots and mount points.
8.  **MySQL User Privileges:** The MySQL user used for backup must have at least the `RELOAD` privilege (for `FLUSH TABLES WITH READ LOCK`) and `SELECT` privilege on `information_schema` to determine the `datadir`.
## MySQL LVM Snapshot Backup Script

This script provides a robust and reliable method for backing up MySQL databases using LVM (Logical Volume Manager) snapshots. It's designed to minimize downtime by creating a consistent snapshot of the MySQL data directory, then archiving it, ensuring data integrity.

## Table of Contents

- Features
- Prerequisites
- Installation
- Configuration
- Usage
- Cron Job Example
- Security Considerations
- Error Handling & Logging
- Cleanup Mechanism

## Features

*   **LVM Snapshot-based Backup:** Creates a consistent point-in-time backup of the MySQL data directory without extended downtime.
*   **Robust Error Handling:** Uses `set -eo pipefail` and comprehensive checks to ensure script exits on failure.
*   **Secure Credential Handling:** Recommends and supports MySQL option files (`~/.my.cnf`) for credentials, avoiding hardcoded passwords.
*   **Configurable via File or CLI:** Allows customization of backup destination, temporary mount point, and snapshot size percentage through a dedicated configuration file or command-line arguments.
*   **Dynamic LVM Sizing:** Automatically determines the LVM volume and calculates a reasonable snapshot size based on a configurable percentage.
*   **Automated Cleanup:** Ensures LVM snapshots are unmounted and removed, and MySQL tables are unlocked, even if the script encounters an error.
*   **Backup Integrity Verification:** Performs a `gzip -t` check on the created archive to confirm it's not corrupt.
*   **Timestamped Backups:** Generates unique backup filenames with timestamps for easy organization and management.
*   **Centralized Logging:** All script output is directed to `syslog` for easy monitoring and auditing.
*   **Privilege Check:** Verifies that the MySQL user has the necessary `RELOAD` privilege for `FLUSH TABLES WITH READ LOCK`.

## Prerequisites

Before running this script, ensure the following are in place:

1.  **LVM (Logical Volume Manager):** Your MySQL data directory (`datadir`) **must** reside on an LVM logical volume.
2.  **MySQL Server:** A running MySQL instance.
3.  **MySQL Client Utilities:** `mysql` and `mysqladmin` commands must be available in the system's PATH.
4.  **`getopt`:** For robust command-line argument parsing (usually pre-installed).
5.  **`logger`:** For sending output to syslog (usually pre-installed).
6.  **`tar` and `gzip`:** For archiving and compression (usually pre-installed).
7.  **Root Privileges:** The script must be run as `root` to manage LVM snapshots and mount points.
8.  **MySQL User Privileges:** The MySQL user used for backup must have at least the `RELOAD` privilege (for `FLUSH TABLES WITH READ LOCK`) and `SELECT` privilege on `information_schema` to determine the `datadir`.

## Installation

1.  **Place the script:** Save the script to a suitable location, e.g., `/usr/local/bin/lvm-mysql-backup.sh`.
    ```bash
    sudo cp lvm-mysql-backup.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/lvm-mysql-backup.sh
    ```
2.  **Create a configuration file (optional but recommended):**
    Create `/etc/mysql-lvm-backup.conf` with your desired settings. This avoids passing sensitive information or long paths on the command line.
    ```bash
    sudo nano /etc/mysql-lvm-backup.conf
    ```
    Example content:
    ```bash
    # /etc/mysql-lvm-backup.conf
    
    # Destination for backup files
    dstdir="/mnt/backups/mysql"
    
    # Temporary mount point for the LVM snapshot
    tmpmountpoint="/mnt/mysql_snapshot_temp"
    
    # Percentage of the LV size to allocate for the snapshot (e.g., 20 for 20%)
    snap_percent=20
    
    # MySQL user (highly recommended to use ~/.my.cnf instead)
    # user="backup_user"
    ```
3.  **Set up MySQL Credentials (Highly Recommended):**
    Create a `.my.cnf` file in the home directory of the user that will run the script (e.g., `/root/.my.cnf` if running as root via cron).
    ```bash
    sudo nano /root/.my.cnf
    ```
    Example content:
    ```ini
    [client]
    user=backup_user
    password=your_secret_password
    ```
    Ensure proper permissions:
    ```bash
    sudo chmod 600 /root/.my.cnf
    ```

## Configuration

The script can be configured using:

1.  **Configuration File:** `/etc/mysql-lvm-backup.conf` (or specified with `-c`). Variables set here are sourced first.
2.  **Command-line Arguments:** Overwrite values from the configuration file.

| Option            | Long Option      | Description                                                              | Default Value (if not in config) |
| :---------------- | :--------------- | :----------------------------------------------------------------------- | :------------------------------- |
| `-d <DIR>`        | `--dest <DIR>`   | Destination directory for backups.                                       | `/backups/mysql`                 |
| `-t <DIR>`        | `--temp-mount <DIR>` | Temporary mount point for the LVM snapshot.                              | `/mnt/mysql_snapshot`            |
| `-u <NAME>`       | `--user <NAME>`  | MySQL user for login.                                                    | (empty)                          |
| `-p <PASS>`       | `--password <PASS>` | MySQL password. **Avoid using on CLI for security reasons.**             | (empty)                          |
|                   | `--snap-percent <NUM>` | Percentage of LV size to use for the snapshot (e.g., `20` for 20%).      | `20`                             |
| `-c <FILE>`       | `--config <FILE>` | Path to an alternative configuration file.                               | `/etc/mysql-lvm-backup.conf`     |
| `-h`              | `--help`         | Display usage information and exit.                                      |                                  |

## Usage

Run the script as root:

```bash
sudo /usr/local/bin/lvm-mysql-backup.sh
```

Using command-line arguments:

```bash
sudo /usr/local/bin/lvm-mysql-backup.sh --dest /var/backups/mysql --snap-percent 25
```

Using a custom configuration file:

```bash
sudo /usr/local/bin/lvm-mysql-backup.sh --config /path/to/my_custom_backup.conf
```

## Cron Job Example

To automate daily backups and clean up old ones (e.g., older than 7 days), you can set up a cron job.

Edit the root user's crontab:

```bash
sudo crontab -e
```

Add the following lines. This example runs the backup daily at 2:00 AM and then cleans up backups older than 7 days.

```cron
# Daily MySQL LVM Backup at 2:00 AM
0 2 * * * /usr/local/bin/lvm-mysql-backup.sh

# Clean up MySQL backups older than 7 days (run daily at 2:30 AM)
30 2 * * * find /mnt/backups/mysql -name "mysql-backup-*.tar.gz" -mtime +7 -delete
```

## Security Considerations

*   **MySQL Credentials:** Always use a `.my.cnf` file with `chmod 600` permissions for storing MySQL credentials. Avoid passing passwords directly on the command line.
*   **Root Access:** The script requires root privileges. Ensure it is only executable by trusted users and that its configuration is secure.
*   **Backup Storage:** Secure your backup destination (`dstdir`) with appropriate file system permissions and consider encrypting backups if they contain sensitive data.

## Error Handling & Logging

The script uses `set -eo pipefail` to ensure that it exits immediately if any command fails. All output (including errors) is directed to `syslog` under the tag `mysql-lvm-backup`. You can monitor its execution using:

```bash
journalctl -t mysql-lvm-backup -f
```

## Cleanup Mechanism

A `trap cleanup EXIT` is used to guarantee that the LVM snapshot is unmounted and removed, and MySQL tables are unlocked, regardless of whether the script completes successfully or exits due to an error. This prevents resource leaks and ensures the database returns to a normal state.
