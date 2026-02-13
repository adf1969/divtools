'''
@script generate_esppresense_yaml.py
@author andrew@avcorp.biz
07/20/2025 | V1 | Initial creation
07/20/2025 | V2 | Added CLI options for -f, -o, and -d
07/20/2025 | V3 | Support parsing SweetHome3D .sh3d/Home.xml files
07/20/2025 | V4 | Support multiple visible levels and corresponding background image calibration
07/20/2025 | V5 | Fixed YAML point formatting and ensured all coordinates are absolute
07/20/2025 | V6 | Fixed list style formatting of points to avoid YAML anchors
07/20/2025 | V7 | Enforced inline formatting of [x, y] coordinate pairs in YAML output
07/20/2025 | V8 | Added level/room listing filters and improved output formatting
07/20/2025 | V9 | Fixed block formatting of floors, rooms, and points in YAML output
07/20/2025 | V10 | Use level name (normalized) as level ID instead of GUID
07/20/2025 | V11 | Fix broken room-level association after ID normalization
07/20/2025 | V12 | Corrected coordinate scaling direction for ESPresense compatibility
'''

import pandas as pd
import yaml
from collections import defaultdict
import argparse
import zipfile
import xml.etree.ElementTree as ET
import math
import os
import sys

debug = False

# ---------------------------
# Coordinate Transformation
# ---------------------------
def compute_scale(bg):
    if debug:
        print(f"[DEBUG] scaleDistance (cm): {bg['scaleDistance']}")
        print("[DEBUG] Skipping scale calculation — using 100 px/m conversion")
    return 1.0  # Not used  # meters per pixel

def pixel_to_meters(x, y, ox, oy, scale):
    x_m = abs(x / 100.0)  # convert cm to meters and ensure positive
    y_m = abs(y / 100.0)
    if debug:  # hardcoded logic assumes 100cm to m
        debug_msg = f"[DEBUG] Raw input x={x}, y={y} → x_m={x_m}, y_m={y_m}"
        print(debug_msg)
    return [round(x_m, 3), round(y_m, 3)]

# ---------------------------
# Custom YAML Dumper
# ---------------------------
class BlockStyleDumper(yaml.SafeDumper):
    def ignore_aliases(self, data):
        return True

def represent_inline_list(dumper, data):
    if all(isinstance(i, (int, float)) for i in data):
        return dumper.represent_sequence('tag:yaml.org,2002:seq', data, flow_style=True)
    return dumper.represent_sequence('tag:yaml.org,2002:seq', data, flow_style=False)

yaml.add_representer(list, represent_inline_list, Dumper=BlockStyleDumper)

# ---------------------------
# Utility Functions
# ---------------------------
def normalize_id(name):
    return name.lower().replace(" ", "_")

# ---------------------------
# Process SH3D and Extract Data
# ---------------------------
def extract_levels_and_rooms(file_path):
    with zipfile.ZipFile(file_path, 'r') as z:
        with z.open('Home.xml') as f:
            tree = ET.parse(f)
            root = tree.getroot()

    levels = {}
    level_id_map = {}
    for level in root.findall("level"):
        if level.get("visible", "true") != "true":
            continue
        orig_id = level.get("id")
        level_name = level.get("name", "level")
        norm_id = level_name.lower().replace(" ", "_")
        levels[norm_id] = {
            "id": norm_id,
            "name": level_name,
            "elevation": level.get("elevation"),
            "height": level.get("height"),
            "orig_id": orig_id,
            "background": level.find("backgroundImage")
        }
        level_id_map[orig_id] = norm_id

    rooms_by_level = defaultdict(list)
    for room in root.findall("room"):
        level_ref = room.get("level")
        if level_ref in level_id_map:
            rooms_by_level[level_id_map[level_ref]].append(room.get("name") or "Unnamed")

    return levels, rooms_by_level, root

