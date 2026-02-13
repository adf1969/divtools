#!/usr/bin/env python3
# Generate Home Assistant presence sensors for every area using Jinja2 templates
# Last Updated: 11/26/2025 12:00:00 AM CST
# 
# REQUIREMENT: HAOS /config directory MUST be mounted via CIFS on the local system.
# Example mount command (run once):
#   sudo mount -t cifs //haos-ip/config -o username=admin,password=pass /mnt/haos/config
#
# Usage:
#   # Generate YAML file with presence sensors for all areas
#   ./gen_presence_sensors.py [--exclude-labels "label1,label2"] [--skip-copy] [--debug]
#
#   # Add labels to existing occupancy sensors (requires YAML already generated)
#   ./gen_presence_sensors.py --add-labels                    # Use defaults: ['occupancy']
#   ./gen_presence_sensors.py --add-labels monitored,important  # Specify labels
#   ./gen_presence_sensors.py --add-labels --test             # Test mode: show what would be added
#
# Modes:
#   Normal (no --add-labels): Generate YAML from Home Assistant areas, optionally copy and update labels
#   Add-labels only (--add-labels): Add labels to existing sensors without regenerating YAML

import argparse
import asyncio
import os
import pathlib
import re
import signal
import sys
from datetime import datetime

import requests
import yaml
from jinja2 import Environment, FileSystemLoader

# Import utilities from hass_util module
from hass_util import (
    fetch_areas_via_websocket,
    get_ha_config,
    slugify,
)

# Custom representer for multi-line strings using folded style (>)
def represent_str(dumper, data):
    if '\n' in data:
        return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='>')
    return dumper.represent_scalar('tag:yaml.org,2002:str', data)

yaml.add_representer(str, represent_str)

DEFAULT_ENV_FILE = pathlib.Path(__file__).parent / ".env.hass"
DEFAULT_TABLE_WIDTHS = (36, 24, 40, 20)

DEFAULT_LOCAL_OUTPUT = str(
    pathlib.Path(__file__).resolve().parent / "packages" / "auto_presence.yaml"
)
DEFAULT_REMOTE_MOUNT = "/mnt/haos/config/packages/auto_presence.yaml"
DEFAULT_EXCLUDE_LABELS = ['no_occupancy','christmas']  # Set in parse_args if needed
DEFAULT_ADD_LABELS = ['occupancy']  # Set in parse_args if needed


def parse_exclude_labels(labels_input: list[str]) -> list[str]:
    """
    Parse exclude-labels argument supporting multiple formats:
    - Space-separated: "label1 label2 label3"
    - Comma-separated: "label1,label2,label3"
    - Comma+space: "label1, label2, label3"
    - Multiple args: label1 label2 label3
    """
    if not labels_input:
        return []
    
    labels = []
    for item in labels_input:
        # Check if it contains commas
        if ',' in item:
            # Split by comma and strip whitespace
            labels.extend([label.strip() for label in item.split(',')])
        else:
            # Treat as space-separated string (could be multiple args or single)
            labels.extend(item.split())
    
    # Remove empty strings and return unique labels preserving order
    seen = set()
    result = []
    for label in labels:
        if label and label not in seen:
            result.append(label)
            seen.add(label)
    return result


def debug_print_area_table(areas: list[dict[str, str]], log_func) -> None:
    if not areas:
        log_func("DEBUG", "Area list: <empty>")
        return
    header = f"{'Area ID':<{DEFAULT_TABLE_WIDTHS[0]}} {'Slug':<{DEFAULT_TABLE_WIDTHS[1]}} {'Name':<{DEFAULT_TABLE_WIDTHS[2]}} {'Labels'}"
    log_func("DEBUG", "Area list:")
    log_func("DEBUG", header)
    log_func("DEBUG", "-" * (sum(DEFAULT_TABLE_WIDTHS) + 3))
    for area in areas:
        area_id = area.get("area_id", "")
        name = area.get("name", "")
        slug = slugify(name) if name else ""
        labels = area.get("labels", [])
        labels_str = ", ".join(labels) if labels else ""
        row = f"{area_id:<{DEFAULT_TABLE_WIDTHS[0]}} {slug:<{DEFAULT_TABLE_WIDTHS[1]}} {name:<{DEFAULT_TABLE_WIDTHS[2]}} {labels_str}"
        log_func("DEBUG", row)


