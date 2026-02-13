"""
Script: o365_upd_akiflow.py

Description:
  Query an Office365 mailbox for messages in a date range and matching specified Outlook filters,
  then prepare actions for Akiflow and Todoist, skipping duplicates by MessageID.
  Also supports generating/updating the YAML filter file from Todoist projects,
  and generating an AutoHotKey categories list from Todoist child projects.

Usage:
  python o365_upd_akiflow.py \
    --category-file <path_to_yaml> [--clear-data-file] \
    [--update-from-todoist] [-a | --append] \
    [--gen-ahk-categories] \
    [--mailbox <folder_or_email> --days <num_days>] \
    [-d | --debug] [-t | --test]
"""
import os
import sys
import argparse
import requests
import re
import textwrap
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from typing import List, Dict, Optional, Set
from o365_auth_user import get_app_access_token, get_todoist_api_token, get_todoist_session
from colorama import Fore, Style, init
init(autoreset=True)  # automatically resets after each print, optional

TODOIST_DESC_MAX = 16_383  # hard cap from Todoist API/docs
# Local DB directory (subfolder to keep scripts dir clean)
DB_DIR = os.path.join(os.getcwd(), 'todoist_db')
# Ensure the DB directory exists
os.makedirs(DB_DIR, exist_ok=True)

# HTML-to-Markdown converter
try:
    from html2text import HTML2Text
    def html2md(html: str) -> str:
        h = HTML2Text()
        h.ignore_images = False
        h.ignore_links = False
        h.body_width = 0
        return h.handle(html)
except ImportError:
    import re
    def html2md(html: str) -> str:
        return re.sub(r'<[^>]+>', '', html)

# YAML support
try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with 'pip install pyyaml'", file=sys.stderr)
    sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent("""
            Fetch emails and sync to Akiflow/Todoist or generate filters/AHK categories from Todoist.

            Adding a New Category to Todoist and Updating Configurations:

            1a. Create a New {Fore.CYAN}Todoist{Style.RESET_ALL} Project:
               - In Todoist, create a new project (e.g., "ParentProject:ChildProject") under an existing parent project or as a top-level project.
               - Note the project hierarchy, as the script uses the format "ParentProject\\ChildProject" for project paths.
            1b. Create the same Project in {Fore.CYAN}Akiflow{Style.RESET_ALL}:
               - In AkiFlow, create a Project below the Parent Project, but this project does NOT have the "PP:" as a prefix, that is handled
                 by the Script, so when creating a "PP:Baxter" Todoist Project, that would be "Baxter" in AKiFlow, below the "Property Purchase" parent. 

            2. Update the YAML Filter File:
               - Run the script with the `--update-from-todoist` flag to automatically generate or append filters based on Todoist projects:
                 ----
                 {Fore.CYAN}
                 python o365_upd_akiflow.py --category-file <path_to_yaml> --update-from-todoist [--append]
                 eg. aki --category-file o365_upd_akiflow.yaml --update-from-todoist [--append]
                 eg. aki_uy (this will run the above without --append)
                 {Style.RESET_ALL}
                 ----
               - Use `--append` to add new filters without overwriting existing ones.
               - This will create or update the YAML file at `<path_to_yaml>` with filters derived from Todoist project names, including the new project.
               - Alternatively, manually edit the YAML file to add a new filter entry. Example:
                 {Fore.CYAN}
                 Outlook Filters:
                   - "ParentProject:ChildProject Filter":
                       outlook_filter:
                         category: "ChildProject"
                       todoist_settings:
                         project: "ParentProject\\ChildProject"
                 {Style.RESET_ALL}

            3. Update {Fore.CYAN}AutoHotKey{Style.RESET_ALL} Categories:
               - Run the script with the `--gen-ahk-categories` flag to generate an updated AutoHotKey categories list:
                 {Fore.CYAN}
                 python o365_upd_akiflow.py --gen-ahk-categories
                 eg. aki_gc
                 {Style.RESET_ALL}
               - This will output a list of categories based on Todoist child projects, with an '&' inserted after the first ':' (or at the start if no colon). For example, "ParentProject:ChildProject" becomes "ParentProject:&ChildProject".
               - Copy the output (e.g., `categories := ["ParentProject:&ChildProject", ...]`) into your AutoHotKey script.

            4. Verify the Setup:
               - Test the updated configuration without making API calls or file changes:
                 {Fore.CYAN}
                 python o365_upd_akiflow.py --category-file <path_to_yaml> --mailbox <folder_or_email> --days <num_days> --test
                 eg. aki --category-file o365_upd_akiflow.yaml --mailbox andrew@avcorp.biz --days 90 --test
                 {Style.RESET_ALL}
               - Run the script normally to process emails with the new category:
                 {Fore.CYAN}
                 python o365_upd_akiflow.py --category-file <path_to_yaml> --mailbox <folder_or_email> --days <num_days>
                 eg. aki --category-file o365_upd_akiflow.yaml --mailbox andrew@avcorp.biz --days 90 --test
                 {Style.RESET_ALL}
        """.format(Fore=Fore, Style=Style))
    )
    parser.add_argument(
        '--category-file',
        help='YAML file for filters'
    )
    parser.add_argument(
        '--clear-data-file', action='store_true',
        help='Create blank YAML and exit'
    )
    parser.add_argument(
        '--update-from-todoist', action='store_true',
        help='Populate filters from Todoist projects'
    )
    parser.add_argument(
        '-a', '--append', action='store_true',
        help='Append when updating YAML'
    )
    parser.add_argument(
        '--gen-ahk-categories', action='store_true',
        help='Generate AHK categories list from Todoist child projects'
    )
    parser.add_argument(
        '--mailbox',
        help='Inbox folder name or email address'
    )
    parser.add_argument(
        '--days', type=int,
        help='Days back for email fetch'
    )
    parser.add_argument(
        '-d', '--debug', action='store_true',
        help='Enable debug logs'
    )
    parser.add_argument(
        '-t', '--test', action='store_true',
        help='Test mode; no API calls or file writes'
    )
    args = parser.parse_args()

    # If generating AHK categories only, no other args required
    if args.gen_ahk_categories:
        return args

    # Otherwise, category-file is required
    if not args.category_file:
        parser.error('the following argument is required: --category-file')

    # clear-data-file or update-from-todoist need only category-file
    if args.clear_data_file or args.update_from_todoist:
        return args

    # Otherwise require mailbox + days
    if not args.mailbox or args.days is None:
        parser.error(
            'Specify --mailbox and --days for email fetch, or use '
            '--clear-data-file/--update-from-todoist/--gen-ahk-categories'
        )
        return args
    # otherwise require mailbox + days
    if not args.mailbox or args.days is None:
        parser.error(
            "Specify --mailbox and --days for email fetch, or use "
            "--clear-data-file/--update-from-todoist/--gen-ahk-categories"
        )
    return args



