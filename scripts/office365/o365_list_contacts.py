import argparse
import requests
from tabulate import tabulate
import csv
import sys
from datetime import datetime
from o365_auth import get_access_token

# Last Updated: 9/17/2025 11:06:00 AM CDT
# Description: Logging function with colored output for debug, info, warn, error
def log_message(message, level="INFO", debug=False):
    colors = {
        "DEBUG": "\033[37m",  # White
        "INFO": "\033[36m",   # Cyan
        "WARN": "\033[33m",   # Yellow
        "ERROR": "\033[31m"   # Red
    }
    reset = "\033[0m"
    if debug or level != "DEBUG":
        print(f"{colors.get(level, '')}[{level}] {message}{reset}")

# Last Updated: 9/17/2025 11:06:00 AM CDT
# Description: Fetch users (/users) or GAL contacts (/contacts) from Graph API and filter client-side
def fetch_graph_data(endpoint, company, token, entity_type, test=False, debug=False):
    if company is None or not company:
        log_message(f"Invalid company name for {entity_type}: {company}", "ERROR", debug)
        return []
    
    if debug:
        log_message(f"Filtering {entity_type} for company: '{company}' (type: {type(company)})", "DEBUG", debug)
    
    headers = {"Authorization": f"Bearer {token}"}
    select_fields = "id,displayName,mail,companyName,businessPhones,mobilePhone,userType" if entity_type == "users" else "id,displayName,mail,companyName,businessPhones,mobilePhone"
    url = f"https://graph.microsoft.com/v1.0/{endpoint}?$select={select_fields}&$top=999"
    
    if test:
        log_message(f"TEST: Would fetch {entity_type} from {url}", "DEBUG", debug)
        # Allow data retrieval for logging in test mode
        if debug:
            log_message("TEST: Simulating fetch but allowing data retrieval for debugging", "DEBUG", debug)
    
    all_data = []
    unique_company_names = set()
    non_none_companies = set()
    unique_user_types = set()
    while url:
        try:
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            data = response.json().get("value", [])
            # Filter client-side for companyName
            if entity_type == "users":
                filtered_data = [item for item in data if isinstance(item, dict) and str(item.get("companyName") or "").lower() == str(company).lower() and item.get("userType") != "Guest"]
            else:  # contacts
                filtered_data = [item for item in data if isinstance(item, dict) and str(item.get("companyName") or "").lower() == str(company).lower()]
            all_data.extend(filtered_data)
            # Collect debugging info
            if debug:
                unique_company_names.update(str(item.get("companyName") or "None") for item in data)
                non_none_companies.update(str(item.get("companyName")) for item in data if item.get("companyName") is not None)
                if entity_type == "users":
                    unique_user_types.update(str(item.get("userType") or "None") for item in data)
            log_message(f"Fetched {len(data)} {entity_type}, filtered to {len(filtered_data)} for company '{company}'", "INFO", debug)
            if debug:
                log_message(f"Response (first 2): {data[:2]}...", "DEBUG", debug)
                if entity_type == "users":
                    log_message(f"User types found: {', '.join(sorted(unique_user_types))}", "DEBUG", debug)
            # Handle pagination
            url = response.json().get("@odata.nextLink")
        except requests.exceptions.RequestException as e:
            log_message(f"Error fetching {entity_type}: {str(e)}", "ERROR", debug)
            if debug and hasattr(e, 'response') and e.response is not None:
                log_message(f"Error details: {e.response.text}", "DEBUG", debug)
            return []
    # Log debugging info and GAL warning
    if not all_data and debug:
        if unique_company_names:
            log_message(f"Available company names for {entity_type}: {', '.join(sorted(unique_company_names))}", "DEBUG", debug)
        if non_none_companies:
            log_message(f"Non-None company names for {entity_type}: {', '.join(sorted(non_none_companies))}", "DEBUG", debug)
        if entity_type == "contacts":
            log_message("Warning: /contacts may not include GAL mail-enabled contacts. Verify in Exchange Admin Center > Recipients > Contacts.", "WARN", debug)
    return all_data

# Last Updated: 9/17/2025 11:06:00 AM CDT
# Description: Normalize user/contact data to standard fields
def normalize_data(items, entity_type, debug=False):
    normalized = []
    for item in items:
        entry = {
            "Id": item.get("id", ""),
            "Name": item.get("displayName", ""),
            "Email": item.get("mail", ""),
            "Company": item.get("companyName", ""),
            "Phone": item.get("businessPhones", [None])[0] or item.get("mobilePhone", "") or ""
        }
        normalized.append(entry)
        if debug:
            log_message(f"Normalized {entity_type} entry: {entry}", "DEBUG", debug)
    return normalized

