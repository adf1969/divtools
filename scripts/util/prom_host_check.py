#!/usr/bin/env python3

import argparse
import socket
import os
import sys
import datetime

# Default configurations
DIVTOOLS = os.getenv("DIVTOOLS", "/opt/divtools")
HOST_FILE = f"{DIVTOOLS}/config/monitor/prom_hosts.txt"
PROM_OUT_FILE = f"{DIVTOOLS}/config/monitor/prom_out.yml"
NODE_SCRAPE_INT = "15s"
CADV_SCRAPE_INT = "10s"
DEBUG_MODE = False  # Default: No debug output unless -d is used

# ANSI color codes
COLORS = {
    "DEBUG": "\033[37m",  # White
    "INFO": "\033[34m",   # Blue
    "WARNING": "\033[33m",  # Yellow
    "CRITICAL": "\033[31m",  # Red
    "RESET": "\033[0m"
}

# ANSI color codes for status output
STATUS_COLORS = {
    "BOTH_RUNNING": "\033[32m",   # Green
    "ONE_RUNNING": "\033[33m",    # Yellow
    "NONE_RUNNING": "\033[31m",   # Red
    "RESET": "\033[0m"
}

# Function to determine color based on service availability
def get_status_color(node, cadv):
    if node == "Y" and cadv == "Y":
        return STATUS_COLORS["BOTH_RUNNING"]
    elif node == "Y" or cadv == "Y":
        return STATUS_COLORS["ONE_RUNNING"]
    else:
        return STATUS_COLORS["NONE_RUNNING"]

# Function for logging with timestamp and color-coded output
def log(level, message, function_name=""):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_msg = f"{COLORS[level]}[{timestamp}] {level} - {function_name}: {message}{COLORS['RESET']}"

    if level == "CRITICAL":
        print(log_msg, file=sys.stderr)
        sys.exit(1)
    elif DEBUG_MODE or level == "CRITICAL":  # Only show non-critical logs if debug mode is enabled
        print(log_msg)

# Function to check if a port is open on a given IP
def is_port_open(ip, port):
    function_name = "is_port_open"
    try:
        log("DEBUG", f"Checking {ip}:{port}", function_name)
        with socket.create_connection((ip, port), timeout=2):
            log("INFO", f"Port {port} is OPEN on {ip}", function_name)
            return True
    except (socket.timeout, ConnectionRefusedError):
        log("WARNING", f"Port {port} is CLOSED on {ip}", function_name)
    except OSError as e:
        log("WARNING", f"Failed to connect to {ip}:{port} - {str(e)}", function_name)
    except socket.gaierror:
        log("WARNING", f"Invalid IP or hostname: {ip}", function_name)
    
    return False  # Port is considered closed on failure


# Function to parse host file, ignoring comments and inline comments
def parse_host_file(file_path):
    function_name = "parse_host_file"
    hosts = []
    try:
        log("DEBUG", f"Reading host file: {file_path}", function_name)
        with open(file_path, "r") as file:
            for line in file:
                line = line.strip()

                # Ignore empty lines and full-line comments
                if not line or line.startswith("#"):
                    continue
                
                # Remove inline comments (anything after #)
                if "#" in line:
                    line = line.split("#", 1)[0].strip()

                # Extract name and IP
                if ":" in line:
                    name, ip = line.split(":", 1)
                    hosts.append((name.strip(), ip.strip()))
                    log("INFO", f"Loaded host: {name} -> {ip}", function_name)

    except FileNotFoundError:
        log("CRITICAL", f"Host file '{file_path}' not found.", function_name)
    return hosts

# Function to generate Prometheus scrape_configs
def generate_prometheus_config(hosts, prom_out_file, node_scrape_int, cadv_scrape_int):
    function_name = "generate_prometheus_config"
    log("DEBUG", f"Generating Prometheus config at {prom_out_file}", function_name)
    
    node_configs = []
    cadvisor_configs = []

    for name, ip in hosts:
        if is_port_open(ip, 9100):
            node_configs.append(f"""
      - targets: 
          - "{ip}:9100"
        labels:
          instance: "{name}" """)
        if is_port_open(ip, 8082):
            cadvisor_configs.append(f"""
      - targets: 
          - "{ip}:8082"
        labels:
          instance: "{name}" """)

    config_content = f"""scrape_configs: 
  # Node Exporter Hosts
  - job_name: "node" 
    scrape_interval: {node_scrape_int}
    static_configs: {''.join(node_configs) if node_configs else '[]'}

  # cAdvisor Hosts
  - job_name: "cadvisor"
    scrape_interval: {cadv_scrape_int}
    static_configs: {''.join(cadvisor_configs) if cadvisor_configs else '[]'}
"""

    try:
        with open(prom_out_file, "w") as file:
            file.write(config_content.strip())
        log("INFO", f"Prometheus config written to {prom_out_file}", function_name)
    except Exception as e:
        log("CRITICAL", f"Failed to write Prometheus config: {str(e)}", function_name)

# Main function
def main():
    global DEBUG_MODE

    parser = argparse.ArgumentParser(description="Check Node Exporter and cAdvisor on hosts.")
    parser.add_argument("-db", type=str, help="Override host file")
    parser.add_argument("-po", type=str, help="Override Prometheus output file")
    parser.add_argument("-q", action="store_true", help="Quiet mode (No console output, only updates Prometheus file)")
    parser.add_argument("-t", action="store_true", help="Test mode (No updates to Prometheus file)")
    parser.add_argument("-d", action="store_true", help="Enable debug mode")

    args = parser.parse_args()
    DEBUG_MODE = args.d  # Enable debug mode if -d is passed

    host_file = args.db if args.db else HOST_FILE
    prom_out_file = args.po if args.po else PROM_OUT_FILE

    log("DEBUG", "Starting script execution", "main")
    log("DEBUG", f"Using host file: {host_file}", "main")
    log("DEBUG", f"Using Prometheus output file: {prom_out_file}", "main")

    hosts = parse_host_file(host_file)

    results = []
    for name, ip in hosts:
        node_status = "Y" if is_port_open(ip, 9100) else "N"
        cadv_status = "Y" if is_port_open(ip, 8082) else "N"
        
        # Determine the color for output
        status_color = get_status_color(node_status, cadv_status)
        
        # Format the result line
        result_line = f"{status_color}{name}:{ip}: Node={node_status}, cAdv={cadv_status}{STATUS_COLORS['RESET']}"
        
        results.append(result_line)

    # Print results unless in quiet mode
    if not args.q:
        for result in results:
            print(result)

    # Write to Prometheus file unless in test mode
    if not args.t:
        generate_prometheus_config(hosts, prom_out_file, NODE_SCRAPE_INT, CADV_SCRAPE_INT)

    log("DEBUG", "Script execution completed", "main")

if __name__ == "__main__":
    main()