def default_config() -> Dict:
    return {'Outlook Filters': [{
        'Example Filter': {
            'outlook_filter': {'category': '/CategoryName/', 'subject': '/SubjectRegex/'},
            'akiflow_settings': {'project': 'ExampleProject', 'status': 'New'},
            'todoist_settings': {'project': 'ExampleProjectName', 'project_id': ''}
        }
    }]}


def write_yaml(path: str, data: Dict, append: bool = False, test: bool = False):
    text = yaml.safe_dump(data, sort_keys=False)
    if test:
        print(f"[TEST] YAML to {'append' if append else 'write'} at {path}:\n{text}")
        return
    mode = 'a' if append else 'w'
    with open(path, mode, encoding='utf-8') as f:
        # if appending, ensure no header on subsequent writes
        if append:
            f.write(text)
        else:
            f.write(text)
    print(f"{'Appended to' if append else 'Wrote'} YAML at {path}")


def generate_filters_from_todoist(path: str, append: bool = False, test: bool = False):
    # Fetch all projects
    session = get_todoist_session()
    resp = session.get('https://api.todoist.com/rest/v2/projects')
    resp.raise_for_status()
    projects = resp.json()
    # build parent lookup
    by_id = {p['id']: p for p in projects}
    filters = []
    for p in projects:
        parent_id = p.get('parent_id')
        if not parent_id:
            continue
        parent = by_id.get(parent_id)
        if not parent:
            continue
        parent_name = parent['name']
        child_name = p['name']
        key = f"{parent_name}:{child_name} Filter"
        category = f"{child_name}"
        project_path = f"{parent_name}\\{child_name}"
        filters.append({key: {
            'outlook_filter': {'category': category},
            # 'subject': '/SubjectRegex/'
            'todoist_settings': {'project': project_path}
        }})
    data = {'Outlook Filters': filters}
    write_yaml(path, data, append=append, test=test)