# Last Updated: 9/17/2025 11:06:00 AM CDT
# Description: Resolve group ID from display name
def resolve_group_id(display_name, token, debug=False):
    headers = {"Authorization": f"Bearer {token}"}
    url = f"https://graph.microsoft.com/v1.0/groups?$filter=displayName eq '{display_name}'&$select=id,displayName"
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        groups = response.json().get("value", [])
        if not groups:
            log_message(f"No group found with display name '{display_name}'", "ERROR", debug)
            return None
        if len(groups) > 1:
            log_message(f"Multiple groups found with display name '{display_name}'. Using first: {groups[0]['id']}", "WARN", debug)
        group_id = groups[0]["id"]
        if debug:
            log_message(f"Resolved group '{display_name}' to ID: {group_id}", "DEBUG", debug)
        return group_id
    except requests.exceptions.RequestException as e:
        log_message(f"Error resolving group '{display_name}': {str(e)}", "ERROR", debug)
        if debug and hasattr(e, 'response') and e.response is not None:
            log_message(f"Error details: {e.response.text}", "DEBUG", debug)
        return None

# Last Updated: 9/17/2025 11:06:00 AM CDT
# Description: Manage distribution lists (list members, add member, create DL, update members)
def manage_distribution_list(group_id, action, token, company=None, user_id=None, display_name=None, mail_nickname=None, test=False, debug=False, format_type="ascii"):
    if not group_id and action != "create-dl":
        log_message("Group ID required for DL management (except create-dl)", "ERROR", debug)
        return []
    
    if test:
        log_message(f"TEST: Would perform {action} on DL {group_id or display_name}", "DEBUG", debug)
    
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    
    if action == "list-members":
        url = f"https://graph.microsoft.com/v1.0/groups/{group_id}/members?$select=id,displayName,mail,companyName,userType"
        try:
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            data = response.json().get("value", [])
            log_message(f"Fetched {len(data)} members from DL {group_id}", "INFO", debug)
            if debug:
                log_message(f"Members (first 2): {data[:2]}...", "DEBUG", debug)
            return data
        except requests.exceptions.RequestException as e:
            log_message(f"Error listing members: {str(e)}", "ERROR", debug)
            if debug and hasattr(e, 'response') and e.response is not None:
                log_message(f"Error details: {e.response.text}", "DEBUG", debug)
            return []
    
    elif action == "add-member":
        if not user_id:
            log_message("User ID required for add-member", "ERROR", debug)
            return None
        url = f"https://graph.microsoft.com/v1.0/groups/{group_id}/members/$ref"
        body = {"@odata.id": f"https://graph.microsoft.com/v1.0/users/{user_id}"}
        if test:
            log_message(f"TEST: Would add user {user_id} to DL {group_id}", "DEBUG", debug)
            return None
        try:
            response = requests.post(url, headers=headers, json=body)
            response.raise_for_status()
            log_message(f"Added user {user_id} to DL {group_id}", "INFO", debug)
            return response.json()
        except requests.exceptions.RequestException as e:
            log_message(f"Error adding member: {str(e)}", "ERROR", debug)
            if debug and hasattr(e, 'response') and e.response is not None:
                log_message(f"Error details: {e.response.text}", "DEBUG", debug)
            return None
    
    elif action == "create-dl":
        if not display_name or not mail_nickname:
            log_message("Display name and mail nickname required for create-dl", "ERROR", debug)
            return None
        url = "https://graph.microsoft.com/v1.0/groups"
        body = {
            "displayName": display_name,
            "mailNickname": mail_nickname,
            "mailEnabled": True,
            "securityEnabled": False,
            "groupTypes": []  # Standard distribution list
        }
        if test:
            log_message(f"TEST: Would create DL with displayName: {display_name}, mailNickname: {mail_nickname}", "DEBUG", debug)
            return {"id": "dummy-id"}
        try:
            response = requests.post(url, headers=headers, json=body)
            response.raise_for_status()
            created_group = response.json()
            log_message(f"Created DL {created_group['displayName']} (ID: {created_group['id']})", "INFO", debug)
            return created_group
        except requests.exceptions.RequestException as e:
            log_message(f"Error creating DL: {str(e)}", "ERROR", debug)
            if debug and hasattr(e, 'response') and e.response is not None:
                log_message(f"Error details: {e.response.text}", "DEBUG", debug)
            return None
    
    elif action == "update-members":
        if not company:
            log_message("Company name required for update-members", "ERROR", debug)
            return None
        # Fetch contacts for company
        contacts = fetch_graph_data("contacts", company, token, "contacts", False, debug)
        normalized_contacts = normalize_data(contacts, "contacts", debug)
        if not normalized_contacts:
            log_message(f"No contacts found for company '{company}'; DL {group_id} unchanged", "INFO", debug)
            return None
        
        # Fetch current members
        current_members = manage_distribution_list(group_id, "list-members", token, debug=debug)
        current_member_ids = {member.get("id", "") for member in current_members}
        
        # New members (contacts)
        new_member_ids = {contact["Id"] for contact in normalized_contacts if contact["Id"]}
        
        # Build operations table
        operations = []
        # Include all current members
        for member_id in current_member_ids:
            member = next((m for m in current_members if m.get("id") == member_id), {})
            if member.get("userType") == "Member":
                operations.append({
                    "Name": member.get("displayName", ""),
                    "Email": member.get("mail", ""),
                    "Company": member.get("companyName", ""),
                    "User Type": member.get("userType", ""),
                    "Operation": "User: No Change",
                    "FirstName": member.get("displayName", "").split()[0] if member.get("displayName", "").split() else member.get("displayName", "")
                })
            elif member_id not in new_member_ids:
                operations.append({
                    "Name": member.get("displayName", ""),
                    "Email": member.get("mail", ""),
                    "Company": member.get("companyName", ""),
                    "User Type": member.get("userType", ""),
                    "Operation": "Delete",
                    "FirstName": member.get("displayName", "").split()[0] if member.get("displayName", "").split() else member.get("displayName", "")
                })
        # Include all contacts (Add or No Change)
        for contact in normalized_contacts:
            first_name = contact.get("Name", "").split()[0] if contact.get("Name", "").split() else contact.get("Name", "")
            operation = "No Change" if contact["Id"] in current_member_ids else "Add"
            operations.append({
                "Name": contact.get("Name", ""),
                "Email": contact.get("Email", ""),
                "Company": contact.get("Company", ""),
                "User Type": "",
                "Operation": operation,
                "FirstName": first_name
            })
        
        # Sort operations by FirstName
        operations = sorted(operations, key=lambda x: x["FirstName"].lower())
        
        # Output operations
        if operations:
            if format_type == "csv":
                if test:
                    log_message("TEST: Would write planned operations to planned_operations.csv", "DEBUG", debug)
                else:
                    with open("planned_operations.csv", "w", newline="", encoding="utf-8") as f:
                        writer = csv.DictWriter(f, fieldnames=["Name", "Email", "Company", "User Type", "Operation"])
                        writer.writeheader()
                        writer.writerows([{k: v for k, v in op.items() if k != "FirstName"} for op in operations])
                    log_message("Wrote planned operations to planned_operations.csv", "INFO", debug)
            else:  # ascii or html
                table = [[op["Name"], op["Email"], op["Company"], op["User Type"], op["Operation"]] for op in operations]
                output = tabulate(table, headers=["Name", "Email", "Company", "User Type", "Operation"], tablefmt="grid")
                if format_type == "html" and not test:
                    html = ["<table border='1'><tr>"]
                    html.extend(f"<th>{header}</th>" for header in ["Name", "Email", "Company", "User Type", "Operation"])
                    html.append("</tr>")
                    for op in operations:
                        html.append("<tr>")
                        html.extend(f"<td>{op[header]}</td>" for header in ["Name", "Email", "Company", "User Type", "Operation"])
                        html.append("</tr>")
                    html.append("</table>")
                    html_output = "".join(html)
                    with open("planned_operations.html", "w", encoding="utf-8") as f:
                        f.write(html_output)
                    log_message("Wrote planned operations to planned_operations.html", "INFO", debug)
                else:
                    log_message(f"Planned operations:\n{output}", "DEBUG", debug)
        
        if test:
            return None
        
        log_message("Actual updates not performed; use planned_operations.csv for manual addition via Exchange Admin Center or PowerShell", "INFO", debug)
        return None
    
    else:
        log_message(f"Unknown action: {action}", "ERROR", debug)
        return []

