#!/usr/bin/env python3
"""
Samba Active Directory Domain Controller Native Installation Script (Python)
Last Updated: 01/15/2026 8:30:00 PM CST

This script provides an interactive TUI-based menu for:
- Native Samba Installation: Installs samba directly on Ubuntu host
- Domain Provisioning: Creates AD domain with samba-tool
- DNS Configuration: Updates host DNS settings  
- Health Checks: Verifies domain functionality
- Service Management: Start/stop/restart samba services

Environment variables are managed in /opt/ads-native/.env.ads
with markers for easy updates (like dt_host_setup.sh does)

Logging:
- All activity logged to /opt/ads-native/logs/dt_ads_native-TIMESTAMP.log
- Log level based on --debug, -v, -vv flags (DEBUG vs INFO)
- Fully timestamped with local timezone
- Menu selections clearly identified

NOTE: This script should be invoked via the dt_ads_native.sh wrapper script,
which sets up the DIVTOOLS environment variable and calls this script with the
correct Python interpreter from the dtpyutil venv.
"""

import sys
import os
import argparse
import subprocess
from pathlib import Path
from datetime import datetime
import shutil
import socket
import json
import tempfile

# Set up path to import dtpyutil (installed in the dtpyutil venv)
# DIVTOOLS should be set by the wrapper script, but default to /home/divix/divtools
DIVTOOLS = os.getenv('DIVTOOLS', '/home/divix/divtools')
DTPYUTIL_PROJECT = Path(DIVTOOLS) / 'projects' / 'dtpyutil'
DTPYUTIL_SRC = DTPYUTIL_PROJECT / 'src'

# Add dtpyutil to sys.path so we can import it
if DTPYUTIL_SRC.exists():
    sys.path.insert(0, str(DTPYUTIL_SRC))

# Import the DtpMenuApp for menu operations
try:
    from dtpyutil.menu.dtpmenu import DtpMenuApp
except ImportError as e:
    print(f"ERROR: Could not import dtpyutil.menu.dtpmenu")
    print(f"  Expected location: {DTPYUTIL_SRC / 'dtpyutil' / 'menu' / 'dtpmenu.py'}")
    print(f"  Error: {e}")
    sys.exit(1)


class ADSNativeApp:
    """Main ADS Native Setup Application"""
    
    def __init__(self, test_mode=False, debug_mode=False, verbose=0):
        self.test_mode = test_mode
        self.debug_mode = debug_mode
        self.verbose = verbose
        
        # Configuration
        self.divtools = Path(os.getenv('DIVTOOLS', '/home/divix/divtools'))
        self.config_dir = Path('/opt/ads-native')
        self.env_file = self.config_dir / '.env.ads'
        self.data_dir = Path('/var/lib/samba')
        self.config_samba_dir = Path('/etc/samba')
        self.log_dir = self.config_dir / 'logs'
        
        # Environment variable markers
        self.env_marker_start = "# >>> DT_ADS_NATIVE AUTO-MANAGED - DO NOT EDIT MANUALLY <<<"
        self.env_marker_end = "# <<< DT_ADS_NATIVE AUTO-MANAGED <<<"
        
        # Initialize logging
        self.log_file = None
        self.init_logging()
        
        # Load environment variables
        self.env_vars = {}
        self.load_ads_env_vars()
        
    def init_logging(self):
        """Initialize logging system"""
        # Create log directory
        self.log_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate log filename with timestamp
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        self.log_file = self.log_dir / f'dt_ads_native-{timestamp}.log'
        
        self.log("HEAD", "================================")
        self.log("HEAD", "ADS Native Setup Script Started")
        self.log("HEAD", "================================")
        self.log("INFO", f"Log file: {self.log_file}")
        self.log("DEBUG", f"Test Mode: {self.test_mode}")
        self.log("DEBUG", f"Debug Mode: {self.debug_mode}")
        self.log("DEBUG", f"Verbose Level: {self.verbose}")
        self.log("DEBUG", f"Current Directory: {os.getcwd()}")
        self.log("DEBUG", f"User: {os.getenv('USER')}")
        self.log("INFO", "Script execution started")
        
    def log(self, level, message):
        """Log a message with timestamp and level"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # Skip DEBUG messages unless debug mode is on
        if level == "DEBUG" and not self.debug_mode:
            return
            
        log_msg = f"[{timestamp}] [{level}] {message}"
        
        # Color codes for terminal output
        colors = {
            'DEBUG': '\033[37m',    # White
            'INFO': '\033[36m',     # Cyan
            'WARN': '\033[33m',     # Yellow
            'ERROR': '\033[31m',    # Red
            'HEAD': '\033[32m',     # Green
        }
        
        reset = '\033[0m'
        color = colors.get(level, '')
        
        # Print to console with color
        print(f"{color}{log_msg}{reset}")
        
        # Write to log file without color
        if self.log_file:
            with open(self.log_file, 'a') as f:
                f.write(log_msg + '\n')
                
    def load_ads_env_vars(self):
        """
        Load ADS-specific environment variables from .env.ads and divtools config files.
        
        This method loads from:
        1. divtools standard locations (via load_divtools_env_files)
        2. Local .env.ads file (ADS-specific overrides)
        
        This ensures environment variables are always current, including updates
        made by the Configure Environment Variables menu option.
        """
        # First, load from divtools standard locations
        try:
            from dtpyutil.env import load_divtools_env_files
            divtools_vars, failed_files = load_divtools_env_files(debug=self.debug_mode)
            self.env_vars.update(divtools_vars)
            self.log("DEBUG", f"Loaded environment variables from divtools config files")
            if failed_files and self.debug_mode:
                for key, path in failed_files.items():
                    self.log("DEBUG", f"  (optional file not found: {path})")
        except Exception as e:
            self.log("DEBUG", f"Could not load divtools env files: {e}")
        
        # Then, load ADS-specific overrides from .env.ads
        if not self.env_file.exists():
            self.log("DEBUG", f"No existing ADS environment file found at {self.env_file}")
            return
            
        self.log("DEBUG", f"Loading ADS environment variables from {self.env_file}")
        
        with open(self.env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('export '):
                    # Parse export VAR="value"
                    parts = line[7:].split('=', 1)
                    if len(parts) == 2:
                        key = parts[0].strip()
                        value = parts[1].strip().strip('"')
                        self.env_vars[key] = value
                        
        self.log("DEBUG", f"Loaded: REALM={self.env_vars.get('REALM', 'N/A')}, DOMAIN={self.env_vars.get('DOMAIN', 'N/A')}")
        
    def save_env_vars(self, realm, domain, workgroup, admin_pass, host_ip):
        """Save environment variables with markers (divtools style)"""
        self.log("INFO", f"Saving ADS environment variables to {self.env_file}")
        
        # Create directory if it doesn't exist
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Backup existing file if it exists
        if self.env_file.exists():
            self.backup_file(self.env_file)
            
        # Remove old auto-managed section if it exists
        if self.env_file.exists():
            with open(self.env_file, 'r') as f:
                content = f.read()
            
            # Remove section between markers
            start_idx = content.find(self.env_marker_start)
            if start_idx != -1:
                end_idx = content.find(self.env_marker_end)
                if end_idx != -1:
                    content = content[:start_idx] + content[end_idx + len(self.env_marker_end):]
                    with open(self.env_file, 'w') as f:
                        f.write(content)
                        
        # Append new section
        timestamp = datetime.now().strftime('%m/%d/%Y %I:%M:%S %p %Z')
        env_content = f"""
{self.env_marker_start}
# Samba AD DC Native Configuration
# Last Updated: {timestamp}
export REALM="{realm}"
export DOMAIN="{domain}"
export WORKGROUP="{workgroup}"
export ADMIN_PASSWORD="{admin_pass}"
export HOST_IP="{host_ip}"
export SERVER_ROLE="dc"
export DOMAIN_LEVEL="2008_R2"
export LOG_LEVEL="1"
{self.env_marker_end}
"""
        
        with open(self.env_file, 'a') as f:
            f.write(env_content)
            
        # Set permissions to 600
        os.chmod(self.env_file, 0o600)
        self.log("DEBUG", f"Set permissions 600 on {self.env_file}")
        self.log("INFO", "ADS environment variables saved successfully")
        
    def backup_file(self, file_path):
        """Backup a file before overwriting"""
        if not Path(file_path).exists():
            self.log("DEBUG", f"File {file_path} does not exist - no backup needed")
            return None
            
        backup_date = datetime.now().strftime('%Y-%m-%d')
        backup_path = f"{file_path}.{backup_date}"
        
        # If backup already exists for today, append timestamp
        if Path(backup_path).exists():
            backup_date = datetime.now().strftime('%Y-%m-%d-%H%M%S')
            backup_path = f"{file_path}.{backup_date}"
            
        self.log("DEBUG", f"Creating backup: {backup_path}")
        shutil.copy2(file_path, backup_path)
        self.log("INFO", f"Backed up existing file to: {Path(backup_path).name}")
        return backup_path
        
    def run_command(self, cmd, check=True, capture_output=True):
        """Execute shell command"""
        if isinstance(cmd, str):
            cmd_str = cmd
            shell = True
        else:
            cmd_str = ' '.join(cmd)
            shell = False
            
        self.log("DEBUG", f"Running command: {cmd_str}")
        
        if self.test_mode:
            self.log("INFO", f"[TEST] Would run: {cmd_str}")
            return subprocess.CompletedProcess(cmd, 0, "", "")
            
        try:
            result = subprocess.run(
                cmd,
                shell=shell,
                capture_output=capture_output,
                text=True,
                check=check
            )
            return result
        except subprocess.CalledProcessError as e:
            self.log("ERROR", f"Command failed: {cmd_str}")
            self.log("ERROR", f"Exit code: {e.returncode}")
            if e.stdout:
                self.log("ERROR", f"Stdout: {e.stdout}")
            if e.stderr:
                self.log("ERROR", f"Stderr: {e.stderr}")
            raise
            
    def prompt_env_vars(self):
        """Prompt for environment variables using TUI dialogs"""
        self.log("HEAD", "=== Configure Environment Variables ===")
        self.log("INFO", "[MENU SELECTION] Environment Variables Configuration initiated")
        
        # Prompt for each variable with existing value as default
        realm = self.inputbox(
            title="Realm",
            prompt="Enter realm in uppercase (e.g., AVCTN.LAN)",
            default=self.env_vars.get('REALM', 'AVCTN.LAN')
        )
        if realm is None:
            self.log("DEBUG", "User cancelled at realm prompt")
            return False
            
        domain = self.inputbox(
            title="Domain Name",
            prompt="Enter domain name (e.g., avctn.lan)",
            default=self.env_vars.get('DOMAIN', 'avctn.lan'),
        )
        if domain is None:
            self.log("DEBUG", "User cancelled at domain prompt")
            return False
            
        workgroup = self.inputbox(
            title="Workgroup",
            prompt="Enter NetBIOS workgroup name (e.g., AVCTN)",
            default=self.env_vars.get('WORKGROUP', 'AVCTN'),
        )
        if workgroup is None:
            self.log("DEBUG", "User cancelled at workgroup prompt")
            return False
            
        admin_pass = self.inputbox(
            title="Administrator Password",
            prompt="Enter administrator password",
            default=self.env_vars.get('ADMIN_PASSWORD', ''),
        )
        if admin_pass is None:
            self.log("DEBUG", "User cancelled at password prompt")
            return False
            
        host_ip = self.inputbox(
            title="Host IP Address",
            prompt="Enter the server's IP address (e.g., 10.1.1.98)",
            default=self.env_vars.get('HOST_IP', '10.1.1.98'),
        )
        if host_ip is None:
            self.log("DEBUG", "User cancelled at host IP prompt")
            return False
            
        # Display summary and get confirmation
        summary = f"""The following configuration will be saved:

═══ Domain Configuration ═══
Realm:           {realm}
Domain:          {domain}
Workgroup:       {workgroup}

═══ Network Configuration ═══
Host IP:         {host_ip}

═══ Credentials ═══
Admin Password:  {admin_pass[:3]}****** ({len(admin_pass)} chars)

═══ File Location ═══
Config File:     {self.env_file}

Do you want to proceed with saving these settings?"""
        
        if not self.yesno(
            title="Confirm Configuration",
            question=summary
        ):
            self.log("DEBUG", "User declined to save environment variables")
            return False
            
        # Save the configuration
        self.log("INFO", "User confirmed - saving environment variables")
        
        if self.test_mode:
            self.log("INFO", f"[TEST] Would save environment variables to {self.env_file}")
            self.msgbox(
                title="Test Mode",
                text="Configuration save simulated.\\n\\n(No actual changes made)",
            )
            return True
            
        try:
            self.save_env_vars(realm, domain, workgroup, admin_pass, host_ip)
            self.msgbox(
                title="Configuration Saved",
                text=f"Environment variables saved successfully to:\\n{self.env_file}\\n\\nPermissions set to 600 (owner read/write only)",
            )
            return True
        except Exception as e:
            self.log("ERROR", f"Failed to save environment variables: {e}")
            self.msgbox(
                title="Save Failed",
                text=f"Failed to save environment variables.\\n\\nCheck logs for details.",
            )
            return False
            
    def check_env_vars(self):
        """Check/View current environment variables"""
        self.log("HEAD", "=== Check Environment Variables ===")
        self.log("INFO", "[MENU SELECTION] Environment Variables Check initiated")
        
        # Reload env vars
        self.load_ads_env_vars()
        
        if not self.env_file.exists():
            self.msgbox(
                title="No Configuration",
                text=f"No environment variables have been configured yet.\\n\\nFile: {self.env_file}\\n\\nRun Option 2 to configure environment variables first.",
            )
            return
            
        # Build summary
        summary = "═══ Current Environment Variables ═══\\n\\n"
        
        for var_name in ['REALM', 'DOMAIN', 'WORKGROUP', 'ADMIN_PASSWORD', 'HOST_IP']:
            value = self.env_vars.get(var_name)
            if value:
                if var_name == 'ADMIN_PASSWORD':
                    display_val = f"{value[:3]}****** ({len(value)} chars)"
                else:
                    display_val = value
                summary += f"{var_name:20} {display_val}\\n"
            else:
                summary += f"{var_name:20} [NOT SET]\\n"
                
        summary += f"\\n═══ File Information ═══\\n"
        summary += f"Config File:        {self.env_file}\\n"
        
        try:
            file_size = self.env_file.stat().st_size
            summary += f"File Size:          {file_size} bytes"
        except:
            summary += f"File Size:          N/A"
            
        self.log("INFO", "Current environment variables displayed to user")
        
        # Display the summary to user
        self.msgbox(
            title="Environment Variables",
            text=summary
        )
        
    def check_samba_installed(self):
        """Check if Samba is installed"""
        self.log("INFO", "Checking if Samba is installed...")
        
        result = self.run_command("command -v samba-tool", check=False)
        if result.returncode == 0:
            version_result = self.run_command("samba-tool --version", check=False)
            version = version_result.stdout.strip().split('\n')[0] if version_result.returncode == 0 else "unknown"
            self.log("INFO", f"✓ Samba is installed: {version}")
            return True
        else:
            self.log("WARN", "✗ Samba is not installed")
            return False
            
    def install_samba(self):
        """Install Samba packages"""
        self.log("HEAD", "=== Install Samba Native ===")
        self.log("INFO", "[MENU SELECTION] Samba Installation initiated")
        
        # Check if already installed
        if self.check_samba_installed():
            if not self.yesno(
                title="Samba Already Installed",
                prompt="Samba is already installed on this system.\\n\\nReinstall anyway?",
            ):
                self.log("DEBUG", "User declined reinstallation")
                return
                
        # Confirm installation
        install_msg = """This will install the following packages:
    
• samba (AD DC, file sharing)
• samba-dsdb-modules (Directory database)
• samba-vfs-modules (Virtual file system)
• krb5-user (Kerberos client)
• krb5-config (Kerberos configuration)
• winbind (Windows integration)
• libpam-winbind (PAM authentication)
• libnss-winbind (Name service switch)

Estimated download size: ~50MB
Estimated install time: 2-3 minutes

