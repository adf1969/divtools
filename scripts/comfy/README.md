# ComfyUI Launcher & Service Wrapper

Last Updated: 12/15/2025 2:00:00 PM CST

Simple wrapper for ComfyUI that loads environment variables and manages execution via direct command or systemd service.

## Quick Usage

### Systemctl Mode (Recommended for Production)

```bash
# Control the systemd service
comfy_run start       # Start the service
comfy_run stop        # Stop the service
comfy_run restart     # Restart the service
comfy_run status      # Show service status
comfy_run enable      # Enable autostart on boot
comfy_run disable     # Disable autostart
```

### Direct Mode (for Development/Testing)

```bash
# Run comfy directly with venv activation
comfy_run                           # Use defaults from .env.comfy
comfy_run --gpu-only                # Add custom args
comfy_run --enable-manager          # Add manager plugin
```

## Configuration (.env.comfy)

Create `/opt/comfy/.env.comfy` to configure ComfyUI:

```bash
# Workspace location
COMFY_WORKSPACE=/opt/comfy

# Network settings
COMFY_LISTEN=0.0.0.0
COMFY_PORT=8188

# Additional arguments (passed to comfy launch)
COMFY_EXTRA_ARGS="--gpu-only --enable-manager --preview-method auto"
```

## How It Works

### Direct Mode
1. Sources `.bash_profile` to get `load_env_files()` and `python_venv_activate()`
2. Detects workspace (COMFY_WORKSPACE env var, /opt/comfy, or ~/comfy/ComfyUI)
3. Loads `.env.comfy` from workspace if it exists
4. Activates `comfy-env` Python virtual environment
5. Builds command from env vars: `comfy --workspace <path> launch --listen <addr> --port <port> <extra-args>`
6. Executes comfy command with all args

### Systemctl Mode
1. Wrapper detects systemctl commands (start/stop/restart/status/enable/disable)
2. Passes command to systemd: `systemctl <cmd> comfy.service`
3. Service unit loads `.env.comfy` and runs comfy with venv activation
4. Service manages lifecycle (auto-restart on failure, logging, etc.)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `COMFY_WORKSPACE` | `/opt/comfy` | Path to ComfyUI workspace |
| `COMFY_LISTEN` | `0.0.0.0` | Listen address (0.0.0.0 for LAN access) |
| `COMFY_PORT` | `8188` | Listen port |
| `COMFY_EXTRA_ARGS` | (empty) | Additional args passed to `comfy launch` |

## Systemd Service

### Installation

```bash
# Install and enable the service
sudo ./scripts/comfy/install_service.sh

# Or manually
sudo cp scripts/comfy/comfy.service.example /etc/systemd/system/comfy.service
sudo systemctl daemon-reload
sudo systemctl enable comfy.service
sudo systemctl start comfy.service
```

### Status & Logs

```bash
# Check service status
comfy_run status
# OR
sudo systemctl status comfy.service

# View logs
sudo journalctl -u comfy.service -f          # Follow logs
sudo journalctl -u comfy.service --since today
```

## Examples

### Change Port and Listen Address

Edit `/opt/comfy/.env.comfy`:

```bash
COMFY_LISTEN=127.0.0.1  # Localhost only
COMFY_PORT=9000
```

Then restart:

```bash
comfy_run restart
```

### Add Custom Arguments

Edit `/opt/comfy/.env.comfy`:

```bash
COMFY_EXTRA_ARGS="--gpu-only --cpu-vae --preview-method latent2rgb"
```

Then restart:

```bash
comfy_run restart
```

### Run Direct Mode with Custom Args

```bash
# Override defaults for one-off testing
comfy_run --listen 192.168.1.100 --port 9999
```

## Troubleshooting

### Service Won't Start

Check logs:

```bash
sudo journalctl -u comfy.service -n 50
```

Common issues:
- Missing venv: Ensure `/opt/divtools/scripts/venvs/comfy-env` exists
- Permissions: Ensure `divix:divix` owns `/opt/comfy`
- Port in use: Change `COMFY_PORT` in `.env.comfy`

### Permission Denied Errors

```bash
# Fix workspace permissions
sudo mkdir -p /opt/comfy/user
sudo chown -R divix:divix /opt/comfy
```

### Module Not Found

Install dependencies in venv:

```bash
source /opt/divtools/scripts/venvs/comfy-env/bin/activate
pip install -r /opt/comfy/requirements.txt
```

## Files

- `comfy_run.sh` - Main wrapper script
- `comfy.service.example` - Systemd unit template
- `install_service.sh` - Service installation helper
- `.env.comfy` - User configuration (create in workspace)