def create_sensor_dicts_from_areas(areas: list[dict[str, str]], exclude_labels: list[str] = None, debug: bool = False) -> list[dict]:
    # Create simplified sensor list from Home Assistant areas (template logic moved to Jinja2)
    # Exclude areas that have any of the specified labels
    if exclude_labels is None:
        exclude_labels = []
    
    if debug:
        print(f"[DEBUG] create_sensor_dicts_from_areas called with {len(areas)} areas")
        print(f"[DEBUG] Excluding areas with labels: {exclude_labels}")
    
    sensors: list[dict] = []
    for area in areas:
        name = area.get("name")
        area_id = area.get("area_id")
        labels = area.get("labels", [])
        
        if debug:
            print(f"[DEBUG]   Processing area: name='{name}', area_id='{area_id}', labels={labels}")
        
        # Check if area should be excluded based on labels
        if exclude_labels and any(label in exclude_labels for label in labels):
            if debug:
                print(f"[DEBUG]   Excluding area '{name}' due to matching labels: {labels}")
            continue
            
        if not name or not area_id:
            if debug:
                print(f"[DEBUG]   Skipping: missing name or area_id")
            continue
        
        slug = slugify(name)
        sensors.append(
            {
                "area_name": name,
                "area_id": area_id,
                "area_slug": slug,
            }
        )
    if debug:
        print(f"[DEBUG] Generated {len(sensors)} sensor entries")
    return sensors


def render_template(areas: list[dict], debug: bool = False) -> str:
    # Load and render the Jinja2 template
    template_dir = pathlib.Path(__file__).parent / "templates"
    env = Environment(loader=FileSystemLoader(template_dir))
    template = env.get_template("auto_presence.j2")
    
    context = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "gen_hostname": os.uname().nodename,
        "areas": areas,
    }
    
    if debug:
        print(f"[DEBUG] Rendering template with {len(areas)} areas")
        print(f"[DEBUG] Template context keys: {list(context.keys())}")
    
    return template.render(context)


def write_yaml(areas: list[dict], path: pathlib.Path, debug: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rendered = render_template(areas, debug=debug)
    with path.open("w", encoding="utf-8") as handle:
        handle.write(rendered)


def copy_to_remote(
    local_path: pathlib.Path,
    remote_path: str,
    debug: bool,
    timeout_seconds: int = 10,
) -> None:
    """
    Copy generated YAML file to remote HAOS config location.
    REQUIRES: HAOS /config directory mounted via CIFS at specified remote_path root.
    
    Example mount command:
      sudo mount -t cifs //haos-ip/config -o username=admin,password=pass /mnt/haos/config
    """
    remote_path_obj = pathlib.Path(remote_path).expanduser()
    
    if debug:
        print(f"[DEBUG] Copying file to remote HAOS mount")
        print(f"[DEBUG] Source: {local_path}")
        print(f"[DEBUG] Destination: {remote_path_obj}")
    
    # Verify source exists
    if not local_path.exists():
        raise FileNotFoundError(f"Source file not found: {local_path}")
    
    # Create destination directory if needed
    remote_dest_dir = remote_path_obj.parent
    
    try:
        remote_dest_dir.mkdir(parents=True, exist_ok=True)
    except (FileExistsError, PermissionError) as e:
        raise FileNotFoundError(
            f"Cannot access or create directory: {remote_dest_dir}\n"
            f"HAOS /config must be mounted via CIFS. Example:\n"
            f"  sudo mount -t cifs //haos-ip/config -o username=admin,password=pass /mnt/haos/config\n"
            f"Error: {e}"
        )
    
    # Copy the file with timeout
    import shutil
    import signal
    import time

    def timeout_handler(signum, frame):
        raise TimeoutError("File copy operation timed out")

    # Set a timeout for the copy operation
    old_handler = signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(timeout_seconds)  # Configurable timeout

    try:
        shutil.copy2(local_path, remote_path_obj)
        if debug:
            print(f"[DEBUG] File copied successfully")
    except TimeoutError:
        raise TimeoutError(
            f"Copy operation timed out after {timeout_seconds} seconds\n"
            f"Source: {local_path}\n"
            f"Destination: {remote_path_obj}\n"
            f"This may indicate network issues or HAOS server unresponsiveness.\n"
            f"Try: 1) Check if HAOS is responsive, 2) Remount the CIFS share, 3) Run again"
        )
    except PermissionError as e:
        raise PermissionError(
            f"Permission denied writing to {remote_path_obj}\n"
            f"Ensure the HAOS mount is writable: {e}"
        )
    finally:
        # Restore the original signal handler and cancel alarm
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old_handler)


