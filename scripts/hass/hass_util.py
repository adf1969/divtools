#!/usr/bin/env python3
# Utility module for Home Assistant API interactions
# Last Updated: 11/25/2025 01:55:00 PM CST

import argparse
import asyncio
import json
import os
import pathlib
import re
import ssl
import sys

import websockets


DEFAULT_ENV_FILE = pathlib.Path(__file__).parent / ".env.hass"


def slugify(name: str) -> str:
    """Normalize area names into a slug compatible with Home Assistant IDs"""
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def load_env_file(path: pathlib.Path) -> None:
    """Load environment variables from a .env file"""
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("export "):
            stripped = stripped[len("export "):]
        if "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def get_ha_config(ha_url: str = None, token: str = None) -> tuple[str, str]:
    """
    Get Home Assistant URL and token from environment or arguments.
    Returns (ha_url, token) tuple.
    Exits with error if token is not available.
    """
    load_env_file(DEFAULT_ENV_FILE)
    
    ha_url = ha_url or os.environ.get("HA_URL", "http://10.1.1.215:8123")
    token = (token or os.environ.get("HA_TOKEN", "")).strip()
    
    if not token:
        print("[ERROR] HA token is required via --token or HA_TOKEN environment variable", file=sys.stderr)
        sys.exit(1)
    
    return ha_url, token


async def fetch_areas_via_websocket(ha_url: str, token: str, debug: bool = False) -> list[dict[str, str]]:
    """Fetch areas via HA WebSocket API. Only pass ssl context for wss:// URLs."""
    ws_url = ha_url.replace("http://", "ws://").replace("https://", "wss://")
    ws_url = f"{ws_url.rstrip('/')}/api/websocket"
    secure = ws_url.startswith("wss://")
    if debug:
        print(f"[DEBUG] Connecting to WebSocket: {ws_url} (secure={secure})")
    connect_kwargs = {}
    if secure:
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        connect_kwargs["ssl"] = ssl_context
    connect_result = websockets.connect(ws_url, **connect_kwargs)
    if hasattr(connect_result, 'recv') and not asyncio.iscoroutine(connect_result):
        websocket = connect_result
    else:
        websocket = await connect_result
    try:
        auth_required = await websocket.recv()
        if debug:
            print(f"[DEBUG] Auth required message: {auth_required}")
        auth_message = json.dumps({"type": "auth", "access_token": token})
        await websocket.send(auth_message)
        auth_result = await websocket.recv()
        if debug:
            print(f"[DEBUG] Auth result: {auth_result}")
        result_data = json.loads(auth_result)
        if result_data.get("type") != "auth_ok":
            raise RuntimeError(f"Authentication failed: {auth_result}")
        request_id = 1
        list_message = json.dumps({"id": request_id, "type": "config/area_registry/list"})
        await websocket.send(list_message)
        if debug:
            print("[DEBUG] Sent area registry list request")
        response = await websocket.recv()
        if debug:
            print(f"[DEBUG] Received response length: {len(response)} bytes")
        data = json.loads(response)
        if not data.get("success"):
            raise RuntimeError(f"Failed to list areas: {data}")
        areas = data.get("result", [])
        if debug:
            print(f"[DEBUG] Retrieved {len(areas)} areas")
        return areas
    finally:
        try:
            await websocket.close()
        except Exception:
            pass


async def fetch_labels_via_websocket(ha_url: str, token: str, debug: bool = False) -> list[dict[str, str]]:
    """Fetch labels via HA WebSocket API. Only pass ssl context for wss:// URLs."""
    ws_url = ha_url.replace("http://", "ws://").replace("https://", "wss://")
    ws_url = f"{ws_url.rstrip('/')}/api/websocket"
    secure = ws_url.startswith("wss://")
    if debug:
        print(f"[DEBUG] Connecting to WebSocket: {ws_url} (secure={secure})")
    connect_kwargs = {}
    if secure:
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        connect_kwargs["ssl"] = ssl_context
    connect_result = websockets.connect(ws_url, **connect_kwargs)
    if hasattr(connect_result, 'recv') and not asyncio.iscoroutine(connect_result):
        websocket = connect_result
    else:
        websocket = await connect_result
    try:
        auth_required = await websocket.recv()
        if debug:
            print(f"[DEBUG] Auth required message: {auth_required}")
        auth_message = json.dumps({"type": "auth", "access_token": token})
        await websocket.send(auth_message)
        auth_result = await websocket.recv()
        if debug:
            print(f"[DEBUG] Auth result: {auth_result}")
        result_data = json.loads(auth_result)
        if result_data.get("type") != "auth_ok":
            raise RuntimeError(f"Authentication failed: {auth_result}")
        request_id = 1
        list_message = json.dumps({"id": request_id, "type": "config/label_registry/list"})
        await websocket.send(list_message)
        if debug:
            print("[DEBUG] Sent label registry list request")
        response = await websocket.recv()
        if debug:
            print(f"[DEBUG] Received response length: {len(response)} bytes")
        data = json.loads(response)
        if not data.get("success"):
            raise RuntimeError(f"Failed to list labels: {data}")
        labels = data.get("result", [])
        if debug:
            print(f"[DEBUG] Retrieved {len(labels)} labels")
        return labels
    finally:
        try:
            await websocket.close()
        except Exception:
            pass


