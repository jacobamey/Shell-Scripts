# System Information Gathering Script

This script (`basic-info.sh`) is a modernized and robust tool for gathering a comprehensive snapshot of a Linux system's configuration and current state. It produces a well-formatted text report that is useful for diagnostics, inventory, and troubleshooting.

## Table of Contents

- Features
- Prerequisites
- Usage
- Example Output
- Customization

## Features

*   **Comprehensive Data:** Gathers a wide range of system information, including:
    *   System and OS release details
    *   Uptime and kernel log (`dmesg`)
    *   CPU information
    *   Memory usage
    *   Disk space and block device layout
    *   Full network configuration (IP addresses, routes, listening sockets)
    *   Top 10 CPU and Memory consuming processes
    *   Status of key system services (e.g., `sshd`, `httpd`, `nginx`)
*   **Modern & Portable:** Uses modern Linux commands like `ip` and `ss` for better compatibility across different distributions.
*   **Automatic Dependency Installation:** If run as root, it can automatically install missing utility packages (`util-linux`, `iproute2`) using `apt`, `dnf`, or `yum`.
*   **Robust and Safe:**
    *   Includes a root check to safely handle package installations.
    *   Fails gracefully with warnings if commands are missing and it cannot install them.
    *   Avoids the use of `eval` for safer command execution.
*   **User-Friendly Output:**
    *   Generates a clean, well-structured report with clear section headers.
    *   Saves the report to a timestamped file in `/tmp` by default.
    *   Optional `--color` flag to generate a report with ANSI color codes for better readability in terminals.
    *   Allows specifying a custom output file path.

## Prerequisites

*   A Linux system with a `bash` shell.
*   Standard system utilities (like `uname`, `cat`, `df`, `ps`, etc.).
*   Root privileges are required for the script to automatically install any missing dependencies. If not run as root, the script will still function but will skip sections where a required command is not already installed.

## Usage

1.  Make the script executable:
    ```bash
    chmod +x basic-info.sh
    ```

2.  Run the script.

    **As a regular user (without auto-install):**
    ```bash
    ./basic-info.sh
    ```
    This will generate a report in `/tmp/system-info-HOSTNAME-TIMESTAMP.txt`.

    **As root (to enable auto-install of dependencies):**
    ```bash
    sudo ./basic-info.sh
    ```

3.  **Specify a custom output file:**
    You can provide a file path as the first argument to save the report to a specific location.
    ```bash
    ./basic-info.sh /home/user/reports/my-server-snapshot.txt
    ```
4.  **Generate a report with color:**
    Use the `--color` flag to embed ANSI color codes in the report.
    ```bash
    sudo ./basic-info.sh --color
    ```
    You can then view the colorized report in your terminal with `cat` or `less -R`:
    ```bash
    cat /tmp/system-info-$(hostname)*.txt
    ```

## Example Output

The generated report file will look similar to this:

```text
System Information Report for my-server on Tue Oct 27 15:30:00 UTC 2023

================================================================================
=== System Information (uname -a)
================================================================================
Linux my-server 5.4.0-122-generic #138-Ubuntu SMP Wed Jun 22 15:00:31 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux

================================================================================
=== OS Release Information
================================================================================
NAME="Ubuntu"
VERSION="20.04.5 LTS (Focal Fossa)"
...

================================================================================
=== CPU Information
================================================================================
Architecture:                    x86_64
CPU op-mode(s):                  32-bit, 64-bit
...

... (and so on for all other sections)
```

## Customization

You can easily customize the script by editing the following sections:

*   **Services to Check:** Modify the `services_to_check` array in the script to add or remove system services you want to monitor.
    ```bash
    services_to_check=("sshd" "nginx" "docker" "my-custom-app")
    ```
*   **Default Output Location:** Change the `DEFAULT_OUTPUT_FILE` variable if you prefer a different default directory or naming convention for the reports.