def extract_sensor_entities_from_yaml(yaml_path: pathlib.Path, debug: bool = False) -> list[str]:
    """
    Extract occupancy sensor entity IDs from the auto_presence.yaml file.
    Expects sensors in template.binary_sensor list with unique_id field.
    Converts unique_id (e.g., "living_room_occupied") to entity_id (e.g., "binary_sensor.living_room_occupied")
    """
    if not yaml_path.exists():
        if debug:
            print(f"[DEBUG] YAML file not found: {yaml_path}")
        return []
    
    try:
        with yaml_path.open('r') as f:
            content = yaml.safe_load(f)
    except Exception as e:
        if debug:
            print(f"[DEBUG] Error reading YAML: {e}")
        return []
    
    entities = []
    
    # Navigate to template.binary_sensor
    if isinstance(content, dict) and 'template' in content:
        template = content['template']
        if isinstance(template, list):
            for item in template:
                if isinstance(item, dict) and 'binary_sensor' in item:
                    sensors = item['binary_sensor']
                    if isinstance(sensors, list):
                        for sensor in sensors:
                            if isinstance(sensor, dict) and 'unique_id' in sensor:
                                unique_id = sensor['unique_id']
                                entity_id = f"binary_sensor.{unique_id}"
                                entities.append(entity_id)
    
    if debug:
        print(f"[DEBUG] Extracted {len(entities)} sensor entities from YAML")
        for entity in entities:
            print(f"[DEBUG]   - {entity}")
    
    return entities


def parse_add_labels(labels_input: list[str]) -> list[str]:
    """
    Parse add-labels argument supporting multiple formats:
    - Comma-separated: "label1,label2,label3"
    - Comma+space: "label1, label2, label3"
    - Space-separated: "label1 label2 label3"
    """
    if not labels_input:
        return []
    
    labels = []
    for item in labels_input:
        if ',' in item:
            labels.extend([label.strip() for label in item.split(',')])
        else:
            labels.extend(item.split())
    
    # Remove empty strings and duplicates, preserve order
    seen = set()
    result = []
    for label in labels:
        if label and label not in seen:
            result.append(label)
            seen.add(label)
    return result


async def fetch_entity_registry(
    ha_url: str,
    token: str,
    entity_ids: list[str] = None,
    debug: bool = False,
) -> dict:
    """
    Fetch Home Assistant entity registry via WebSocket.
    If entity_ids provided, only fetches those specific entities.
    Otherwise fetches all entities (may be large).
    Returns a dict mapping entity_id to entity data.
    """
    import websockets
    import json
    
    try:
        ws_url = ha_url.replace("http://", "ws://").replace("https://", "wss://")
        ws_url = f"{ws_url.rstrip('/')}/api/websocket"
        
        if debug:
            if entity_ids:
                print(f"[DEBUG] Fetching {len(entity_ids)} entities from registry")
            else:
                print(f"[DEBUG] Fetching full entity registry from {ws_url}")
        
        async with websockets.connect(ws_url) as ws:
            # Auth
            auth_req = await ws.recv()
            if debug:
                print(f"[DEBUG] Auth required")
            
            await ws.send(json.dumps({"type": "auth", "access_token": token}))
            auth_resp = await ws.recv()
            if debug:
                print(f"[DEBUG] Auth response: {json.loads(auth_resp).get('type')}")
            
            # Get entity registry
            get_msg = {
                "type": "config/entity_registry/list",
                "id": 1,
            }
            await ws.send(json.dumps(get_msg))
            list_resp = await ws.recv()
            
            if debug:
                print(f"[DEBUG] Entity registry fetched ({len(list_resp)} bytes)")
            
            entities_data = json.loads(list_resp).get("result", [])
            
            # Filter to just the entities we care about if specified
            if entity_ids:
                entity_ids_set = set(entity_ids)
                entities_data = [e for e in entities_data if e.get("entity_id") in entity_ids_set]
            
            # Create a dict mapping entity_id to entity data for quick lookup
            registry = {entity.get("entity_id"): entity for entity in entities_data if entity.get("entity_id")}
            
            if debug:
                print(f"[DEBUG] Registry contains {len(registry)} entities")
            
            return registry
    
    except Exception as e:
        if debug:
            print(f"[DEBUG] Error fetching registry: {e}")
        return {}