Proceed with installation?"""
        
        if not self.yesno(
            title="Confirm Installation",
            question=install_msg
        ):
            self.log("DEBUG", "User cancelled installation")
            return
            
        self.log("INFO", "Starting Samba installation...")
        
        if self.test_mode:
            self.log("INFO", "[TEST] Would run: apt-get update")
            self.log("INFO", "[TEST] Would install: samba samba-dsdb-modules samba-vfs-modules krb5-user krb5-config winbind libpam-winbind libnss-winbind")
            self.msgbox(
                title="Test Mode",
                text="Installation simulated successfully.\\n\\n(No actual changes made)",
            )
            return
            
        # Update package lists
        self.log("INFO", "Updating package lists...")
        try:
            self.run_command("sudo apt-get update")
        except subprocess.CalledProcessError:
            self.log("ERROR", "Failed to update package lists")
            self.msgbox(
                title="Installation Failed",
                text="Failed to update package lists.\\n\\nCheck your internet connection and try again.",
            )
            return
            
        # Install packages
        self.log("INFO", "Installing Samba packages...")
        try:
            self.run_command(
                "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "
                "samba samba-dsdb-modules samba-vfs-modules "
                "krb5-user krb5-config winbind libpam-winbind libnss-winbind"
            )
        except subprocess.CalledProcessError:
            self.log("ERROR", "Failed to install Samba packages")
            self.msgbox(
                title="Installation Failed",
                text=f"Package installation failed.\\n\\nCheck logs for details:\\n{self.log_file}",
            )
            return
            
        # Verify installation
        if self.check_samba_installed():
            version_result = self.run_command("samba-tool --version", check=False)
            version = version_result.stdout.strip().split('\n')[0] if version_result.returncode == 0 else "unknown"
            self.log("INFO", "✓ Samba installation completed successfully")
            self.msgbox(
                title="Installation Complete",
                text=f"Samba installed successfully!\\n\\nVersion: {version}\\n\\nNext step: Configure environment variables",
            )
        else:
            self.log("ERROR", "Installation appeared to succeed but samba-tool not found")
            self.msgbox(
                title="Installation Warning",
                text=f"Packages installed but samba-tool command not found.\\n\\nPlease check logs:\\n{self.log_file}",
            )

    def _call_dtpmenu(self, mode, title, content=None, default=""):
        """
        Call DtpMenuApp directly for TUI dialogs.
        
        Args:
            mode: 'menu', 'msgbox', 'yesno', or 'inputbox'
            title: Dialog title
            content: Data for the dialog (varies by mode)
            default: Default value for inputbox mode
            
        Returns:
            For menu/inputbox: user selection or None if cancelled
            For msgbox: always None
            For yesno: True if yes, False if no
        """
        try:
            # Prepare content data based on mode
            # inputbox mode requires a dictionary with "text" and "default" keys
            if mode == 'inputbox' and isinstance(content, str):
                final_content = {"text": content, "default": default}
            else:
                final_content = content

            # Create and run the DtpMenuApp
            app = DtpMenuApp(
                mode=mode,
                title=title,
                content_data=final_content,
                width=0,      # Use default
                height=0,     # Use default
                colors=None,
                h_center=True,
                v_center=True,
                debug=self.debug_mode
            )
            
            # Run the app (blocks until user interacts)
            app.run()
            
            # Return the result based on mode
            if mode == 'menu' or mode == 'inputbox':
                return app.result  # Selected tag or input value
            elif mode == 'yesno':
                return app.result == "yes"
            else:  # msgbox
                return None
                
        except Exception as e:
            self.log("ERROR", f"Menu dialog error ({mode}): {e}")
            return None
    
    def menu(self, title, items):
        """Display a menu and return the selected tag"""
        self.log("DEBUG", f"Showing menu: {title}")
        self.log("DEBUG", f"Total items passed to menu(): {len(items)}")
        
        # DEBUG: Log what we're actually passing to dtpmenu
        for idx, (tag, label) in enumerate(items):
            if tag == "":
                self.log("DEBUG", f"  [{idx}] (HEADER) {label}")
            else:
                self.log("DEBUG", f"  [{idx}] ({tag}) {label}")
        
        # Pass ALL items (including headers with empty tags) to dtpmenu
        # dtpmenu will render headers distinctly and handle selection logic
        result = self._call_dtpmenu('menu', title, content=items)
        if result:
            self.log("DEBUG", f"Menu selection: {result}")
        return result
    
    def msgbox(self, title, text, align="center"):
        """Display a message box with line count in title"""
        # Count message lines (not including padding/buttons)
        message_lines = text.count('\n') + 1 if text else 0
        title_with_count = f"{title} ({message_lines})"

        content = {"text": text, "align": align} if align else text
        self.log("DEBUG", f"Message: {title}")
        return self._call_dtpmenu('msgbox', title_with_count, content=content)
    
    def yesno(self, title, question):
        """Display yes/no dialog. Returns True for yes, False for no"""
        self.log("DEBUG", f"Yes/No: {title}")
        return self._call_dtpmenu('yesno', title, content=question)
    
    def inputbox(self, title, prompt, default=""):
        """Display input box. Returns user input or None if cancelled"""
        self.log("DEBUG", f"Input: {title}")
        return self._call_dtpmenu('inputbox', title, content=prompt, default=default)
    
    # Menu option handlers (stub implementations for future development)
    # Last Updated: 01/15/2026 8:15:00 PM CST
    
    def create_config_links(self):
        """Create config file links for VSCode"""
        # Last Updated: 01/15/2026 4:50:00 PM CST
        self.log("HEAD", "=== Create Config File Links (for VSCode) ===")
        self.log("INFO", "[MENU SELECTION] Config File Links Creation initiated")
        
        # Check if DOCKER_HOSTDIR is set
        docker_hostdir = os.getenv('DOCKER_HOSTDIR')
        if not docker_hostdir:
            self.log("WARN", "DOCKER_HOSTDIR environment variable not set")
            self.msgbox(
                title="Environment Variable Not Set",
                text="DOCKER_HOSTDIR is not set in your environment.\n\nThis variable should point to the host's shared directory (e.g., /home/divix/divtools/docker).\n\nPlease load your environment with: source ~/.bash_profile"
            )
            return
        
        links_dir = Path(docker_hostdir) / 'ads.cfg'
        self.log("INFO", f"Creating config file links in: {links_dir}")
        
        # Check if directory exists, create if not
        if not links_dir.exists():
            self.log("INFO", f"Creating directory: {links_dir}")
            if self.test_mode:
                self.log("INFO", f"[TEST] Would create: mkdir -p {links_dir}")
            else:
                try:
                    subprocess.run(['sudo', 'mkdir', '-p', str(links_dir)], check=True)
                except subprocess.CalledProcessError:
                    self.log("ERROR", f"Failed to create directory: {links_dir}")
                    self.msgbox(
                        title="Failed",
                        text=f"Failed to create directory:\n\n{links_dir}"
                    )
                    return
        
        # Define files to soft-link
        files_to_link = [
            ("smb.conf", "/etc/samba/smb.conf"),
            ("krb5.conf", "/etc/krb5.conf"),
            ("smb.conf.default", "/etc/samba/smb.conf.default"),
            ("resolv.conf", "/etc/resolv.conf"),
        ]
        
        # Define directories to soft-link
        dirs_to_link = [
            ("etc_samba", "/etc/samba"),
            ("lib_samba", "/var/lib/samba"),
        ]
        
        creation_count = 0
        error_count = 0
        summary = "Creating soft-links for Samba configuration files:\n\n"
        
        # Create file soft-links
        for link_name, target_file in files_to_link:
            link_path = links_dir / link_name
            self.log("DEBUG", f"Processing file link: {link_name} -> {target_file}")
            
            # Check if target exists
            if not Path(target_file).exists():
                self.log("WARN", f"Target file does not exist (might not be provisioned yet): {target_file}")
                summary += f"⚠ {link_name} -> {target_file} [NOT YET CREATED]\n"
                continue
            
            if self.test_mode:
                self.log("INFO", f"[TEST] Would create link: ln -sf {target_file} {link_path}")
                summary += f"[TEST] {link_name} -> {target_file}\n"
                creation_count += 1
            else:
                # Remove existing link if it exists
                if link_path.is_symlink():
                    try:
                        subprocess.run(['sudo', 'rm', str(link_path)], check=True)
                        self.log("DEBUG", f"Removed existing symlink: {link_path}")
                    except subprocess.CalledProcessError:
                        pass
                
                # Create the link
                try:
                    subprocess.run(['sudo', 'ln', '-sf', target_file, str(link_path)], check=True)
                    self.log("INFO", f"✓ Created link: {link_name} -> {target_file}")
                    summary += f"✓ {link_name}\n"
                    creation_count += 1
                except subprocess.CalledProcessError:
                    self.log("ERROR", f"Failed to create link: {link_path} -> {target_file}")
                    summary += f"✗ {link_name} (FAILED)\n"
                    error_count += 1
        
        # Create directory soft-links
        for link_name, target_dir in dirs_to_link:
            link_path = links_dir / link_name
            self.log("DEBUG", f"Processing directory link: {link_name} -> {target_dir}")
            
            # Check if target exists
            if not Path(target_dir).exists():
                self.log("WARN", f"Target directory does not exist: {target_dir}")
                summary += f"⚠ {link_name} -> {target_dir} [NOT FOUND]\n"
                continue
            
            if self.test_mode:
                self.log("INFO", f"[TEST] Would create link: ln -sf {target_dir} {link_path}")
                summary += f"[TEST] {link_name}/ -> {target_dir}/\n"
                creation_count += 1
            else:
                # Remove existing link if it exists
                if link_path.is_symlink():
                    try:
                        subprocess.run(['sudo', 'rm', str(link_path)], check=True)
                        self.log("DEBUG", f"Removed existing symlink: {link_path}")
                    except subprocess.CalledProcessError:
                        pass
                
                # Create the link
                try:
                    subprocess.run(['sudo', 'ln', '-sf', target_dir, str(link_path)], check=True)
                    self.log("INFO", f"✓ Created link: {link_name} -> {target_dir}")
                    summary += f"✓ {link_name}/ (directory)\n"
                    creation_count += 1
                except subprocess.CalledProcessError:
                    self.log("ERROR", f"Failed to create link: {link_path} -> {target_dir}")
                    summary += f"✗ {link_name}/ (FAILED)\n"
                    error_count += 1
        
        # Display results
        summary += "\n═══════════════════════════════════════\n"
        summary += f"Location: {links_dir}\n\n"
        summary += "You can now:\n"
        summary += "• Edit files directly in VSCode\n"
        summary += "• View the actual file system locations\n"
        summary += "• Make changes that affect the live system"
        
        if error_count == 0:
            self.log("INFO", "Config file links created successfully")
            self.msgbox(title="Config Links Created", text=summary)
        else:
            self.log("WARN", f"Config file links created with {error_count} errors")
            self.msgbox(
                title="Partial Success",
                text=f"{summary}\n\nWarning: {error_count} link(s) failed. Check logs for details."
            )
    
    def install_bash_aliases(self):
        """Install Bash aliases"""
        # Last Updated: 01/15/2026 10:45:00 PM CST
        self.log("HEAD", "=== Install Bash Aliases ===")
        self.log("INFO", "[MENU SELECTION] Bash Aliases Installation initiated")
        
        source_file = self.divtools / 'projects' / 'ads' / 'native' / 'samba-aliases-native.sh'
        dotfiles_dir = self.divtools / 'dotfiles'
        dotfiles_aliases = dotfiles_dir / 'samba-aliases-native.sh'
        user_bash_aliases = Path.home() / '.bash_aliases'
        divtools_bash_aliases = dotfiles_dir / '.bash_aliases'
        
        # Check if source file exists
        if not source_file.exists():
            self.log("ERROR", f"Source aliases file not found: {source_file}")
            self.msgbox(
                title="Error",
                text=f"ERROR: samba-aliases-native.sh not found at:\n\n{source_file}\n\nPlease ensure the file exists before running this option."
            )
            return
        
        # Helper function to create/update softlink
        def create_softlink():
            link_target = dotfiles_aliases
            link_source = "../projects/ads/native/samba-aliases-native.sh"
            
            self.log("DEBUG", f"Creating/updating softlink: {link_target} -> {link_source}")
            
            if self.test_mode:
                self.log("INFO", f"[TEST] Would create softlink: ln -sf {link_source} {link_target}")
                return True
            
            # Create the softlink (relative path from dotfiles to projects/ads/native)
            try:
                # Change to dotfiles directory to create relative link
                cwd = os.getcwd()
                os.chdir(dotfiles_dir)
                if link_target.is_symlink() or link_target.exists():
                    link_target.unlink()
                link_target.symlink_to(link_source)
                os.chdir(cwd)
                self.log("INFO", f"✓ Created/updated softlink: {link_target} -> {link_source}")
                return True
            except Exception as e:
                self.log("ERROR", f"Failed to create softlink: {link_target} -> {link_source}: {e}")
                return False
        
        # Helper function to add include to file
        def add_include_to_file(target_file):
            include_line = 'source "$DIVTOOLS/dotfiles/samba-aliases-native.sh"'
            
            self.log("DEBUG", f"Adding include to: {target_file}")
            
            # Check if include already exists
            if target_file.exists():
                content = target_file.read_text()
                if 'samba-aliases-native.sh' in content:
                    self.log("WARN", f"Include for samba-aliases-native.sh already exists in {target_file}")
                    message = f"""Include for samba-aliases-native.sh already exists in:

{target_file}

Add it anyway (might cause duplicate aliases)?"""
                    if not self.yesno(title="Include Already Exists", text=message):
                        self.log("DEBUG", "User cancelled due to existing include")
                        return True
            
            if self.test_mode:
                self.log("INFO", f"[TEST] Would append '{include_line}' to {target_file}")
                return True
            
            # Add the include at the end of the file
            try:
                with open(target_file, 'a') as f:
                    f.write(f"\n# Samba AD DC Native Bash Aliases\n{include_line}\n")
                self.log("INFO", f"✓ Added include to {target_file}")
                return True
            except Exception as e:
                self.log("ERROR", f"Failed to add include to {target_file}: {e}")
                return False
        
        # Show user options
        choice = self.menu(
            title="Bash Aliases Installation",
            text="Choose how to install Samba bash aliases:",
            items=[
                ("1", "Create softlink in dotfiles + include in ~/.bash_aliases"),
                ("2", "Create softlink in dotfiles + include in dotfiles/.bash_aliases"),
                ("3", "Create softlink in dotfiles only"),
                ("4", "Cancel")
            ]
        )
        
        if choice == "1":
            self.log("INFO", "User chose: Create softlink + include in ~/.bash_aliases")
            
            # Create softlink first
            if not create_softlink():
                self.msgbox(title="Failed", text="Failed to create softlink.\n\nCheck logs for details.")
                return
            
            # Add include to user's ~/.bash_aliases
            if not add_include_to_file(user_bash_aliases):
                self.msgbox(title="Failed", text="Failed to add include to ~/.bash_aliases.\n\nCheck logs for details.")
                return
            
            self.msgbox(
                title="Installation Complete",
                text="Installation Complete!\n\n✓ Softlink created: dotfiles/samba-aliases-native.sh\n✓ Include added to ~/.bash_aliases\n\nRun 'source ~/.bash_aliases' to activate."
            )
        
        elif choice == "2":
            self.log("INFO", "User chose: Create softlink + include in dotfiles/.bash_aliases")
            
            # Create softlink first
            if not create_softlink():
                self.msgbox(title="Failed", text="Failed to create softlink.\n\nCheck logs for details.")
                return
            
            # Add include to divtools .bash_aliases
            if not add_include_to_file(divtools_bash_aliases):
                self.msgbox(title="Failed", text="Failed to add include to dotfiles/.bash_aliases.\n\nCheck logs for details.")
                return
            
            self.msgbox(
                title="Installation Complete",
                text="Installation Complete!\n\n✓ Softlink created: dotfiles/samba-aliases-native.sh\n✓ Include added to dotfiles/.bash_aliases\n\nThis will work on ALL systems using divtools."
            )
        
        elif choice == "3":
            self.log("INFO", "User chose: Create softlink only")
            
            # Create softlink
            if not create_softlink():
                self.msgbox(title="Failed", text="Failed to create softlink.\n\nCheck logs for details.")
                return
            
            self.msgbox(
                title="Softlink Created",
                text="Softlink Created!\n\n✓ dotfiles/samba-aliases-native.sh -> ../projects/ads/native/samba-aliases-native.sh\n\nYou can now manually source this file or add includes as needed."
            )
        
        else:  # choice == "4" or None/empty
            self.log("DEBUG", "User cancelled bash aliases installation")
    
    def generate_install_doc(self):
        """Generate installation steps documentation"""
        # Last Updated: 01/15/2026 10:30:00 AM CST
        
        # Load environment variables first
        self.load_ads_env_vars()
        
        # Get domain/realm from environment (with fallback to input)
        domain = self.env_vars.get('ADS_REALM', '')
        
        if not domain:
            domain = self.inputbox(
                title='Enter Domain Realm',
                text='Enter the AD realm (e.g., FHMTN1.LAN, AVCTN.LAN):',
                initial=''
            )
        
        if not domain:
            self.log("WARN", "User cancelled domain entry")
            return
        
        # Validate domain format
        domain = domain.upper()
        import re
        if not re.match(r'^[A-Z0-9]+\.[A-Z]+$', domain):
            self.msgbox(title="Invalid Domain", text="Domain must be in format: DOMAIN.LAN (e.g., FHMTN1.LAN)")
            return
        
        # Display header with REALM
        self.log("HEAD", f"=== INSTALL GUIDE: {domain} ===")
        
        # Calculate install steps doc path
        doc_dir = self.divtools / 'projects' / 'ads' / 'native'
        doc_name = f"INSTALL-STEPS-{domain}.md"
        doc_path = doc_dir / doc_name
        
        self.log("DEBUG", f"Generating installation steps for domain: {domain}")
        self.log("DEBUG", f"Document path: {doc_path}")
        
        # Create directory if it doesn't exist
        doc_dir.mkdir(parents=True, exist_ok=True)
        
        # Backup existing file if it exists
        if doc_path.exists():
            self.log("DEBUG", "Document already exists, creating backup...")
            backup_path = doc_path.with_suffix(f".backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md")
            import shutil
            shutil.copy(doc_path, backup_path)
            self.log("INFO", f"Backed up existing document to {backup_path}")
        
        # Get environment variables for document generation
        ads_netbios = self.env_vars.get('ADS_NETBIOS', 'DOMAIN')
        ads_admin_user = self.env_vars.get('ADS_ADMIN_USER', 'Administrator')
        ads_dns_backend = self.env_vars.get('ADS_DNS_BACKEND', 'SAMBA_INTERNAL')
        hostname = socket.gethostname()
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # Generate the document content
        doc_content = f"""# Samba AD DC Installation Steps - {domain}

