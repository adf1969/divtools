#!/bin/bash
# Script to fix Coral USB TPU delegate error in Frigate on Ubuntu 22.04 LTS
# Purpose: Installs Edge TPU runtime, verifies TPU detection and permissions, provides guidance for Docker Compose and LXC USB passthrough
# Last Updated: 9/21/2025 8:39 PM CDT

# Source logging function
if [ -f "$DIVTOOLS/scripts/util/logging.sh" ]; then
  source "$DIVTOOLS/scripts/util/logging.sh"
else
  echo "ERROR: Logging script not found at $DIVTOOLS/scripts/util/logging.sh" >&2
  exit 1
fi

# Usage function
usage() {
  log "INFO" "Usage: $(basename "$0") [-debug] [--reinstall] [-h|--help]"
  log "INFO" "  -debug: Enable debug logging"
  log "INFO" "  --reinstall: Force reinstallation of packages"
  log "INFO" "  -h|--help: Show this help message"
  exit 1
}

# Parse arguments
debug_mode=0
reinstall=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -debug) debug_mode=1; export DEBUG_MODE=1; shift ;;
    --reinstall) reinstall=1; shift ;;
    -h|--help) usage ;;
    *) log "ERROR" "Unknown argument: $1"; usage ;;
  esac
done

# Source environment variables
if [ -f ~/.env ]; then
  source ~/.env
  [ $debug_mode -eq 1 ] && log "DEBUG" "Sourced ~/.env: DOCKERDIR=$DOCKERDIR, HOSTNAME=$HOSTNAME, SERVER_IP=$SERVER_IP"
fi

# Step 1: Install Edge TPU runtime and dependencies
install_tpu_runtime() {
  log "INFO" "Installing Coral Edge TPU runtime and dependencies..."

  # Add Coral repository
  if [ ! -f /etc/apt/sources.list.d/coral-edgetpu.list ]; then
    log "INFO" "Adding Coral repository..."
    echo "deb [signed-by=/usr/share/keyrings/coral-edgetpu-archive-keyring.gpg] https://packages.cloud.google.com/apt coral-edgetpu-stable main" | sudo tee /etc/apt/sources.list.d/coral-edgetpu.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/coral-edgetpu-archive-keyring.gpg
    [ $debug_mode -eq 1 ] && log "DEBUG" "Added Coral repository and GPG key"
  else
    log "INFO" "Coral repository already exists"
  fi

  # Update package index
  log "INFO" "Running apt update..."
  sudo apt update
  if [ $? -ne 0 ]; then
    log "ERROR" "Failed to run apt update"
    exit 1
  fi
  [ $debug_mode -eq 1 ] && log "DEBUG" "apt update completed"

  # Install packages
  local install_cmd="install -y"
  [ $reinstall -eq 1 ] && install_cmd="install --reinstall -y"
  log "INFO" "Installing libedgetpu1-std, libusb-1.0-0..."
  sudo apt $install_cmd libedgetpu1-std libusb-1.0-0
  if [ $? -ne 0 ]; then
    log "ERROR" "Failed to install libedgetpu1-std, libusb-1.0-0"
    exit 1
  fi
  [ $debug_mode -eq 1 ] && log "DEBUG" "Installed packages: libedgetpu1-std, libusb-1.0-0"

  # Check Python version for compatibility
  local python_version
  python_version=$(python3 --version | awk '{print $2}')
  if [[ "$python_version" < "3.10" ]]; then
    log "INFO" "Installing python3-pycoral (Python $python_version detected)..."
    sudo apt $install_cmd python3-pycoral
    if [ $? -ne 0 ]; then
      log "WARN" "Failed to install python3-pycoral; continuing without it"
    else
      [ $debug_mode -eq 1 ] && log "DEBUG" "Installed python3-pycoral"
    fi
  else
    log "INFO" "Python $python_version detected; installing python3-tflite-runtime instead"
    sudo apt $install_cmd python3-tflite-runtime
    if [ $? -ne 0 ]; then
      log "WARN" "Failed to install python3-tflite-runtime; continuing without it"
    else
      [ $debug_mode -eq 1 ] && log "DEBUG" "Installed python3-tflite-runtime"
    fi
  fi

  # Verify library
  if [ -f /usr/lib/x86_64-linux-gnu/libedgetpu.so.1.0 ]; then
    log "INFO" "Edge TPU library found: /usr/lib/x86_64-linux-gnu/libedgetpu.so.1.0"
  else
    log "ERROR" "Edge TPU library not found"
    exit 1
  fi
}

