#!/bin/bash
#
# Modernized version of basic-info.sh
#
# - Gathers a more comprehensive set of system information.
# - Formats output for readability.
# - Uses modern commands like 'ip' and 'ss'.
# - Allows the output file to be specified as an argument.
# - Includes error handling and basic checks.
#
##################################################
# Name: basic-info.sh
# Description: Grabs basic info about the server
# Script Maintainer: Jacob Amey
#
# Last Updated: July 9th 2013 (Original)
##################################################

set -euo pipefail

# --- Configuration ---

# Use the first argument as the output file, or default to a timestamped file in /tmp.
DEFAULT_OUTPUT_FILE="/tmp/system-info-$(hostname)-$(date +%Y%m%d_%H%M%S).txt"
OUTPUT_FILE="${1:-$DEFAULT_OUTPUT_FILE}"

# --- Color Codes ---
COLOR_HEADER=""
COLOR_RESET=""

# --- Functions ---

# Function to write a formatted section header to the output file.
write_header() {
    local title="$1"
    {
        printf "\n"
        printf "${COLOR_HEADER}================================================================================${COLOR_RESET}\n"
        printf "${COLOR_HEADER}=== ${title}${COLOR_RESET}\n"
        printf "${COLOR_HEADER}================================================================================${COLOR_RESET}\n"
    } >> "$OUTPUT_FILE"
}

# Function to run a command and append its output to the file.
run_command() {
    local title="$1"
    # All subsequent arguments are treated as the command and its arguments.
    shift
    
    write_header "$title"
    # The `|| true` prevents the script from exiting if a command fails (e.g., a tool isn't installed).
    # The error message will still be captured in the output file.
    "$@" >> "$OUTPUT_FILE" 2>&1 || true
}

# --- Main Script ---

# Simple argument check for color
if [[ "${1:-}" == "--color" || "${2:-}" == "--color" ]]; then
    # If --color is the first arg, shift it and use the default output file.
    if [[ "${1:-}" == "--color" ]]; then
        shift
        OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
    fi
    # If --color is the second arg, shift it. The first arg is already the output file.
    if [[ "${2:-}" == "--color" ]]; then
        shift
    fi
    COLOR_HEADER=$'\e[1;34m' # Bold Blue
    COLOR_RESET=$'\e[0m'
fi

# Check for root privileges early, as they are needed for package installation.
if [ "$(id -u)" -ne 0 ]; then
    IS_ROOT=false
else
    IS_ROOT=true
fi
# Ensure we can write to the output file by creating it.
echo "System Information Report for $(hostname) on $(date)" > "$OUTPUT_FILE" || {
    echo "Error: Unable to write to output file '$OUTPUT_FILE'." >&2
    exit 1
}

# Redirect informational messages to stderr, so stdout can be used for other purposes if needed.
echo "Starting system information gathering..." >&2

# --- Dependency Installation ---

# Function to install packages if a command is missing.
install_if_missing() {
    local cmd_to_check="$1"
    local package_to_install="$2"
    
    if ! command -v "$cmd_to_check" &> /dev/null; then
        if [ "$IS_ROOT" = true ]; then
            echo "Command '$cmd_to_check' not found. Attempting to install package '$package_to_install'..." >&2
            if command -v apt-get &> /dev/null; then
                apt-get update && apt-get install -y "$package_to_install"
            elif command -v dnf &> /dev/null; then
                dnf install -y "$package_to_install"
            elif command -v yum &> /dev/null; then
                yum install -y "$package_to_install"
            else
                echo "Warning: Could not find a known package manager (apt, dnf, yum) to install '$package_to_install'." >&2
            fi
        else
            echo "Warning: Command '$cmd_to_check' not found, and not running as root to install. Skipping." >&2
            return # Skip the check if not root and command is missing
        fi

        if ! command -v "$cmd_to_check" &> /dev/null; then
            echo "Error: Failed to install '$cmd_to_check' via package '$package_to_install'." >&2
            exit 1 # Exit if installation fails
        fi
        echo "Successfully installed '$package_to_install'." >&2
    fi
}

# Check for required commands before starting
install_if_missing lscpu util-linux
install_if_missing lsblk util-linux
install_if_missing ss iproute2

# 1. System & OS Information
run_command "System Information (uname -a)" uname -a
run_command "OS Release Information" cat /etc/*-release
run_command "Uptime" uptime
run_command "Kernel Log (dmesg - last 50 lines)" sh -c "dmesg | tail -n 50"

# 2. CPU Information
run_command "CPU Information" lscpu

# 3. Memory Usage
run_command "Memory Usage (free -h)" free -h

# 4. Disk Usage
run_command "Filesystem Disk Space Usage (df -hT)" df -hT
run_command "Block Device Information (lsblk)" lsblk

# 5. Network Configuration
run_command "IP Address Information (ip addr)" ip addr
run_command "Routing Table (ip route)" ip route
run_command "Listening Sockets (ss -tulpn)" ss -tulpn

# 6. Process Information
run_command "Top 10 CPU Consuming Processes" sh -c "ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 11"
run_command "Top 10 Memory Consuming Processes" sh -c "ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 11"

# 7. Service Status (for systemd-based systems)
if command -v systemctl &> /dev/null; then
    # Add any other services you want to monitor to this list
    services_to_check=("sshd" "httpd" "apache2" "nginx" "mysqld" "mariadb" "postgresql" "cron" "crond")
    run_command "Key Service Status (systemctl)" sh -c "for service in ${services_to_check[*]}; do systemctl status \"\$service\" 2>/dev/null || true; done"
fi

echo "System information report generation complete." >&2
echo "Report saved to: $OUTPUT_FILE"
