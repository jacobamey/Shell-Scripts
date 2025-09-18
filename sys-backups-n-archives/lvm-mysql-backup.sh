#!/bin/bash
#
# Name: lvm-mysql-backup.sh
# Description: Does a backup of your MySQL Database utilizng LVM Snapshot.
# Script Maintainer: Jacob Amey 
#
# Created: August 8th 2013 (Original)
# Last Updated: September 18th 2025 (Modernized)
##################################################

set -eo pipefail

##################################################
# Configuration
#
CONFIG_FILE="/etc/mysql-lvm-backup.conf"
LOG_TAG="mysql-lvm-backup"

##################################################
# Variables
#
user="" # Can be set in config file
password="" # Can be set in config file
tmpmountpoint="/mnt/mysql_snapshot" # Default, can be overridden by config
dstdir="/backups/mysql" # Default, can be overridden by config
snap_percent=20 # Default, can be overridden by config

# Load configuration file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

# Redirect stdout and stderr to syslog via logger
exec 1> >(logger -t "$LOG_TAG")
exec 2> >(logger -t "$LOG_TAG" -p user.error)

echo "--- Starting MySQL LVM Backup ---"

##################################################
# Usage Options
#
usage () {
  # Send usage info to standard output, not syslog
  exec 1>&2
  cat >&2 <<EOF
Usage: $0 [OPTIONS]

Options:
  -d, --dest DIR        Destination directory for backups.
                        Default: ${dstdir}
  -t, --temp-mount DIR  Temporary mount point for the snapshot.
                        Default: ${tmpmountpoint}
  -u, --user NAME       MySQL user. Overrides config file.
  -p, --password PASS   MySQL password. Overrides config file. Avoid on CLI.
  --snap-percent NUM    Percentage of LV size to use for snapshot.
                        Default: ${snap_percent}
  -c, --config FILE     Path to a configuration file.
                        Default: ${CONFIG_FILE}
  -h, --help            Display this help and exit.

It is highly recommended to use a ~/.my.cnf file for credentials:
[client]
user=backup_user
password=your_secret_password
EOF
  exit 1 # Default exit code for usage is 1
}
##################################################
# Argument Parsing
#
OPTS=$(getopt -o u:p:d:t:c:h --long user:,password:,dest:,temp-mount:,snap-percent:,config:,help -n "$0" -- "$@")
if [ $? != 0 ]; then echo "Failed parsing options." >&2; usage; fi
eval set -- "$OPTS"

while true; do
  case "$1" in
    -u | --user )       user="$2"; shift 2 ;;
    -p | --password )   password="$2"; shift 2 ;;
    -d | --dest )       dstdir="$2"; shift 2 ;;
    -t | --temp-mount ) tmpmountpoint="$2"; shift 2 ;;
    -c | --config )
      if [[ -f "$2" ]]; then
        # shellcheck source=/dev/null
        source "$2"
      fi
      shift 2 ;;
    --snap-percent )    snap_percent="$2"; shift 2 ;;
    -h | --help )       usage ;;
    -- )                shift; break ;;
    * )                 break ;;
  esac
done

##################################################
# Initial checks
#
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root to manage LVM and mounts." >&2
  exit 1
fi

mkdir -p "$dstdir"
if [ ! -d "$dstdir" ]; then
  echo "Error: Destination directory '$dstdir' could not be created or is not a directory." >&2
  exit 1
fi

mkdir -p "$tmpmountpoint"
if [ ! -d "$tmpmountpoint" ]; then
  echo "Error: Temporary mount point '$tmpmountpoint' could not be created or is not a directory." >&2
  exit 1
fi

if mount | grep -q " on ${tmpmountpoint} "; then
  echo "Error: Temporary mount point '$tmpmountpoint' is already in use." >&2
  exit 1
fi

MYSQL_OPTS=""
[[ -n "$user" ]] && MYSQL_OPTS+=" --user=${user}"
[[ -n "$password" ]] && MYSQL_OPTS+=" --password=${password}"

