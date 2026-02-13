#!/usr/bin/env python3

import os
import argparse
from datetime import datetime, timedelta
from dotenv import load_dotenv
import requests

# Global debug flag, set in main()
DEBUG = False

def load_env():
    env_path = os.path.join(os.path.dirname(__file__), "secrets", ".env")
    load_dotenv(env_path)
    user = os.getenv("BITRIX_WH_USERID")
    key = os.getenv("BITRIX_WH_KEY")
    if not user or not key:
        raise RuntimeError("Missing BITRIX_WH_USERID or BITRIX_WH_KEY in .env")
    return user, key


def build_base_url(user, key):
    return f"https://avcorp.bitrix24.com/rest/{user}/{key}"


def get_workgroup_id(base, name=None, group_id=None):
    if group_id:
        return group_id
    url = f"{base}/sonet_group.get.json"
    params = {'filter[NAME]': name, 'select[]': 'ID'}
    if DEBUG:
        print(f"[DEBUG] get_workgroup_id URL: {url}")
        print(f"[DEBUG] get_workgroup_id params: {params}\n")
    r = requests.get(url, params=params)
    r.raise_for_status()
    data = r.json().get('result', [])
    if not data:
        raise ValueError(f"Workgroup '{name}' not found")
    return int(data[0]['ID'])


def list_tasks(base, group_id=None):
    url = f"{base}/tasks.task.list.json"
    params = {
        'order[ID]': 'DESC',
        'select[]': ['ID','TITLE','CHANGED_DATE','COMMENTS_COUNT']
    }
    if group_id:
        params['filter[GROUP_ID]'] = group_id
    if DEBUG:
        print(f"[DEBUG] list_tasks URL: {url}")
        print(f"[DEBUG] list_tasks params: {params}\n")
    r = requests.get(url, params=params)
    r.raise_for_status()
    data = r.json().get('result')
    # Handle both list and dict formats
    if isinstance(data, dict) and 'tasks' in data:
        tasks = data['tasks']
    elif isinstance(data, list):
        tasks = data
    else:
        tasks = []
    return tasks


def parse_datetime(dt_str):
    if not dt_str:
        return None
    # Strip trailing timezone ±HH:MM
    if len(dt_str) > 6 and dt_str[-3] == ':' and (dt_str[-6] in ('+','-')):
        dt_str = dt_str[:-6]
    try:
        return datetime.fromisoformat(dt_str)
    except ValueError:
        if DEBUG:
            print(f"[DEBUG] parse_datetime failed for '{dt_str}'")
        return None


def count_comments(task):
    return int(task.get('commentsCount') or task.get('COMMENTS_COUNT') or 0)


def get_changed_date(task):
    return task.get('changedDate') or task.get('CHANGED_DATE')


def has_recent(task, since):
    dt = parse_datetime(get_changed_date(task))
    return dt and dt >= since


def main():
    global DEBUG
    parser = argparse.ArgumentParser(description="List Bitrix24 tasks by workgroup")
    parser.add_argument("--workgroup-name", help="Name of the workgroup")
    parser.add_argument("--workgroup-id", type=int, help="ID of the workgroup")
    parser.add_argument("--days", type=int, required=True, help="Look back this many days")
    parser.add_argument("-d","--debug", action="store_true", help="Show debug output for all API calls and task data")
    args = parser.parse_args()
    DEBUG = args.debug

    user, key = load_env()
    base = build_base_url(user, key)
    if DEBUG:
        print(f"[DEBUG] Base URL: {base}\n")
    wg_id = get_workgroup_id(base, args.workgroup_name, args.workgroup_id)
    since = datetime.utcnow() - timedelta(days=args.days)

    tasks = list_tasks(base, group_id=wg_id)

    if DEBUG:
        print(f"[DEBUG] Total tasks retrieved: {len(tasks)}")
        for t in tasks:
            print(f"[DEBUG] Task raw: {t}")
        print()

    recent = [t for t in tasks if has_recent(t, since)]

    if not recent:
        print(f"No tasks updated in the last {args.days} days.")
    else:
        print(f"Tasks updated in the last {args.days} days:")
        for t in recent:
            title = t.get('title') or t.get('TITLE')
            dt_str = get_changed_date(t)
            num = count_comments(t)
            print(f"{t.get('ID')}: {title} | {dt_str} | {num} comments")

if __name__ == '__main__':
    main()