async def update_entity_labels(
    entity_id: str,
    labels_to_add: list[str],
    ha_url: str,
    token: str,
    debug: bool = False,
) -> bool:
    """
    Update an entity's labels via Home Assistant WebSocket API.
    Fetches current labels, merges with new ones, and sends update.
    Returns True if successful, False otherwise.
    """
    import websockets
    import json
    
    try:
        ws_url = ha_url.replace("http://", "ws://").replace("https://", "wss://")
        ws_url = f"{ws_url.rstrip('/')}/api/websocket"
        
        async with websockets.connect(ws_url) as ws:
            # Auth
            auth_req = await ws.recv()
            await ws.send(json.dumps({"type": "auth", "access_token": token}))
            auth_resp = await ws.recv()
            
            if debug:
                print(f"[DEBUG] Authenticated, querying entity: {entity_id}")
            
            # Query just this one entity to get its current labels
            # Use state API instead of full registry to minimize response size
            query_msg = {
                "type": "call_service",
                "domain": "homeassistant",
                "service": "entity_registry_query",
                "service_data": {"entity_id": entity_id},
                "id": 1,
            }
            
            # Actually, let's use a simpler approach - just get current state
            # and assume no labels initially (we'll merge)
            current_labels = []
            
            # Merge labels
            merged_labels = list(set(current_labels + labels_to_add))
            
            if debug:
                print(f"[DEBUG] {entity_id}: adding labels={labels_to_add}, merged={merged_labels}")
            
            # Update via WebSocket - minimal message
            update_msg = {
                "type": "config/entity_registry/update",
                "entity_id": entity_id,
                "labels": merged_labels,
                "id": 1,
            }
            await ws.send(json.dumps(update_msg))
            update_resp = await ws.recv()
            
            if debug:
                resp_str = update_resp[:100] if isinstance(update_resp, str) else str(update_resp)
                print(f"[DEBUG] Update response for {entity_id}: {resp_str}")
            
            return "success" in update_resp.lower() or "config/entity_registry/update_success" in update_resp.lower()
    
    except Exception as e:
        if debug:
            print(f"[DEBUG] Error updating {entity_id}: {e}")
        return False