# Step 2: Verify TPU detection and permissions
verify_tpu() {
  log "INFO" "Verifying Coral USB TPU detection..."

  # Check lsusb
  local tpu_info
  tpu_info=$(lsusb | grep -i "1a6e:089a")
  if [ -z "$tpu_info" ]; then
    log "ERROR" "Coral USB TPU not detected. Check LXC USB passthrough on Proxmox host."
    log "INFO" "Run 'lsusb' on Proxmox host to verify TPU (ID 1a6e:089a) and ensure passthrough in /etc/pve/lxc/100.conf."
    exit 1
  fi
  log "INFO" "TPU detected: $tpu_info"
  [ $debug_mode -eq 1 ] && log "DEBUG" "lsusb output: $tpu_info"

  # Get USB path
  local usb_path
  usb_path=$(lsusb -d 1a6e:089a | awk '{print $2 "/" $4}' | sed 's/://')
  if [ -z "$usb_path" ]; then
    log "ERROR" "Failed to determine USB device path"
    exit 1
  fi
  log "INFO" "TPU device path: /dev/bus/usb/$usb_path"
  [ $debug_mode -eq 1 ] && log "DEBUG" "USB path extracted: /dev/bus/usb/$usb_path"

  # Verify device exists
  if [ ! -e "/dev/bus/usb/$usb_path" ]; then
    log "ERROR" "TPU device not found at /dev/bus/usb/$usb_path. Check LXC USB passthrough."
    log "INFO" "Run 'lsusb -tv' on Proxmox host to confirm path and update /etc/pve/lxc/100.conf."
    exit 1
  fi

  # Fix permissions
  log "INFO" "Setting TPU device permissions..."
  sudo chmod 666 /dev/bus/usb/$usb_path
  sudo chown root:plugdev /dev/bus/usb/$usb_path
  if [ $? -ne 0 ]; then
    log "ERROR" "Failed to set permissions for /dev/bus/usb/$usb_path"
    exit 1
  fi
  log "INFO" "Permissions set for /dev/bus/usb/$usb_path"
  [ $debug_mode -eq 1 ] && log "DEBUG" "Set chmod 666 and chown root:plugdev on /dev/bus/usb/$usb_path"

  # Add user to plugdev group
  log "INFO" "Adding user divix to plugdev group..."
  sudo usermod -aG plugdev divix
  if [ $? -eq 0 ]; then
    log "INFO" "User divix added to plugdev group"
    [ $debug_mode -eq 1 ] && log "DEBUG" "User divix added to plugdev group"
  else
    log "WARN" "Failed to add divix to plugdev group; continuing"
  fi

  # Test TPU runtime
  log "INFO" "Testing TPU runtime..."
  if python3 -c "import tflite_runtime.interpreter as tflite; interpreter = tflite.Interpreter(model_path='/tmp/dummy.tflite', experimental_delegates=[tflite.load_delegate('libedgetpu.so.1.0')]); print('TPU OK')" 2>/dev/null; then
    log "INFO" "TPU runtime test passed"
  else
    log "WARN" "TPU runtime test failed; continuing as it may still work in Frigate"
  fi
}

# Step 3: Provide Docker Compose guidance
docker_compose_guidance() {
  log "INFO" "Docker Compose configuration guidance..."

  local docker_file="$DOCKERDIR/docker-compose-$HOSTNAME.yml"
  if [ ! -f "$docker_file" ]; then
    log "ERROR" "Docker Compose file not found: $docker_file"
    exit 1
  fi

  local device_snippet="
    devices:
      - /dev/bus/usb:/dev/bus/usb  # Coral USB TPU
      - /dev/dri:/dev/dri  # NVIDIA GPU
    group_add:
      - plugdev  # USB access
  "
  log "INFO" "Ensure the 'frigate' service in $docker_file includes:"
  log "INFO" "$device_snippet"
  log "INFO" "Manually update $docker_file and run: dcchk && dcpull && dcrestart frigate"
}

# Step 4: Provide LXC USB passthrough guidance
lxc_hook_guidance() {
  log "INFO" "LXC USB passthrough configuration guidance..."

  local lxc_snippet="
lxc.autodev: 1
lxc.hook.autodev: /etc/pve/lxc/usb_tpu_hook.sh
lxc.cgroup2.devices.allow: c 189:* rwm
  "
  log "INFO" "Ensure /etc/pve/lxc/100.conf on the Proxmox host includes:"
  log "INFO" "$lxc_snippet"

  local hook_snippet="
#!/bin/bash
VENDOR_ID=\"1a6e\"
PRODUCT_ID=\"089a\"
USB_DEVICE=\$(lsusb -d \${VENDOR_ID}:\${PRODUCT_ID} | awk '{print \$2 \"/\" \$4}' | sed 's/://')
if [ -n \"\$USB_DEVICE\" ]; then
  mkdir -p \${LXC_ROOTFS_MOUNT}/dev/bus/usb/\${USB_DEVICE%/*}
  mknod \${LXC_ROOTFS_MOUNT}/dev/bus/usb/\$USB_DEVICE c 189 \$(stat -c %t:%T /dev/bus/usb/\$USB_DEVICE | xargs printf %d)
  chmod 666 \${LXC_ROOTFS_MOUNT}/dev/bus/usb/\$USB_DEVICE
  chown root:plugdev \${LXC_ROOTFS_MOUNT}/dev/bus/usb/\$USB_DEVICE
fi
  "
  log "INFO" "Create /etc/pve/lxc/usb_tpu_hook.sh on the Proxmox host with content like:"
  log "INFO" "$hook_snippet"
  log "INFO" "Then run: chmod +x /etc/pve/lxc/usb_tpu_hook.sh && pct stop 100 && pct start 100"
}

# Main execution
log "INFO" "Starting Frigate TPU fix script..."
install_tpu_runtime
verify_tpu
docker_compose_guidance
lxc_hook_guidance
log "INFO" "Frigate TPU fix completed. Check logs: dclogs frigate | grep -E '(detector|coral|edgetpu)'"