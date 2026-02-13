#!/usr/bin/env python3
import argparse
import os
from dotenv import load_dotenv
from typing import List, Dict, Optional
import requests


def get_todoist_api_token() -> str:
    """
    Load Todoist API token from secrets/.env file.
    """
    env_path = os.path.join(os.path.dirname(__file__), "secrets", ".env")
    load_dotenv(env_path)
    token = os.getenv("TODOIST_API_TOKEN")
    if not token:
        raise ValueError("TODOIST_API_TOKEN not set in secrets/.env")
    return token


def get_todoist_session() -> requests.Session:
    """
    Returns a requests.Session with Authorization and Content-Type headers set.
    """
    token = get_todoist_api_token()
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    })
    return session


def add_task(
    content: str,
    project_id: Optional[int] = None,
    due_string: Optional[str] = None,
    priority: Optional[int] = None,
    labels: Optional[List[int]] = None
) -> Dict:
    """
    Create a new task in Todoist via REST API v2.
    Returns the JSON response for the created task.
    """
    session = get_todoist_session()
    payload: Dict = {"content": content}

    if project_id is not None:
        payload["project_id"] = project_id
    if due_string is not None:
        payload["due_string"] = due_string
    if priority is not None:
        payload["priority"] = priority
    if labels is not None:
        payload["labels"] = labels

    resp = session.post(
        "https://api.todoist.com/rest/v2/tasks",
        json=payload
    )
    resp.raise_for_status()
    return resp.json()


def get_projects() -> List[Dict]:
    """
    Retrieve all Todoist projects.
    """
    session = get_todoist_session()
    resp = session.get("https://api.todoist.com/rest/v2/projects")
    resp.raise_for_status()
    return resp.json()


def search_tasks(query: str, test: bool = False) -> None:
    """
    Search for tasks containing 'query' in their content and list them.
    """
    session = get_todoist_session()
    resp = session.get("https://api.todoist.com/rest/v2/tasks")
    resp.raise_for_status()
    tasks = resp.json()
    matched = [t for t in tasks if query.lower() in t.get("content", "").lower()]
    if not matched:
        print(f"No tasks found containing '{query}'.")
        return

    # Print header
    print(f"{'Task ID':<12} | {'Content':<50} | {'Due Date':<12}")
    for t in matched:
        tid = t.get("id", "")
        content = t.get("content", "")
        due = ""
        if t.get("due") and isinstance(t.get("due"), dict) and t["due"].get("date"):
            due = t["due"]["date"]
        if test:
            print(f"[TEST] Would list: {tid:<12} | {content:<50} | {due:<12}")
        else:
            print(f"{tid:<12} | {content:<50} | {due:<12}")


def delete_tasks(query: str, test: bool = False) -> None:
    """
    Delete tasks containing 'query' in their content.
    """
    session = get_todoist_session()
    resp = session.get("https://api.todoist.com/rest/v2/tasks")
    resp.raise_for_status()
    tasks = resp.json()
    matched = [t for t in tasks if query.lower() in t.get("content", "").lower()]
    if not matched:
        print(f"No tasks found containing '{query}'.")
        return

    for t in matched:
        tid = t.get("id", "")
        content = t.get("content", "")
        due = (t.get("due") or {}).get("date", "")
        if test:
            print(f"[TEST] Would delete: {tid} | {content} | {due}")
        else:
            del_resp = session.delete(f"https://api.todoist.com/rest/v2/tasks/{tid}")
            if del_resp.status_code == 204:
                print(f"Deleted: {tid} | {content} | {due}")
            else:
                print(f"[ERROR] Failed to delete {tid}: HTTP {del_resp.status_code}")


def main():
    parser = argparse.ArgumentParser(
        description="Manage Todoist tasks: list projects, create test task, search or delete tasks."
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--list-projects", action="store_true",
        help="List all existing Todoist projects"
    )
    group.add_argument(
        "--create-test-task", action="store_true",
        help="Create a sample test task in Todoist"
    )
    group.add_argument(
        "--search-tasks", metavar="QUERY", type=str,
        help="Search and list tasks containing QUERY"
    )
    group.add_argument(
        "--delete-tasks", metavar="QUERY", type=str,
        help="Delete tasks containing QUERY"
    )
    parser.add_argument(
        "--test", action="store_true",
        help="Test mode: show what would be done without making changes"
    )
    args = parser.parse_args()

    test = args.test

    if args.list_projects:
        projects = get_projects()
        # Build lookup for parent names
        name_map = {proj["id"]: proj["name"] for proj in projects}
        # Print header with fixed column widths
        print(f"{'Project ID':<12} | {'Name':<25} | {'Parent ID':<12} | {'Parent Name':<25}")
        for proj in projects:
            proj_id = str(proj.get("id") or "")
            name = proj.get("name") or ""
            parent_id = str(proj.get("parent_id") or "")
            parent_name = name_map.get(proj.get("parent_id"), "")
            print(f"{proj_id:<12} | {name:<25} | {parent_id:<12} | {parent_name:<25}")

    elif args.create_test_task:
        task = add_task(
            content="Follow up on your email",
            due_string="tomorrow at 9am",
            priority=4
        )
        print(f"Created task ID={task['id']} • {task['content']}")

    elif args.search_tasks:
        search_tasks(args.search_tasks, test)

    elif args.delete_tasks:
        delete_tasks(args.delete_tasks, test)


if __name__ == "__main__":
    main()