**Generated:** {timestamp}
**Domain/Realm:** {domain}
**NetBIOS Name:** {ads_netbios}
**Admin User:** {ads_admin_user}
**Host:** {hostname}

---

## Pre-Installation Checks

- [ ] System hostname set correctly
- [ ] DNS resolver configured to use this server (127.0.0.1)
- [ ] Sufficient disk space available (~2GB minimum)
- [ ] Network connectivity verified
- [ ] Internet access available for package downloads

---

## Installation Steps

### Step 1: Install Samba Packages
- [ ] Run: `apt-get update && apt-get install -y samba samba-dsdb-modules samba-vfs-modules krb5-user krb5-config winbind libpam-winbind libnss-winbind`
- [ ] Verify installation: `samba-tool --version`
- [ ] Check for errors in output

### Step 2: Configure Environment Variables
- [ ] Domain Realm: `{domain}`
- [ ] NetBIOS Name: `{ads_netbios}`
- [ ] Admin User: `{ads_admin_user}`
- [ ] Domain Admin Password: (must be complex, 12+ chars)
- [ ] DNS Backend: `{ads_dns_backend}`

### Step 3: Provision AD Domain
- [ ] Run: `dt_ads_native.sh` → Menu Option 8: Provision AD Domain
- [ ] Wait for provisioning to complete (may take 1-2 minutes)
- [ ] Check for any error messages
- [ ] Verify /etc/samba/smb.conf was created

### Step 4: Configure DNS on Host
- [ ] Run: `dt_ads_native.sh` → Menu Option 9: Configure DNS on Host
- [ ] Stop systemd-resolved
- [ ] Update /etc/resolv.conf to point to 127.0.0.1
- [ ] Verify DNS is working: `nslookup {domain}`

### Step 5: Start Samba Services
- [ ] Run: `dt_ads_native.sh` → Menu Option 10: Start Samba Services
- [ ] Verify services started: `systemctl status samba-ad-dc`
- [ ] Check Samba logs: `journalctl -u samba-ad-dc -n 20`

### Step 6: Create Soft-Links for Config Editing
- [ ] Run: `dt_ads_native.sh` → Menu Option 4: Create Config File Links
- [ ] Verify soft-links created in $DOCKER_HOSTDIR/ads.cfg/
- [ ] Test editing: Open smb.conf in VSCode

### Step 7: Install Bash Aliases
- [ ] Run: `dt_ads_native.sh` → Menu Option 5: Install Bash Aliases
- [ ] Test alias: `ads-status` or `ads-health`

### Step 8: Verify Domain Setup
- [ ] Run: `dt_ads_native.sh` → Menu Option 14: Run Health Checks
- [ ] Check all test results pass
- [ ] Verify FSMO roles assigned
- [ ] Confirm replication working

---

## Post-Installation Tasks

- [ ] Create domain admin user: `samba-tool user add <username>`
- [ ] Add user to Domain Admins group: `samba-tool group addmembers 'Domain Admins' <username>`
- [ ] Configure DNS zones (if using SAMBA_INTERNAL)
- [ ] Set up file shares (if needed)
- [ ] Configure GPOs (Group Policy Objects) as needed
- [ ] Join additional computers to the domain
- [ ] Enable regular backups of /var/lib/samba/private/

---

## Troubleshooting

If you encounter issues:

1. **DNS not resolving:** `nslookup -server=127.0.0.1 {domain}`
2. **Service won't start:** `journalctl -u samba-ad-dc -p err -n 50`
3. **Replication issues:** `samba-tool drs showrepl`
4. **User authentication fails:** `kinit Administrator@{domain}`

---

## Configuration Files

For detailed information about Samba configuration files, see: [N-ADS-CONFIG-FILES.md](N-ADS-CONFIG-FILES.md)

---