def print_areas_table(areas: list[dict[str, str]], show_labels: bool = True) -> None:
    """Print areas in a formatted table"""
    if not areas:
        print("No areas found")
        return
    
    # Determine column widths
    col_widths = [36, 24, 40, 30] if show_labels else [36, 24, 40]
    
    if show_labels:
        header = f"{'Area ID':<{col_widths[0]}} {'Slug':<{col_widths[1]}} {'Name':<{col_widths[2]}} {'Labels':<{col_widths[3]}}"
    else:
        header = f"{'Area ID':<{col_widths[0]}} {'Slug':<{col_widths[1]}} {'Name'}"
    
    print(header)
    print("-" * sum(col_widths[:3 if not show_labels else 4]))
    
    for area in areas:
        area_id = area.get("area_id", "")
        name = area.get("name", "")
        slug = slugify(name) if name else ""
        
        if show_labels:
            labels = area.get("labels", [])
            labels_str = ", ".join(labels) if labels else ""
            row = f"{area_id:<{col_widths[0]}} {slug:<{col_widths[1]}} {name:<{col_widths[2]}} {labels_str}"
        else:
            row = f"{area_id:<{col_widths[0]}} {slug:<{col_widths[1]}} {name}"
        
        print(row)


def print_labels_table(labels: list[dict[str, str]]) -> None:
    """Print labels in a formatted table"""
    if not labels:
        print("No labels found")
        return
    
    col_widths = [30, 30, 10, 20, 20]
    header = f"{'Label ID':<{col_widths[0]}} {'Name':<{col_widths[1]}} {'Color':<{col_widths[2]}} {'Icon':<{col_widths[3]}} {'Description':<{col_widths[4]}}"
    
    print(header)
    print("-" * (sum(col_widths) + 10))
    
    for label in labels:
        label_id = label.get("label_id", "")
        name = label.get("name", "")
        color = label.get("color", "")
        icon = label.get("icon", "")
        description = label.get("description", "")
        
        row = f"{label_id:<{col_widths[0]}} {name:<{col_widths[1]}} {color:<{col_widths[2]}} {icon:<{col_widths[3]}} {description}"
        print(row)


def parse_args() -> argparse.Namespace:
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Home Assistant utility for listing areas and labels"
    )
    parser.add_argument(
        "--ha-url",
        default=None,
        help="Home Assistant base URL (env: HA_URL, default: http://10.1.1.215:8123)",
    )
    parser.add_argument(
        "--token",
        default=None,
        help="Long-lived access token (env: HA_TOKEN)",
    )
    parser.add_argument(
        "--lsa", "--ls-areas",
        dest="list_areas",
        action="store_true",
        help="List all areas",
    )
    parser.add_argument(
        "--lsl", "--ls-labels",
        dest="list_labels",
        action="store_true",
        help="List all labels",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Show extra debug output",
    )
    return parser.parse_args()


def main() -> None:
    """Main entry point when run as a script"""
    args = parse_args()
    
    # If no listing option specified, show both
    if not args.list_areas and not args.list_labels:
        args.list_areas = True
        args.list_labels = True
    
    ha_url, token = get_ha_config(args.ha_url, args.token)
    
    if args.debug:
        print("[DEBUG] ===== Configuration =====")
        print(f"[DEBUG] HA_URL: {ha_url}")
        token_preview = token[:10] + "..." if len(token) > 10 else token
        print(f"[DEBUG] HA_TOKEN: {token_preview}")
        print(f"[DEBUG] List areas: {args.list_areas}")
        print(f"[DEBUG] List labels: {args.list_labels}")
        print("[DEBUG] ======================\n")
    
    try:
        if args.list_areas:
            print("[INFO] Fetching areas from Home Assistant...")
            areas = asyncio.run(fetch_areas_via_websocket(ha_url, token, args.debug))
            print(f"\n{len(areas)} Areas:\n")
            print_areas_table(areas, show_labels=True)
        
        if args.list_labels:
            if args.list_areas:
                print("\n")  # Add spacing between tables
            
            print("[INFO] Fetching labels from Home Assistant...")
            labels = asyncio.run(fetch_labels_via_websocket(ha_url, token, args.debug))
            print(f"\n{len(labels)} Labels:\n")
            print_labels_table(labels)
    
    except Exception as exc:
        print(f"[ERROR] Failed to retrieve data: {exc}", file=sys.stderr)
        if args.debug:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