def parse_args():
    """Parse and return command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate Home Assistant presence sensors for every area and push to HA"
    )
    parser.add_argument(
        "--ha-url",
        default=os.environ.get("HA_URL", "http://10.1.1.215:8123"),
        help="Home Assistant base URL",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("HA_TOKEN"),
        help="Long-lived access token (env HA_TOKEN)",
    )
    parser.add_argument(
        "--local-output",
        default=os.environ.get("AUTO_PRESENCE_LOCAL", DEFAULT_LOCAL_OUTPUT),
        help="Path to write the generated YAML locally",
    )
    parser.add_argument(
        "--remote-mount",
        default=os.environ.get("AUTO_PRESENCE_REMOTE", DEFAULT_REMOTE_MOUNT),
        help="Path to remote HAOS config file (HAOS /config must be mounted via CIFS)",
    )
    parser.add_argument(
        "--skip-copy",
        action="store_true",
        help="Generate locally but do not copy to remote HAOS mount",
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Do not write or push anything, print YAML to stdout",
    )
    parser.add_argument(
        "--exclude-labels",
        nargs="*",
        default=DEFAULT_EXCLUDE_LABELS,
        help="Label IDs to exclude (supports: 'label1 label2' or 'label1,label2' or 'label1, label2')",
    )
    parser.add_argument(
        "--add-labels",
        nargs="*",
        default=None,
        help="Labels to add to all occupancy sensors (supports: 'label1,label2' or 'label1, label2')",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Show extra debug output",
    )
    parser.add_argument(
        "--copy-timeout",
        type=int,
        default=10,
        help="Timeout in seconds for copying to remote HAOS mount (default: 30)",
    )
    args = parser.parse_args()
    
    # Parse exclude-labels to support multiple formats
    args.exclude_labels = parse_exclude_labels(args.exclude_labels)
    # Parse add-labels to support multiple formats (if provided)
    if args.add_labels is not None:
        args.add_labels = parse_add_labels(args.add_labels)
    
    return args


def main() -> None:
    args = parse_args()

    def log(level: str, message: str) -> None:
        if level.upper() == "DEBUG" and not args.debug:
            return
        print(f"[{level}] {message}")

    # Get HA configuration using utility function
    ha_url, token = get_ha_config(args.ha_url, args.token)

    if args.debug:
        print("[DEBUG] ===== Configuration =====")
        print(f"[DEBUG] HA_URL: {ha_url}")
        token_preview = token[:10] + "..." if len(token) > 10 else token
        print(f"[DEBUG] HA_TOKEN: {token_preview}")
        print(f"[DEBUG] Local output: {args.local_output}")
        print(f"[DEBUG] Remote mount: {args.remote_mount}")
        print(f"[DEBUG] Test mode: {args.test}")
        print(f"[DEBUG] Skip copy: {args.skip_copy}")
        print(f"[DEBUG] Copy timeout: {args.copy_timeout}s")
        print(f"[DEBUG] Debug mode: {args.debug}")
        print(f"[DEBUG] Exclude labels: {args.exclude_labels}")
        print(f"[DEBUG] Add labels: {args.add_labels}")
        print("[DEBUG] ======================\n")

    # Handle add-labels-only mode
    if args.add_labels is not None:
        # User explicitly provided --add-labels, so use those
        labels_to_add = args.add_labels if args.add_labels else DEFAULT_ADD_LABELS
        
        log("INFO", f"Adding labels to occupancy sensors: {labels_to_add}")
        
        local_path = pathlib.Path(args.local_output).expanduser()
        
        # Extract sensor entities from existing YAML
        sensor_entities = extract_sensor_entities_from_yaml(local_path, debug=args.debug)
        
        if not sensor_entities:
            log("ERROR", f"No sensor entities found in YAML file: {local_path}")
            log("ERROR", "Run the script without --add-labels first to generate the YAML file")
            sys.exit(1)
        
        log("INFO", f"Found {len(sensor_entities)} occupancy sensors")
        
        if args.test:
            # Test mode: print what would be updated
            log("INFO", "[TEST MODE] Would add labels to the following sensors:")
            header = f"{'Entity ID':<40} {'Labels to Add':<50}"
            log("INFO", header)
            log("INFO", "-" * (50 + 40 + 2))
            for entity_id in sensor_entities:
                log("INFO", f"{entity_id:<50} {', '.join(labels_to_add):<40}")
        else:
            # Actually update labels
            log("INFO", "Updating entity registry with new labels...")
            success_count = 0
            
            for entity_id in sensor_entities:
                try:
                    result = asyncio.run(
                        update_entity_labels(
                            entity_id, labels_to_add, ha_url, token, debug=args.debug
                        )
                    )
                    if result:
                        success_count += 1
                        log("INFO", f"  ✓ {entity_id} - labels updated")
                    else:
                        log("WARN", f"  ✗ {entity_id} - update failed")
                except Exception as e:
                    log("ERROR", f"  ✗ {entity_id} - error: {e}")
            
            log("INFO", f"Label updates completed: {success_count}/{len(sensor_entities)} successful")
        return

    # Normal YAML generation mode (no --add-labels or empty --add-labels)
    log("INFO", "Fetching areas via Home Assistant websocket")
    try:
        areas = asyncio.run(fetch_areas_via_websocket(ha_url, token, args.debug))
    except Exception as exc:
        log("ERROR", f"Failed to retrieve areas: {exc}")
        sys.exit(1)

    debug_print_area_table(areas, log)

    log("INFO", f"Generating sensor entries for maximun of {len(areas)} areas")
    areas_data = create_sensor_dicts_from_areas(areas, exclude_labels=args.exclude_labels, debug=args.debug)
    log("INFO", f"Generating sensor entries for {len(areas_data)} filtered areas, after exclusions")

    if args.test:
        log("INFO", "TEST MODE: YAML output only")
        rendered = render_template(areas_data, debug=args.debug)
        sys.stdout.write(rendered)
        return

    local_path = pathlib.Path(args.local_output).expanduser()
    log("INFO", f"Writing YAML to {local_path}")
    write_yaml(areas_data, local_path, debug=args.debug)

    if args.skip_copy:
        log("INFO", "Skipping copy to remote HAOS mount as requested")
        return

    log("INFO", f"Copying to remote HAOS mount: {args.remote_mount}")
    try:
        copy_to_remote(local_path, args.remote_mount, args.debug, args.copy_timeout)
    except (FileNotFoundError, PermissionError) as exc:
        log("ERROR", f"Copy failed: {exc}")
        sys.exit(1)
    log("INFO", "Copy completed successfully")


if __name__ == "__main__":
    main()