**Last Updated:** {timestamp}
**Auto-generated by dt_ads_native.py**
"""
        
        # Write the document
        try:
            doc_path.write_text(doc_content)
            display_path = f"./projects/ads/native/{doc_name}"
            self.log("INFO", f"✓ Installation steps document created: {doc_name}")
            self.log("INFO", f"Location: {display_path}")
            self.msgbox(
                title=f"Success - REALM: {domain}",
                text=f"Installation steps document created:\n\n{display_path}\n\nYou can now follow the steps one by one.\nUse Menu Option 7 to update status as you complete each step."
            )
        except Exception as e:
            self.log("ERROR", f"Failed to write document: {e}")
            self.msgbox(
                title="Error",
                text=f"Failed to create installation steps document.\n\nCheck permissions on:\n{doc_path}"
            )
    
    def update_install_doc(self):
        """Update installation steps documentation"""
        # Last Updated: 01/18/2026 12:05:00 PM CST
        
        # Get domain/realm from environment
        domain = self.env_vars.get('ADS_REALM', '')
        
        if not domain:
            self.msgbox(
                title="Update Installation Steps - Missing Configuration",
                text="ADS_REALM not set in environment.\n\nPlease configure environment variables first (Menu Option 2)."
            )
            return
        
        # Display header with REALM
        self.log("HEAD", f"=== UPDATE INSTALLATION STEPS: {domain} ===")
        
        # Validate document exists
        domain = domain.upper()
        doc_name = f"INSTALL-STEPS-{domain}.md"
        doc_dir = self.divtools / 'projects' / 'ads' / 'native'
        doc_path = doc_dir / doc_name
        
        if not doc_path.exists():
            self.msgbox(
                title="Update Installation Steps - Document Not Found",
                text=f"Installation steps document not found:\n\n{doc_name}\n\nCreate it first using Menu Option 6 (Generate Installation Steps Doc)."
            )
            return
        
        self.log("DEBUG", f"Checking installation step status for domain: {domain}")
        self.log("DEBUG", f"Document: {doc_path}")
        
        # Get file modification timestamp
        file_mtime = datetime.fromtimestamp(doc_path.stat().st_mtime).strftime('%m/%d/%Y %I:%M:%S %p')
        current_check_time = datetime.now().strftime('%m/%d/%Y %I:%M:%S %p')
        
        # Check status of each major step
        checks_completed = 0
        checks_total = 0
        status_items = []
        
        # Check 1: Samba installed
        checks_total += 1
        try:
            result = subprocess.run(['samba-tool', '--version'], capture_output=True, text=True, check=True)
            version = result.stdout.splitlines()[0] if result.stdout else 'installed'
            status_items.append(('COMPLETE', f"Samba installed: {version}"))
            checks_completed += 1
        except:
            status_items.append(('INCOMPLETE', "Samba not installed"))
        
        # Check 2: Domain provisioned
        checks_total += 1
        if Path('/etc/samba/smb.conf').exists():
            status_items.append(('COMPLETE', "Domain provisioned"))
            checks_completed += 1
        else:
            status_items.append(('INCOMPLETE', "Domain not provisioned"))
        
        # Check 3: DNS configured
        checks_total += 1
        try:
            resolv_content = Path('/etc/resolv.conf').read_text()
            if '127.0.0.1' in resolv_content:
                status_items.append(('COMPLETE', "DNS configured (127.0.0.1)"))
                checks_completed += 1
            else:
                status_items.append(('INCOMPLETE', "DNS not configured"))
        except:
            status_items.append(('INCOMPLETE', "DNS not configured"))
        
        # Check 4: Samba services running
        checks_total += 1
        try:
            result = subprocess.run(['systemctl', 'is-active', 'samba-ad-dc'], capture_output=True)
            if result.returncode == 0:
                status_items.append(('COMPLETE', "Samba AD DC service running"))
                checks_completed += 1
            else:
                status_items.append(('INCOMPLETE', "Samba AD DC service not running"))
        except:
            status_items.append(('INCOMPLETE', "Samba AD DC service not running"))
        
        # Check 5: Config links exist
        checks_total += 1
        docker_hostdir = os.getenv('DOCKER_HOSTDIR', '')
        if docker_hostdir:
            link_path = Path(docker_hostdir) / 'ads.cfg' / 'smb.conf'
            if link_path.is_symlink():
                status_items.append(('COMPLETE', "Config file links created"))
                checks_completed += 1
            else:
                status_items.append(('INCOMPLETE', "Config file links not created"))
        else:
            status_items.append(('INCOMPLETE', "Config file links not created (DOCKER_HOSTDIR not set)"))
        
        # Check 6: Aliases installed
        checks_total += 1
        bashrc = Path.home() / '.bashrc'
        bash_profile = Path.home() / '.bash_profile'
        bash_aliases = Path.home() / '.bash_aliases'
        
        alias_found = False
        for file in [bashrc, bash_profile, bash_aliases]:
            if file.exists():
                content = file.read_text()
                if 'samba-aliases-native' in content:
                    alias_found = True
                    break
        
        if alias_found:
            status_items.append(('COMPLETE', "Bash aliases installed"))
            checks_completed += 1
        else:
            status_items.append(('INCOMPLETE', "Bash aliases not installed"))
        
        # Build clean formatted message - LEFT JUSTIFIED, NO REDUNDANT TITLE
        # NO title here (title is in msgbox title parameter)
        status_msg = f"File: ./projects/ads/native/{doc_name}\n"
        status_msg += f"File created: {file_mtime}\n"
        status_msg += f"Status checked: {current_check_time}\n"
        status_msg += "\n"
        status_msg += "Installation Status:\n"
        status_msg += "\n"
        
        # Add each status item with visual indicators
        # Use [✓] for complete, [✗] for incomplete - clear distinction
        for status, item in status_items:
            if status == "COMPLETE":
                status_msg += f"[green]✓ {item}[/green]\n"
            else:
                status_msg += f"[yellow]✗ {item}[/yellow]\n"
        
        status_msg += "\n"
        status_msg += f"Progress: {checks_completed}/{checks_total} steps completed\n"
        status_msg += f"Percentage: {int((checks_completed/checks_total)*100)}%"
        
        self.log("INFO", f"Installation progress: {checks_completed}/{checks_total} completed ({int((checks_completed/checks_total)*100)}%)")
        self.log("INFO", f"Status checked and displayed: {doc_name}")
        
        # Display the status - title shows REALM only, content is clean and left-justified
        self.msgbox(
            title=f"Update Installation Steps - {domain}",
            text=status_msg,
            align="left"
        )
    
    def provision_domain(self):
        """Provision AD Domain"""
        # Last Updated: 01/15/2026 4:50:00 PM CST
        self.log("HEAD", "=== Provision AD Domain ===")
        self.log("INFO", "[MENU SELECTION] Domain Provisioning initiated")
        
        # Check if samba is installed
        try:
            subprocess.run(['which', 'samba-tool'], check=True, capture_output=True)
        except subprocess.CalledProcessError:
            self.msgbox(
                title="Samba Not Installed",
                text="Samba is not installed.\n\nPlease install Samba first (Option 1)"
            )
            return
        
        # Load environment variables
        self.load_ads_env_vars()
        
        # Check required variables
        required_vars = ['ADS_DOMAIN', 'ADS_REALM', 'ADS_ADMIN_PASSWORD']
        missing_vars = [var for var in required_vars if not self.env_vars.get(var)]
        if missing_vars:
            self.msgbox(
                title="Missing Configuration",
                text="Required environment variables not set.\n\nPlease configure environment variables first (Option 2)"
            )
            return
        
        # Check if domain already provisioned
        sam_ldb = self.data_dir / 'private' / 'sam.ldb'
        if sam_ldb.exists():
            self.log("WARN", "Domain database already exists")
            if not self.yesno(
                title="Domain Exists",
                text=f"A domain database already exists at:\n{sam_ldb}\n\nThis means the domain is already provisioned.\n\nRe-provision anyway? (This will DELETE the existing domain!)"
            ):
                self.log("DEBUG", "User declined re-provisioning")
                return
            
            # Stop samba services before reprovisioning
            self.log("INFO", "Stopping Samba services...")
            subprocess.run(['sudo', 'systemctl', 'stop', 'samba-ad-dc'], capture_output=True)
            
            # Backup existing data
            timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
            backup_dir = f"{self.data_dir}.backup-{timestamp}"
            self.log("INFO", f"Backing up existing domain to {backup_dir}...")
            try:
                subprocess.run(['sudo', 'mv', str(self.data_dir), backup_dir], check=True)
            except subprocess.CalledProcessError as e:
                self.log("ERROR", f"Failed to backup existing domain: {e}")
        
        # Get env vars for display
        ads_domain = self.env_vars.get('ADS_DOMAIN', '')
        ads_realm = self.env_vars.get('ADS_REALM', '')
        ads_workgroup = self.env_vars.get('ADS_WORKGROUP', '')
        ads_host_ip = self.env_vars.get('ADS_HOST_IP', '')
        ads_dns_forwarder = self.env_vars.get('ADS_DNS_FORWARDER', '8.8.8.8')
        
        # Confirm provisioning
        provision_msg = f"""Ready to provision AD domain with:

Domain: {ads_domain}
Realm: {ads_realm}
Workgroup: {ads_workgroup}
Host IP: {ads_host_ip}
DNS Forwarder: {ads_dns_forwarder}

This will:
• Create AD database in /var/lib/samba
• Generate smb.conf in /etc/samba
• Configure Kerberos in /etc/krb5.conf
• Set Administrator password