# ---------------------------
# Main Processing Logic
# ---------------------------
def process_sh3d(file_path, output_path=None, list_only=None, level_filter=None, nodes_only=False):
    levels, rooms_by_level, root = extract_levels_and_rooms(file_path)

    if list_only == 'levels':
        for lvl in levels.values():
            print(f"{lvl['id']}: {lvl['name']}")
        return
    elif list_only == 'all':
        for lvl_id, lvl in levels.items():
            print(f"{lvl_id}: {lvl['name']}")
            for room in rooms_by_level[lvl_id]:
                print(f"  - {room}")
        return
    elif list_only and list_only.startswith('rooms:'):
        target = list_only.split(':', 1)[1].lower()
        for lvl_id, lvl in levels.items():
            if target == lvl_id.lower() or target == lvl['name'].lower():
                print(f"Rooms in level '{lvl['name']}' ({lvl_id}):")
                for room in rooms_by_level[lvl_id]:
                    print(f"  - {room}")
                return
        print(f"Level '{target}' not found.")
        return

    floor_outputs = []
    for norm_id, level_info in levels.items():
        if level_filter and level_filter.lower() not in [norm_id.lower(), level_info["name"].lower()]:
            continue

        bg = level_info["background"]
        if bg is None:
            continue

        bg_attr = bg.attrib
        scale = compute_scale(bg_attr)
        ox = float(bg_attr['xOrigin'])
        oy = float(bg_attr['yOrigin'])

        rooms = []
        for room in root.findall("room"):
            if room.get("level") != level_info["orig_id"]:
                continue
            name = room.get("name") or "Unnamed"
            points = []
            for point in room.findall("point"):
                px = float(point.get("x"))
                py = float(point.get("y"))
                points.append(pixel_to_meters(px, py, ox, oy, scale))
            if points:
                points.append(points[0])
                rooms.append({
                    "id": normalize_id(name),
                    "name": name,
                    "points": points
                })
                if debug:
                    print(f"[DEBUG] Room '{name}' added to level '{norm_id}' with {len(points)} points")

        # Calculate bounds from room points
        all_points = [pt for room in rooms for pt in room['points']]
        if all_points:
            min_x = min(p[0] for p in all_points)
            min_y = min(p[1] for p in all_points)
            max_x = max(p[0] for p in all_points)
            max_y = max(p[1] for p in all_points)
            elevation_cm = float(level_info.get("elevation", 0))
            height_cm = float(level_info.get("height", 300))
            z_min = round(elevation_cm / 100, 3)
            z_max = round((elevation_cm + height_cm) / 100, 3)
            bounds_str = f"[[{max(0, round(min_x - 3, 3))}, {max(0, round(min_y - 3, 3))}, {z_min}], [{round(max_x + 3, 3)}, {round(max_y + 3, 3)}, {z_max}]]"
        else:
            bounds_str = "[[0, 0, 0], [10, 10, 3]]"

        floor_outputs.append({
            "id": norm_id,
            "name": level_info["name"],
            "bounds_str": bounds_str,
            "rooms": rooms
        })

        # Extract nodes from furniture elements
    nodes = []
    for piece in root.findall("pieceOfFurniture"):
        name = piece.get("name", "")
        if not name.startswith("node:"):
            continue
        desc = piece.get("description", "")
        if ", Floors:" in desc:
            raw_name = desc.split(", Floors:", 1)[0].strip()
        else:
            raw_name = name.split(":", 1)[1].strip()
        if ", Floors:" in desc:
            raw_name = desc.split(", Floors:", 1)[0].strip()
        else:
            raw_name = name.split(":", 1)[1].strip()
        node_id = normalize_id(raw_name)
        x = float(piece.get("x"))
        y = float(piece.get("y"))
        z = float(piece.get("elevation", "0"))
        x_m = round(abs(x / 100.0), 3)
        y_m = round(abs(y / 100.0), 3)
        z_m = round(z / 100.0, 3)
        desc = piece.get("description", "")
        floor_list = []
        if "Floors:" in desc:
            floor_list = [s.strip().lower().replace(" ", "_") for s in desc.split("Floors:", 1)[1].split(",")]
        nodes.append({
            "id": node_id,
            "name": raw_name,
            "point": [x_m, y_m, z_m],
            "floors": floor_list
        })

    output = {"floors": floor_outputs, "nodes": nodes}
    import datetime
    file_mod_ts = os.path.getmtime(file_path)
    file_mod_str = datetime.datetime.fromtimestamp(file_mod_ts).strftime('%Y-%m-%d %H:%M:%S')
    output_lines = [f"### Floor/Rooms/Nodes output produced by create_espc_yaml.py script", f"### BEGIN (Generated from file last modified: {file_mod_str})"]
    if not nodes_only:
        output_lines.append("floors:")
        for floor in output['floors']:
            output_lines.append(f"# Floor: {floor['name'].upper()}")
            output_lines.append(f"  - id: {floor['id']}")
            output_lines.append(f"    name: {floor['name']}")
            output_lines.append(f"    bounds: {floor['bounds_str']}")
            output_lines.append("")
            output_lines.append(f"    # ROOMS for {floor['name'].upper()}")
            output_lines.append(f"    rooms:")
            for room in floor['rooms']:
                output_lines.append(f"      - id: {room['id']}")
                output_lines.append(f"        name: {room['name']}")
                output_lines.append(f"        points:")
                for pt in room['points']:
                    output_lines.append(f"          - {pt}")

    if output['nodes']:
        selected_nodes = output['nodes']
        if level_filter:
            selected_nodes = [n for n in output['nodes'] if level_filter.lower() in n['floors']]
        if selected_nodes:
            output_lines.append("")
            output_lines.append("# NODES")
            output_lines.append("nodes:")
            for node in selected_nodes:
                output_lines.append(f"  - id: {node['id']}")
                output_lines.append(f"    name: {node['name']}")
                output_lines.append(f"    point: [{node['point'][0]}, {node['point'][1]}, {node['point'][2]}]")
                output_lines.append(f"    floors: {node['floors']}")

    output_lines.append("")
    output_lines.append("### END")
    yaml_output = "\n".join(output_lines)

    if not output_path and args.unique_output:
        ts_str = datetime.datetime.fromtimestamp(file_mod_ts).strftime('%Y-%m-%d-%H%M%S')
        prefix = args.unique_output if args.unique_output else "espc"
        output_path = f"{prefix}-{ts_str}.yaml"

    if output_path:
        with open(output_path, "w") as f:
            f.write(yaml_output)
        print(f"YAML configuration written to: {output_path}")
    else:
        print(yaml_output)