def generate_ahk_categories(test: bool = False):
    """
    Generate an AutoHotKey categories list from Todoist child projects,
    inserting '&' after the first ':' in each name (or at the front if no colon).
    """
    session = get_todoist_session()
    resp = session.get('https://api.todoist.com/rest/v2/projects')
    resp.raise_for_status()
    projects = resp.json()
    # Build a lookup so we know who's a child
    by_id = {p['id']: p for p in projects}

    categories = []
    for p in projects:
        parent_id = p.get('parent_id')
        if not parent_id:
            continue  # skip top-level
        child_name = p['name']
        # Insert '&' after the first colon, or at the start if no colon
        if ':' in child_name:
            idx = child_name.find(':')
            cat = child_name[:idx+1] + '&' + child_name[idx+1:]
        else:
            cat = '&' + child_name
        categories.append(cat)

    # Format for AHK:
    line = 'categories := [' + ', '.join(f'"{c}"' for c in categories) + ']'
    print(line)

def create_data_file(path, test=False):
    data = default_config()
    y = yaml.safe_dump(data, sort_keys=False)
    if test:
        print("[TEST] YAML:\n"+y)
    else:
        with open(path,'w',encoding='utf-8') as f: f.write(y)
        print(f"Created {path}")


def load_config(path):
    with open(path,'r',encoding='utf-8') as f:
        return yaml.safe_load(f)


def fetch_messages(token, mailbox, start_dt, end_dt, debug=False):
    headers = {'Authorization': f'Bearer {token}'}
    if '@' in mailbox:
        url = f"https://graph.microsoft.com/v1.0/users/{mailbox}/mailFolders('inbox')/messages"
    else:
        url = f"https://graph.microsoft.com/v1.0/me/mailFolders('{mailbox}')/messages"

    params = {
        '$select': 'subject,receivedDateTime,webLink,body,from,categories,id',
        '$filter': f"receivedDateTime ge {start_dt.isoformat()} and receivedDateTime le {end_dt.isoformat()}",
        '$orderby': 'receivedDateTime desc',
        '$top': '100'
    }

    all_messages: List[Dict] = []
    while True:
        if debug:
            print(f"{Fore.GREEN}[DEBUG] GET {url} params={params}", file=sys.stderr)
        resp = requests.get(url, headers=headers, params=params)
        resp.raise_for_status()
        data = resp.json()

        page = data.get('value', [])
        all_messages.extend(page)
        if debug:
            print(f"{Fore.GREEN}[DEBUG] Retrieved {len(page)} messages; total so far {len(all_messages)}", file=sys.stderr)

        # follow the nextLink if there’s more data
        next_link = data.get('@odata.nextLink')
        if not next_link:
            break
        url = next_link
        params = None

    if debug:
        print(f"{Fore.GREEN}[DEBUG] Total messages fetched: {len(all_messages)}", file=sys.stderr)
    return all_messages




def match_filters(msg, filters, debug=False):
    import re
    cats,subj=msg.get('categories',[]),msg.get('subject','')
    res=[]
    for entry in filters:
        for name,det in entry.items():
            o=det.get('outlook_filter',{}); cat=o.get('category'); sub=o.get('subject')
            ok=True
            if cat:
                if cat.startswith('/') and cat.endswith('/'):
                    if not any(re.search(cat.strip('/'),c) for c in cats): ok=False
                else:
                    if not any(c.lower()==cat.lower() for c in cats): ok=False
            if ok and sub:
                if sub.startswith('/') and sub.endswith('/'):
                    if not re.search(sub.strip('/'),subj): ok=False
                else:
                    if sub.lower() not in subj.lower(): ok=False
            if ok:
                if debug: print(f"{Fore.GREEN}[DEBUG] match '{name}' subj='{subj}'",file=sys.stderr)
                res.append((name,det,msg))
    return res


# ----------------------------------------------------------------------
# Local MessageID DB helpers
# ----------------------------------------------------------------------
def db_filename(project_id: int) -> str:
    return os.path.join(DB_DIR, f"todoist_project_{project_id}.db")

def load_db(db_file: str) -> Set[str]:
    try:
        with open(db_file, 'r', encoding='utf-8') as f:
            return {line.strip() for line in f if line.strip()}
    except FileNotFoundError:
        return set()