# Last Updated: 9/17/2025 11:06:00 AM CDT
# Description: Output DL members in specified format (CSV, ASCII, HTML)
def output_dl_members(data, format_type, test=False, debug=False):
    if not data:
        log_message("No members to output.", "INFO", debug)
        return
    
    headers = ["Name", "Email", "Company", "User Type"]
    if format_type == "csv":
        if test:
            log_message("TEST: Would write CSV output", "DEBUG", debug)
            return
        with open("dl_members.csv", "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=headers)
            writer.writeheader()
            writer.writerows([{"Name": item.get("displayName", ""), "Email": item.get("mail", ""), "Company": item.get("companyName", ""), "User Type": item.get("userType", "")} for item in data])
        log_message("Wrote DL members to dl_members.csv", "INFO", debug)
    
    elif format_type == "ascii":
        table = [[item.get("displayName", ""), item.get("mail", ""), item.get("companyName", ""), item.get("userType", "")] for item in data]
        output = tabulate(table, headers=headers, tablefmt="grid")
        if test:
            log_message(f"TEST: Would print ASCII table:\n{output}", "DEBUG", debug)
        else:
            print(output)
    
    elif format_type == "html":
        html = ["<table border='1'><tr>"]
        html.extend(f"<th>{header}</th>" for header in headers)
        html.append("</tr>")
        for item in data:
            html.append("<tr>")
            html.extend(f"<td>{item.get(header.lower().replace(' ', ''), '')}</td>" for header in headers)
            html.append("</tr>")
        html.append("</table>")
        html_output = "".join(html)
        if test:
            log_message(f"TEST: Would write HTML:\n{output}", "DEBUG", debug)
        else:
            with open("dl_members.html", "w", encoding="utf-8") as f:
                f.write(html_output)
            log_message("Wrote DL members to dl_members.html", "INFO", debug)

# Last Updated: 9/17/2025 11:06:00 AM CDT
# Description: Output data in specified format (CSV, ASCII, HTML)
def output_data(data, format_type, test=False, debug=False):
    if not data:
        log_message("No data to output.", "INFO", debug)
        return
    
    headers = ["Name", "Email", "Company", "Phone"]
    if format_type == "csv":
        if test:
            log_message("TEST: Would write CSV output", "DEBUG", debug)
            return
        with open("contacts_output.csv", "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=headers)
            writer.writeheader()
            writer.writerows(data)
        log_message("Wrote output to contacts_output.csv", "INFO", debug)
    
    elif format_type == "ascii":
        table = [[item[header] for header in headers] for item in data]
        output = tabulate(table, headers=headers, tablefmt="grid")
        if test:
            log_message(f"TEST: Would print ASCII table:\n{output}", "DEBUG", debug)
        else:
            print(output)
    
    elif format_type == "html":
        html = ["<table border='1'><tr>"]
        html.extend(f"<th>{header}</th>" for header in headers)
        html.append("</tr>")
        for item in data:
            html.append("<tr>")
            html.extend(f"<td>{item[header]}</td>" for header in headers)
            html.append("</tr>")
        html.append("</table>")
        html_output = "".join(html)
        if test:
            log_message(f"TEST: Would write HTML:\n{output}", "DEBUG", debug)
        else:
            with open("contacts_output.html", "w", encoding="utf-8") as f:
                f.write(html_output)
            log_message("Wrote output to contacts_output.html", "INFO", debug)

# Last Updated: 9/17/2025 11:06:00 AM CDT
# Description: Main function to filter and output users/contacts or manage DLs
def list_contacts(company, format_type="ascii", users_only=False, contacts_only=False, test=False, debug=False, dl_name=None, dl_action=None, dl_user_id=None, dl_display_name=None, dl_mail_nickname=None):
    if company is None and dl_name is None and dl_action not in ["create-dl"]:
        log_message("Company name or DL name required unless creating a DL.", "ERROR", debug)
        return
    
    if debug:
        log_message(f"Processing company: {company}, DL action: {dl_action}, DL name: {dl_name}", "DEBUG", debug)
    
    token = get_access_token()
    if not token:
        log_message("Failed to authenticate with Microsoft Graph.", "ERROR", debug)
        return

    all_data = []
    
    if dl_name or dl_action:
        # DL management mode
        if dl_action == "create-dl":
            result = manage_distribution_list(None, dl_action, token, company, None, dl_display_name, dl_mail_nickname, test, debug, format_type)
            return
        elif dl_action == "update-members":
            if not company:
                log_message("Company name required for update-members.", "ERROR", debug)
                return
            group_id = resolve_group_id(dl_name, token, debug)
            if not group_id:
                if test and dl_display_name and dl_mail_nickname:
                    log_message(f"TEST: Would create DL '{dl_name}' with display name '{dl_display_name}' and mail nickname '{dl_mail_nickname}'", "DEBUG", debug)
                    group_id = "dummy-id"
                elif dl_display_name and dl_mail_nickname:
                    created_group = manage_distribution_list(None, "create-dl", token, None, None, dl_display_name, dl_mail_nickname, test, debug, format_type)
                    if not created_group:
                        return
                    group_id = created_group["id"]
                else:
                    log_message("DL display name and mail nickname required to create DL with update-members.", "ERROR", debug)
                    return
            result = manage_distribution_list(group_id, dl_action, token, company, test=test, debug=debug, format_type=format_type)
            return
        else:
            group_id = resolve_group_id(dl_name, token, debug)
            if not group_id:
                return
            result = manage_distribution_list(group_id, dl_action, token, None, dl_user_id, dl_display_name, dl_mail_nickname, test, debug, format_type)
            if dl_action == "list-members":
                output_dl_members(result, format_type, test, debug)
            return
    
    # Original list mode
    if not contacts_only:
        users = fetch_graph_data("users", company, token, "users", test, debug)
        all_data.extend(normalize_data(users, "users", debug))
    
    if not users_only:
        contacts = fetch_graph_data("contacts", company, token, "contacts", test, debug)
        all_data.extend(normalize_data(contacts, "contacts", debug))
    
    if not all_data:
        log_message(f"No users or contacts found for company '{company}'.", "WARN", debug)
        return
    
    output_data(all_data, format_type, test, debug)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="List Microsoft 365 users and contacts filtered by company, or manage distribution lists.")
    parser.add_argument("-c", "--company", help="Filter by company name (e.g., 'Fields Family').")
    parser.add_argument("-csv", action="store_true", help="Output in CSV format.")
    parser.add_argument("-a", action="store_true", help="Output in ASCII table format.")
    parser.add_argument("-html", action="store_true", help="Output in HTML table format.")
    parser.add_argument("-users-only", action="store_true", help="Only output users.")
    parser.add_argument("-contacts-only", action="store_true", help="Only output contacts.")
    parser.add_argument("-test", action="store_true", help="Run in test mode (log actions, no writes).")
    parser.add_argument("-debug", action="store_true", help="Enable debug output.")
    # DL management flags
    parser.add_argument("-dl", "--distribution-list", help="DL name (e.g., 'FieldsFamilyExt').")
    parser.add_argument("-lm", "--list-members", action="store_true", help="List members of DL (requires -dl).")
    parser.add_argument("-am", "--add-member", help="Add user to DL by user ID (requires -dl).")
    parser.add_argument("-um", "--update-members", action="store_true", help="Update DL with contacts matching company (requires -dl, -c).")
    parser.add_argument("-cdl", "--create-dl", action="store_true", help="Create new DL if it doesn't exist (requires -dl-display-name, -dl-mail-nickname).")
    parser.add_argument("-dl-display-name", help="Display name for new DL (requires -create-dl or -update-members with -cdl).")
    parser.add_argument("-dl-mail-nickname", help="Mail nickname for new DL (requires -create-dl or -update-members with -cdl).")
    
    args = parser.parse_args()
    
    # Validate output format
    format_type = "ascii"
    if args.csv:
        format_type = "csv"
    elif args.html:
        format_type = "html"
    elif args.a:
        format_type = "ascii"
    
    # Validate mutually exclusive flags for list mode
    if args.company and (args.users_only and args.contacts_only):
        log_message("Cannot specify both --users-only and --contacts-only.", "ERROR", args.debug)
        sys.exit(1)
    
    # DL mode validation
    if args.distribution_list and args.create_dl:
        if not args.dl_display_name or not args.dl_mail_nickname:
            log_message("Display name and mail nickname required for create-dl.", "ERROR", args.debug)
            sys.exit(1)
    if args.add_member and not args.distribution_list:
        log_message("DL name required for add-member.", "ERROR", args.debug)
        sys.exit(1)
    if args.list_members and not args.distribution_list:
        log_message("DL name required for list-members.", "ERROR", args.debug)
        sys.exit(1)
    if args.update_members and (not args.distribution_list or not args.company):
        log_message("DL name and company name required for update-members.", "ERROR", args.debug)
        sys.exit(1)
    
    if args.debug:
        log_message(f"Parsed company argument: {args.company}, DL name: {args.distribution_list}", "DEBUG", args.debug)
    
    # Determine action
    dl_action = None
    if args.list_members:
        dl_action = "list-members"
    elif args.add_member:
        dl_action = "add-member"
    elif args.create_dl:
        dl_action = "create-dl"
    elif args.update_members:
        dl_action = "update-members"
    
    list_contacts(args.company, format_type, args.users_only, args.contacts_only, args.test, args.debug, args.distribution_list, dl_action, args.add_member, args.dl_display_name, args.dl_mail_nickname)