echo "Verifying MySQL user has RELOAD privilege for FLUSH TABLES..."
privileges=$(mysql ${MYSQL_OPTS} -sN -e "SHOW GRANTS FOR CURRENT_USER();")
if ! (echo "$privileges" | grep -q -E "ALL PRIVILEGES ON \*\.\*|RELOAD"); then
    echo "Error: The MySQL user requires the global RELOAD privilege to execute 'FLUSH TABLES WITH READ LOCK'." >&2
    exit 1
fi
echo "RELOAD privilege confirmed."


##################################################
# Get Mysql data directory
#
echo "Fetching MySQL data directory..."
datadir=$(mysql ${MYSQL_OPTS} -Ns -e "show global variables like 'datadir'" | awk '{print $2}')
datadir=${datadir%/} # Remove trailing slash
if [ -z "$datadir" ]; then
  echo "Error: Could not determine MySQL data directory. Check MySQL connection and permissions." >&2
  exit 1
fi
echo "MySQL data directory is '$datadir'"

##################################################
# Get snap name and size
#
echo "Determining LVM volume for snapshot..."
device=$(df --output=source "$datadir" | tail -n 1)
if ! lvs "$device" >/dev/null 2>&1; then
    echo "Error: MySQL data directory '$datadir' is not on an LVM logical volume." >&2
    exit 1
fi

vg=$(lvs --noheadings -o vg_name "$device" | xargs)
lv=$(lvs --noheadings -o lv_name "$device" | xargs)
snap="mysql-snap-$(date +%s)"

# Calculate snapshot size.
lv_size_gb=$(lvs --noheadings --units g -o lv_size "$device" | sed 's/g//' | cut -d. -f1)
snapsize=$(( (lv_size_gb * snap_percent) / 100 ))
if [ "$snapsize" -lt 1 ]; then
    snapsize=1
fi
snapsize_g="${snapsize}G"

echo "Found LV '$lv' in VG '$vg'. Snapshot will be '$snap' with size ${snapsize_g}."

cleanup() {
  local exit_status=${1:-$?}
  echo "--- Running cleanup ---"
  # If the script is exiting on an error, try to unlock tables
  if [[ "$exit_status" -ne 0 ]]; then
    echo "Unlocking tables due to script exit..."
    mysql ${MYSQL_OPTS} -e "UNLOCK TABLES;" || echo "Failed to unlock tables, they may not have been locked."
  fi
  if mount | grep -q " on ${tmpmountpoint} "; then
    echo "Unmounting snapshot from $tmpmountpoint..."
    umount "$tmpmountpoint"
  fi
  if lvs "/dev/$vg/$snap" >/dev/null 2>&1; then
    echo "Removing LVM snapshot /dev/$vg/$snap..."
    lvremove -f "/dev/$vg/$snap"
  fi
  echo "--- Cleanup finished ---"
}

# Trap EXIT signal to ensure cleanup runs on any exit
trap cleanup EXIT

##################################################
# Backup
#
echo "Locking databases and creating snapshot..."
mysql ${MYSQL_OPTS} << EOF
FLUSH TABLES WITH READ LOCK;
system lvcreate --snapshot -n $snap -L$snapsize_g /dev/$vg/$lv;
UNLOCK TABLES;
EOF
echo "Databases unlocked, snapshot created."

##################################################
# Perfrom the backup.
#
echo "Mounting snapshot..."
mount /dev/$vg/$snap $tmpmountpoint

backup_file="$dstdir/mysql-backup-$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
echo "Backing up databases to $backup_file"
tar -C "$tmpmountpoint" -czf "$backup_file" .

echo "Verifying backup integrity..."
if gzip -t "$backup_file"; then
  echo "Backup verification successful."
else
  echo "Error: Backup verification FAILED for $backup_file. The file may be corrupt." >&2
  # The script will exit here because of 'set -e', but we could also add a notification.
  # The failed backup file will be left for manual inspection.
  exit 1
fi

echo "Backup of '$datadir' successfully created at $backup_file"
echo "--- MySQL LVM Backup Finished ---"

exit 0
##################################################