def append_db(db_file: str, mids: Set[str]) -> None:
    os.makedirs(os.path.dirname(db_file) or '.', exist_ok=True)
    with open(db_file, 'a', encoding='utf-8') as f:
        for mid in sorted(mids):
            f.write(mid + "\n")



### AKIFLOW ###
def process_akiflow(name,msgs,ak_cfg,test=False, debug=False):
    if test and ak_cfg: print(f"[TEST] Akiflow '{name}' {len(msgs)} msgs")





### TODOIST ###
def _build_todoist_description(body_md: str,
                               frm: str,
                               formatted_date: str,
                               link_md: str,
                               message_id: str) -> str:
    """
    Return a description guaranteed to be ≤ TODOIST_DESC_MAX chars
    while keeping the MessageID footer intact.
    """
    header_lines = [
        f"From: {frm}",
        f"Date: {formatted_date}",
        f"WebLink: {link_md}",
        "",  # blank line before body
    ]
    footer_lines = [
        "",
        "---",
        f"MessageID: {message_id}"
    ]
    # compute header+footer length (+1 per newline)
    header_footer_len = sum(len(l) + 1 for l in header_lines + footer_lines)
    # remaining room for the body (slack of 5 chars)
    keep = TODOIST_DESC_MAX - header_footer_len - 5
    if keep < 0:
        keep = 0
    trimmed_body = body_md[:keep]
    return "\n".join(header_lines + [trimmed_body] + footer_lines)




def get_todoist_projects()->List[Dict]:
    s=get_todoist_session(); r=s.get("https://api.todoist.com/rest/v2/projects"); r.raise_for_status(); return r.json()

def build_todoist_project_index():
    projs=get_todoist_projects(); idx={}
    for p in projs:
        parts=[p['name']]; pid_p=p.get('parent_id'); seen=set()
        while pid_p and pid_p not in seen:
            seen.add(pid_p)
            par=next((x for x in projs if x['id']==pid_p),None);
            if not par: break
            parts.insert(0,par['name']); pid_p=par.get('parent_id')
        fp="\\".join(parts)
        idx[fp.lower()]=p['id']; idx[p['name'].lower()]=p['id']
    return idx

def find_todoist_project_id(cfg):
    pid=cfg.get('project_id');
    if pid:
        try:return int(pid)
        except: return None
    name=cfg.get('project');return build_todoist_project_index().get(name.lower()) if name else None