Proceed with provisioning?"""
        
        if not self.yesno(title="Provision Domain", text=provision_msg):
            self.log("DEBUG", "User cancelled provisioning")
            return
        
        self.log("INFO", "Starting domain provisioning...")
        
        if self.test_mode:
            self.log("INFO", "[TEST] Would provision domain with samba-tool")
            self.msgbox(
                title="Test Mode",
                text="Domain provisioning simulated.\n\n(No actual changes made)"
            )
            return
        
        # Remove existing smb.conf if it exists
        smb_conf = self.config_samba_dir / 'smb.conf'
        if smb_conf.exists():
            self.log("INFO", "Removing existing smb.conf")
            try:
                subprocess.run(['sudo', 'rm', '-f', str(smb_conf)], check=True)
            except subprocess.CalledProcessError as e:
                self.log("WARN", f"Failed to remove smb.conf: {e}")
        
        # Run samba-tool domain provision
        self.log("INFO", "Running samba-tool domain provision...")
        admin_password = self.env_vars.get('ADS_ADMIN_PASSWORD', '')
        
        provision_cmd = [
            'sudo', 'samba-tool', 'domain', 'provision',
            '--server-role=dc',
            '--use-rfc2307',
            '--dns-backend=SAMBA_INTERNAL',
            f'--realm={ads_realm}',
            f'--domain={ads_workgroup}',
            f'--adminpass={admin_password}',
            f'--host-ip={ads_host_ip}',
            f'--option=dns forwarder = {ads_dns_forwarder}',
            '--option=log level = 1'
        ]
        
        try:
            result = subprocess.run(provision_cmd, capture_output=True, text=True, check=True)
            self.log("DEBUG", f"Provision output: {result.stdout}")
        except subprocess.CalledProcessError as e:
            self.log("ERROR", f"Domain provisioning failed: {e.stderr}")
            self.msgbox(
                title="Provisioning Failed",
                text=f"Domain provisioning failed.\n\nCheck logs for details:\n{self.log_file}"
            )
            return
        
        # Copy Kerberos config
        krb5_conf_src = self.data_dir / 'private' / 'krb5.conf'
        if krb5_conf_src.exists():
            self.log("INFO", "Copying Kerberos configuration to /etc/krb5.conf")
            try:
                subprocess.run(['sudo', 'cp', str(krb5_conf_src), '/etc/krb5.conf'], check=True)
            except subprocess.CalledProcessError as e:
                self.log("WARN", f"Failed to copy krb5.conf: {e}")
        
        self.log("INFO", "✓ Domain provisioning completed successfully")
        self.msgbox(
            title="Provisioning Complete",
            text=f"Domain provisioned successfully!\n\nDomain: {ads_domain}\nRealm: {ads_realm}\n\nNext step: Configure DNS on host (Option 9)"
        )
    
    def configure_dns(self):
        """Configure DNS on Host"""
        # Last Updated: 01/15/2026 4:50:00 PM CST
        self.log("HEAD", "=== Configure DNS on Host ===")
        self.log("INFO", "[MENU SELECTION] DNS Configuration initiated")
        
        self.load_ads_env_vars()
        
        # Get current DNS settings
        try:
            with open('/etc/resolv.conf', 'r') as f:
                resolv_content = f.read()
            current_nameservers = ' '.join([line.split()[1] for line in resolv_content.splitlines() 
                                           if line.strip().startswith('nameserver')])
            search_lines = [line for line in resolv_content.splitlines() if line.strip().startswith('search')]
            current_search = search_lines[0].split()[1] if search_lines else ''
        except FileNotFoundError:
            current_nameservers = 'None'
            current_search = ''
        
        # Check if systemd-resolved is active
        try:
            result = subprocess.run(['systemctl', 'is-active', 'systemd-resolved'],
                                  capture_output=True, text=True)
            systemd_resolved_active = (result.returncode == 0)
        except Exception:
            systemd_resolved_active = False
        
        resolved_status = "ACTIVE" if systemd_resolved_active else "inactive"
        resolved_warning = "\n\nWARNING: systemd-resolved will be stopped and masked" if systemd_resolved_active else ""
        
        dns_forwarder = self.env_vars.get('ADS_DNS_FORWARDER', '8.8.8.8')
        ads_domain = self.env_vars.get('ADS_DOMAIN', '')
        
        dns_msg = f"""Current DNS Configuration:

Nameservers: {current_nameservers}
Search Domain: {current_search}
systemd-resolved: {resolved_status}

NEW DNS CONFIGURATION:
Primary NS:   127.0.0.1 (Samba AD DC)
Secondary NS: {dns_forwarder} (External)
Search Domain: {ads_domain}{resolved_warning}