# ---------------------------
# Entry Point
# ---------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate ESPresense YAML config from .sh3d or Home.xml.")
    parser.add_argument("-u", "--unique-output", nargs="?", const="espc", help="Generate unique output filename with optional prefix")
    parser.add_argument("-f", "--file", required=True, help="Input .sh3d or Home.xml file path")
    parser.add_argument("-o", "--output", help="Output YAML file (stdout if not set)")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug output")
    parser.add_argument("-ls", "--list-all", action="store_true", help="List all levels and their rooms")
    parser.add_argument("-lsl", "--list-levels", action="store_true", help="List level IDs and names")
    parser.add_argument("-lsr", "--list-rooms", help="List rooms for a specific level name or ID")
    parser.add_argument("-l", "--level", help="Only process specific level (by ID or name)")
    parser.add_argument("-n", "--nodes-only", action="store_true", help="Output only nodes section")
    args = parser.parse_args()

    if args.file.lower().endswith(".sh3d"):
        list_flag = None
        if args.list_all:
            list_flag = 'all'
        elif args.list_levels:
            list_flag = 'levels'
        elif args.list_rooms:
            list_flag = f"rooms:{args.list_rooms}"
        debug = args.debug
        process_sh3d(args.file, args.output, list_only=list_flag, level_filter=args.level, nodes_only=args.nodes_only)
    elif os.path.basename(args.file).lower() == "home.xml":
        with zipfile.ZipFile("temp.sh3d", 'w') as z:
            z.write(args.file, arcname="Home.xml")
        process_sh3d("temp.sh3d", args.output, args.debug, level_filter=args.level)
        os.remove("temp.sh3d")
    else:
        print("Unsupported input file. Please provide a .sh3d or Home.xml file.")