# ----------------------------------------------------------------------
# Todoist existing fetch (open + completed)
# ----------------------------------------------------------------------
def get_existing_message_ids(project_id: int) -> Set[str]:
    session = get_todoist_session()
    pattern = re.compile(r"MessageID:\s*(\S+)")
    existing: Set[str] = set()
    # open tasks
    resp = session.get(f"https://api.todoist.com/rest/v2/tasks?project_id={project_id}")
    resp.raise_for_status()
    for task in resp.json():
        desc = task.get('description', '')
        m = pattern.search(desc)
        if m:
            existing.add(m.group(1))
        # completed items via Sync API
    sync_payload = {
        "sync_token": "*",
        "resource_types": '["completed_items"]'
    }
    # Sync API requires form-encoded data (not JSON)
    r = session.post(
        "https://api.todoist.com/sync/v9/sync",
        data=sync_payload,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    r.raise_for_status()
    for item in r.json().get('completed_items', []):
        desc = item.get('description', '')
        m = pattern.search(desc)
        if m:
            existing.add(m.group(1))
    return existing


def add_task(content:str,description:Optional[str]=None,project_id:Optional[int]=None,
             due_string:Optional[str]=None,priority:Optional[int]=None,
             labels:Optional[List[int]]=None)->Dict:
    s=get_todoist_session(); payload={'content':content}
    if description: payload['description']=description
    if project_id: payload['project_id']=project_id
    if due_string: payload['due_string']=due_string
    if priority: payload['priority']=priority
    if labels: payload['labels']=labels
    r=s.post("https://api.todoist.com/rest/v2/tasks",json=payload); r.raise_for_status(); return r.json()


# ----------------------------------------------------------------------
# Updated process_todoist using local DB + bootstrap
# ----------------------------------------------------------------------
def process_todoist(name: str,
                    msgs: List[Dict],
                    cfg: Dict,
                    test: bool = False,
                    debug: bool = False):
    pid = find_todoist_project_id(cfg)
    if not pid:
        print(f"[WARN] no project_id for '{name}'", file=sys.stderr)
        return
    db_file = db_filename(pid)
    existing = load_db(db_file)
    if not existing:
        # first run: bootstrap from API
        if debug:
            print(f"[DEBUG] Bootstrapping DB for project {pid}", file=sys.stderr)
        boot = get_existing_message_ids(pid)
        append_db(db_file, boot)
        existing.update(boot)
    if test:
        print(f"[TEST] would create tasks in project {pid} (candidates: {len(msgs)})")
        
    for msg in msgs:
        mid  = msg.get('id', '')
        subj = msg.get('subject', '')
        frm  = msg.get('from', {}).get('emailAddress', {}).get('name', '')

        if debug:
            print(f"{Fore.GREEN} - {msg.get('receivedDateTime')} | {subj}", file=sys.stderr)

        # Skip if we've already seen this MessageID (open or completed)
        if mid in existing:
            if debug:
                print(f"{Fore.YELLOW}  - Skipping existing task Subject={subj}, From={frm},{Style.RESET_ALL}\n  - MessageID={mid}", file=sys.stderr)
            continue

        # Build formatted local time string
        recv = msg.get('receivedDateTime', '')
        try:
            if recv.endswith('Z'):
                recv = recv[:-1] + '+00:00'
            dt = datetime.fromisoformat(recv).astimezone(ZoneInfo('America/Chicago'))
            date_part = dt.strftime('%Y-%m-%d')
            time_ampm = dt.strftime('%I:%M%p').lower()
            tz = dt.strftime('%Z') or 'Central'
            wd = dt.strftime('%A')
            formatted = f"{date_part} {time_ampm} {tz}, {wd}"
        except Exception as e:
            print(f"[DEBUG] Date parse failed for '{recv}': {e}", file=sys.stderr)
            formatted = recv

        # Link + body
        link = msg.get('webLink', '')
        link_md = f"[{subj}]({link})" if link else subj
        html = msg.get('body', {}).get('content', '') or ''
        body = html2md(html)
        
        desc = _build_todoist_description(body, frm, formatted, link_md, mid)
        if test:
            print(f"[TEST] add_task: {subj}")
        else:
            add_task(subj, desc, pid, cfg.get('due_string'), cfg.get('priority'), cfg.get('labels'))
            append_db(db_file, {mid})
            existing.add(mid)


def main():
    args = parse_args()
    debug = args.debug
    test  = args.test

    # 1) Clear-data-file: write default YAML and exit
    if args.clear_data_file:
        write_yaml(args.category_file,
                   default_config(),
                   append=False,
                   test=test)
        sys.exit(0)

    # 2) Update-from-todoist: generate filters from your projects
    if args.update_from_todoist:
        generate_filters_from_todoist(
            args.category_file,
            append=args.append,
            test=test
        )
        sys.exit(0)

    # 2A) Output AHK Categories for use in AHK Macro
    if args.gen_ahk_categories:
        generate_ahk_categories(test=args.test)
        sys.exit(0)
    
    # 3) Otherwise: load filters and run the sync
    cfg      = load_config(args.category_file)
    filters  = cfg.get('Outlook Filters', [])
    now      = datetime.now(timezone.utc)
    start    = now - timedelta(days=args.days)
    end      = now
    token    = get_app_access_token()
    msgs     = fetch_messages(token, args.mailbox, start, end, debug=debug)

    total = 0
    for entry in filters:
        for name, det in entry.items():
            ak_cfg = det.get('akiflow_settings', {})
            td_cfg = det.get('todoist_settings', {})
            matched = []
            for m in msgs:
                for _, __, msg in match_filters(m, [entry], debug=debug):
                    matched.append(msg)

            if debug:
                print(f"Processing {name}...", file=sys.stderr)
                #for m in matched:
                #    print(f" - {m.get('receivedDateTime')} | {m.get('subject')}", file=sys.stderr)

            total += len(matched)
            process_akiflow(name, matched, ak_cfg, test=test, debug=debug)
            process_todoist(name, matched, td_cfg, test=test, debug=debug)

    print(f"Found {total} matching messages.")
    if test:
        print("Test mode: no actions performed.")

if __name__=='__main__': main()