Proceed with DNS configuration?"""
        
        if not self.yesno(title="Configure DNS", text=dns_msg):
            self.log("DEBUG", "User cancelled DNS configuration")
            return
        
        if self.test_mode:
            self.log("INFO", "[TEST] Would configure DNS settings")
            self.msgbox(
                title="Test Mode",
                text="DNS configuration simulated.\n\n(No actual changes made)"
            )
            return
        
        # Stop and mask systemd-resolved if active
        if systemd_resolved_active:
            self.log("INFO", "Stopping systemd-resolved...")
            try:
                subprocess.run(['sudo', 'systemctl', 'stop', 'systemd-resolved'], check=True)
                subprocess.run(['sudo', 'systemctl', 'mask', 'systemd-resolved'], check=True)
                self.log("INFO", "✓ systemd-resolved stopped and masked")
            except subprocess.CalledProcessError as e:
                self.log("ERROR", f"Failed to stop systemd-resolved: {e}")
                self.msgbox(title="Error", text=f"Failed to stop systemd-resolved: {e}")
                return
        
        # Backup resolv.conf
        resolv_conf = Path('/etc/resolv.conf')
        if resolv_conf.exists():
            backup_file = f"/etc/resolv.conf.backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
            try:
                subprocess.run(['sudo', 'cp', str(resolv_conf), backup_file], check=True)
                self.log("INFO", f"Backed up resolv.conf to {backup_file}")
            except subprocess.CalledProcessError as e:
                self.log("WARN", f"Failed to backup resolv.conf: {e}")
        
        # Update resolv.conf
        self.log("INFO", "Updating /etc/resolv.conf...")
        new_resolv_content = f"nameserver 127.0.0.1\nnameserver {dns_forwarder}\nsearch {ads_domain}\n"
        try:
            # Write to temp file first, then use sudo tee
            with tempfile.NamedTemporaryFile(mode='w', delete=False) as tmp:
                tmp.write(new_resolv_content)
                tmp_path = tmp.name
            
            subprocess.run(f'sudo tee /etc/resolv.conf < {tmp_path} > /dev/null', 
                          shell=True, check=True)
            Path(tmp_path).unlink()
            
            self.log("INFO", "✓ DNS configuration completed")
            self.msgbox(
                title="DNS Configured",
                text=f"DNS configured successfully!\n\nPrimary: 127.0.0.1 (Samba AD DC)\nSecondary: {dns_forwarder}\nSearch: {ads_domain}"
            )
        except Exception as e:
            self.log("ERROR", f"Failed to update resolv.conf: {e}")
            self.msgbox(title="Error", text=f"Failed to update resolv.conf: {e}")
    
    def start_services(self):
        """Start Samba services"""
        # Last Updated: 01/15/2026 4:50:00 PM CST
        self.log("HEAD", "=== Start Samba Services ===")
        self.log("INFO", "[MENU SELECTION] Start Services initiated")
        
        if self.test_mode:
            self.log("INFO", "[TEST] Would start samba-ad-dc service")
            self.msgbox(
                title="Test Mode",
                text="Services start simulated.\n\n(No actual changes made)"
            )
            return
        
        self.log("INFO", "Starting samba-ad-dc service...")
        try:
            subprocess.run(['sudo', 'systemctl', 'start', 'samba-ad-dc'], check=True)
        except subprocess.CalledProcessError:
            self.log("ERROR", "Failed to start samba-ad-dc")
            self.msgbox(
                title="Start Failed",
                text="Failed to start Samba services.\n\nCheck logs:\njournalctl -u samba-ad-dc -n 50"
            )
            return
        
        # Enable on boot
        try:
            subprocess.run(['sudo', 'systemctl', 'enable', 'samba-ad-dc'], check=True)
        except subprocess.CalledProcessError as e:
            self.log("WARN", f"Failed to enable service: {e}")
        
        self.log("INFO", "✓ Samba services started and enabled")
        self.msgbox(
            title="Services Started",
            text="Samba AD DC services started successfully!\n\nEnabled on boot: Yes\n\nCheck status with:\nsystemctl status samba-ad-dc"
        )
    
    def stop_services(self):
        """Stop Samba services"""
        # Last Updated: 01/15/2026 4:50:00 PM CST
        self.log("HEAD", "=== Stop Samba Services ===")
        self.log("INFO", "[MENU SELECTION] Stop Services initiated")
        
        if self.test_mode:
            self.log("INFO", "[TEST] Would stop samba-ad-dc service")
            self.msgbox(
                title="Test Mode",
                text="Services stop simulated.\n\n(No actual changes made)"
            )
            return
        
        self.log("INFO", "Stopping samba-ad-dc service...")
        try:
            subprocess.run(['sudo', 'systemctl', 'stop', 'samba-ad-dc'], check=True)
        except subprocess.CalledProcessError:
            self.log("ERROR", "Failed to stop samba-ad-dc")
            self.msgbox(
                title="Stop Failed",
                text="Failed to stop Samba services.\n\nCheck status:\nsystemctl status samba-ad-dc"
            )
            return
        
        self.log("INFO", "✓ Samba services stopped")
        self.msgbox(
            title="Services Stopped",
            text="Samba AD DC services stopped successfully."
        )
    
    def restart_services(self):
        """Restart Samba services"""
        # Last Updated: 01/15/2026 4:50:00 PM CST
        self.log("HEAD", "=== Restart Samba Services ===")
        self.log("INFO", "[MENU SELECTION] Restart Services initiated")
        
        if self.test_mode:
            self.log("INFO", "[TEST] Would restart samba-ad-dc service")
            self.msgbox(
                title="Test Mode",
                text="Services restart simulated.\n\n(No actual changes made)"
            )
            return
        
        self.log("INFO", "Restarting samba-ad-dc service...")
        try:
            subprocess.run(['sudo', 'systemctl', 'restart', 'samba-ad-dc'], check=True)
        except subprocess.CalledProcessError:
            self.log("ERROR", "Failed to restart samba-ad-dc")
            self.msgbox(
                title="Restart Failed",
                text="Failed to restart Samba services.\n\nCheck logs:\njournalctl -u samba-ad-dc -n 50"
            )
            return
        
        self.log("INFO", "✓ Samba services restarted")
        self.msgbox(
            title="Services Restarted",
            text="Samba AD DC services restarted successfully."
        )
    
    def view_logs(self):
        """View Samba service logs"""
        # Last Updated: 01/15/2026 4:50:00 PM CST
        self.log("HEAD", "=== View Service Logs ===")
        self.log("INFO", "[MENU SELECTION] View Logs initiated")
        
        self.log("INFO", "Fetching service logs...")
        
        try:
            result = subprocess.run(
                ['sudo', 'journalctl', '-u', 'samba-ad-dc', '-n', '100', '--no-pager'],
                capture_output=True,
                text=True,
                check=True
            )
            logs = result.stdout
            
            if not logs.strip():
                logs = "No logs found for samba-ad-dc service."
            
            self.msgbox(
                title="Samba AD DC Service Logs (Last 100 lines)",
                text=logs
            )
        except subprocess.CalledProcessError as e:
            self.log("ERROR", f"Failed to fetch logs: {e}")
            self.msgbox(
                title="Error",
                text=f"Failed to fetch service logs.\n\nError: {e.stderr if e.stderr else str(e)}"
            )
    
    def health_checks(self):
        """Run health checks"""
        # Last Updated: 01/15/2026 4:50:00 PM CST
        self.log("HEAD", "=== Health Checks ===")
        self.log("INFO", "[MENU SELECTION] Health Checks initiated")
        
        results = ""
        
        # Check if service is running
        results += "Service Status:\n"
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', 'samba-ad-dc'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                results += "✓ samba-ad-dc is running\n\n"
            else:
                results += "✗ samba-ad-dc is NOT running\n\n"
        except Exception as e:
            results += f"✗ Error checking service: {e}\n\n"
        
        # Check domain info
        results += "Domain Information:\n"
        try:
            result = subprocess.run(
                ['sudo', 'samba-tool', 'domain', 'info', '127.0.0.1'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                results += result.stdout + "\n\n"
            else:
                results += "✗ Failed to get domain info\n\n"
        except Exception as e:
            results += f"✗ Error getting domain info: {e}\n\n"
        
        # Check FSMO roles
        results += "FSMO Roles:\n"
        try:
            result = subprocess.run(
                ['sudo', 'samba-tool', 'fsmo', 'show'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                # Get first 10 lines
                fsmo_lines = result.stdout.splitlines()[:10]
                results += '\n'.join(fsmo_lines) + "\n"
            else:
                results += "✗ Failed to get FSMO roles\n"
        except Exception as e:
            results += f"✗ Error getting FSMO roles: {e}\n"
        
        self.msgbox(
            title="Health Check Results",
            text=results
        )
            
    def main_menu(self):
        """Display main menu and handle user selections"""
        while True:
            # Reload env vars at start of each loop to get current realm
            # Last Updated: 12/20/2024 10:30:00 AM CDT
            self.load_ads_env_vars()
            display_realm = self.env_vars.get('REALM', 'Not Configured')
            
            # Build menu items with line numbers if debug mode
            menu_items = [
                ("", "═══ INSTALLATION ═══"),
                ("1", "Install Samba (Native)"),
                ("2", "Configure Environment Variables"),
                ("3", "Check Environment Variables"),
                ("4", "Create Config File Links (for VSCode)"),
                ("5", "Install Bash Aliases"),
                ("", f"═══ INSTALL GUIDE: {display_realm} ═══"),
                ("6", "Generate Installation Steps Doc"),
                ("7", "Update Installation Steps Doc"),
                ("", "═══ DOMAIN SETUP ═══"),
                ("8", "Provision AD Domain"),
                ("9", "Configure DNS on Host"),
                ("", "═══ SERVICE MANAGEMENT ═══"),
                ("10", "Start Samba Services"),
                ("11", "Stop Samba Services"),
                ("12", "Restart Samba Services"),
                ("13", "View Service Logs"),
                ("", "═══ DIAGNOSTICS ═══"),
                ("14", "Run Health Checks"),
                ("", "═════════════════════════════"),
                ("0", "Exit"),
            ]
            
            # Add line numbers if debug mode
            if self.debug_mode:
                menu_items = [(tag, f"{idx}: {text}") for idx, (tag, text) in enumerate(menu_items, 1)]
            
            # Build title with line count (selectable items only, excluding section headers)
            selectable_count = sum(1 for tag, _ in menu_items if tag)  # Count non-empty tags
            title = f"Samba AD DC Native Setup ({selectable_count})"  # Shows selectable menu items
            
            # DEBUG OUTPUT: Show what we're passing
            self.log("DEBUG", f"Main menu building {len(menu_items)} items:")
            for idx, (tag, label) in enumerate(menu_items):
                if tag == "":
                    self.log("DEBUG", f"  [{idx}] HEADER: {label}")
                else:
                    self.log("DEBUG", f"  [{idx}] TAG '{tag}': {label}")
            
            # Show menu
            choice = self.menu(
                title=title,
                items=menu_items,
            )
            
            if choice is None or choice == "0":
                self.log("INFO", "User chose to exit from main menu")
                self.log("HEAD", "Script execution completed - Exiting")
                break
                
            # Skip empty choices (section headers)
            if not choice:
                continue
                continue
                
            menu_descriptions = {
                "1": "Install Samba (Native)",
                "2": "Configure Environment Variables",
                "3": "Check Environment Variables",
                "4": "Create Config File Links (for VSCode)",
                "5": "Install Bash Aliases",
                "6": "Generate Installation Steps Doc",
                "7": "Update Installation Steps Doc",
                "8": "Provision AD Domain",
                "9": "Configure DNS on Host",
                "10": "Start Samba Services",
                "11": "Stop Samba Services",
                "12": "Restart Samba Services",
                "13": "View Service Logs",
                "14": "Run Health Checks",
            }
            
            desc = menu_descriptions.get(choice, "Unknown")
            self.log("HEAD", "═══════════════════════════════════════════")
            self.log("HEAD", f"MENU SELECTION: Option {choice} - {desc}")
            self.log("HEAD", "═══════════════════════════════════════════")
            
            # Handle menu choice
            if choice == "1":
                self.install_samba()
            elif choice == "2":
                self.prompt_env_vars()
            elif choice == "3":
                self.check_env_vars()
            elif choice == "4":
                self.create_config_links()
            elif choice == "5":
                self.install_bash_aliases()
            elif choice == "6":
                self.generate_install_doc()
            elif choice == "7":
                self.update_install_doc()
            elif choice == "8":
                self.provision_domain()
            elif choice == "9":
                self.configure_dns()
            elif choice == "10":
                self.start_services()
            elif choice == "11":
                self.stop_services()
            elif choice == "12":
                self.restart_services()
            elif choice == "13":
                self.view_logs()
            elif choice == "14":
                self.health_checks()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Samba AD DC Native Setup - Interactive TUI',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('-test', '--test', action='store_true',
                       help='Test mode (no permanent changes)')
    parser.add_argument('-debug', '--debug', action='store_true',
                       help='Enable debug logging')
    parser.add_argument('-v', action='count', default=0,
                       help='Verbose output (-v or -vv)')
    
    args = parser.parse_args()
    
    # Determine debug mode
    debug_mode = args.debug or args.v >= 2
    
    try:
        app = ADSNativeApp(
            test_mode=args.test,
            debug_mode=debug_mode,
            verbose=args.v
        )
        app.main_menu()
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
