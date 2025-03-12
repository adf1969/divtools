import os
import json
import argparse
import requests
import smtplib
import shutil
from email.mime.text import MIMEText
from datetime import datetime
from o365_auth import get_access_token  # Import authentication function

# Microsoft Graph API endpoint
GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0"
RULES_DIR = "o365_rules"  # Directory to store rules
ALERTS_DIR = "alerts"  # Directory to store alert flags
ARCHIVE_DIR = "alerts.archive"  # Archive folder for cleared alerts
USER_FILE = "o365_users.txt"  # File with list of users
EMAIL_SUBJECT_PREFIX = "Office365 Rule Exceptions"  # Email Subject Prefix
SENDER_NAME = "Office365 Monitor"
#SENDER_EMAIL = "admin@avcorp.biz"
SENDER_EMAIL = "avcorp.smtp@gmail.com"

# Ensure necessary directories exist
for directory in [RULES_DIR, ALERTS_DIR, ARCHIVE_DIR]:
    os.makedirs(directory, exist_ok=True)

def get_users_from_file():
    """ Read users from file, ignoring extra columns (enabled, licensed). """
    users = []
    try:
        with open(USER_FILE, "r") as file:
            for line in file:
                parts = line.strip().split(",")  # Split on comma
                if parts and parts[0]:  # Ensure non-empty
                    users.append(parts[0].strip())  # Only store email
    except FileNotFoundError:
        print(f"❌ Error: User file '{USER_FILE}' not found.")
    return users

# Function to get inbox rules for a user
def get_inbox_rules(user_email, token, debug=False):
    url = f"{GRAPH_API_ENDPOINT}/users/{user_email}/mailFolders/Inbox/messageRules"
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        rules = response.json().get("value", [])
        timestamp = datetime.utcnow().isoformat()
        data = {"timestamp": timestamp, "rules": rules}

        if debug:
            print(f"📜 Downloaded rules for {user_email} (Timestamp: {timestamp}):")
            print(json.dumps(rules, indent=4))
            print("-" * 40)

        return data
    else:
        print(f"❌ Failed to get rules for {user_email}: {response.text}")
        return None

# Function to save inbox rules to a file
def save_rules(user_email, data):
    file_path = os.path.join(RULES_DIR, f"{user_email}.json")
    with open(file_path, "w") as f:
        json.dump(data, f, indent=4)
    print(f"✅ Saved rules for {user_email} (Timestamp: {data['timestamp']}) to {file_path}")

# Function to load saved rules for comparison
def load_saved_rules(user_email):
    file_path = os.path.join(RULES_DIR, f"{user_email}.json")
    if not os.path.exists(file_path):
        return None
    with open(file_path, "r") as f:
        data = json.load(f)
    return data  # Includes timestamp and rules

# Function to parse rule conditions
def parse_conditions(rule):
    conditions = []
    if "conditions" in rule:
        conds = rule["conditions"]

        # Extract email addresses from "sentToAddresses" and "fromAddresses"
        for key in ["sentToAddresses", "fromAddresses"]:
            if key in conds:
                emails = [addr["emailAddress"]["address"] for addr in conds[key]]
                conditions.append(f"{key}: {', '.join(emails)}")

        # Extract text-based conditions
        for key in ["subjectContains", "senderContains"]:
            if key in conds:
                values = ", ".join(conds[key])
                conditions.append(f"{key}: {values}")

    return "; ".join(conditions) if conditions else "No Conditions"

# Function to parse rule actions
def parse_actions(rule):
    actions = []
    if "actions" in rule:
        act = rule["actions"]

        if "moveToFolder" in act:
            actions.append("moveToFolder")
        if act.get("delete", False):
            actions.append("delete")
        if act.get("stopProcessingRules", False):
            actions.append("stopProcessingRules")

    return " | ".join(actions) if actions else "No Actions"

# Function to compare current rules with saved rules
def compare_rules(user_email, current_rules):
    saved_data = load_saved_rules(user_email)
    if saved_data is None:
        return None

    saved_rules = saved_data["rules"]
    saved_rules_dict = {rule["id"]: rule for rule in saved_rules}
    current_rules_dict = {rule["id"]: rule for rule in current_rules}

    changes = []

    for rule_id, rule in current_rules_dict.items():
        display_name = rule.get("displayName", "Unnamed Rule")
        new_condition = parse_conditions(rule)
        new_action = parse_actions(rule)
        new_enabled_status = rule.get("isEnabled", True)

        if rule_id not in saved_rules_dict:
            changes.append(f"NEW: {display_name}: {new_condition} | {new_action} | Enabled: {new_enabled_status}")
        else:
            old_rule = saved_rules_dict[rule_id]
            old_condition = parse_conditions(old_rule)
            old_action = parse_actions(old_rule)
            old_enabled_status = old_rule.get("isEnabled", True)

            if (
                old_condition != new_condition
                or old_action != new_action
                or old_enabled_status != new_enabled_status
            ):
                changes.append(f"CHG: {display_name}:")
                if old_enabled_status != new_enabled_status:
                    changes.append(f"  STATUS CHG> Enabled: {old_enabled_status} → {new_enabled_status}")
                if old_condition != new_condition or old_action != new_action:
                    changes.append(f"  OLD> {old_condition} | {old_action}")
                    changes.append(f"  NEW> {new_condition} | {new_action}")

    for rule_id, rule in saved_rules_dict.items():
        if rule_id not in current_rules_dict:
            display_name = rule.get("displayName", "Unnamed Rule")
            condition = parse_conditions(rule)
            action = parse_actions(rule)
            enabled_status = rule.get("isEnabled", True)
            changes.append(f"DEL: {display_name}: {condition} | {action} | Enabled: {enabled_status}")

    return changes if changes else None


# Function to check if an alert was already sent
def get_alert_filename(users):
    user_str = "_".join(sorted(users)).replace("@", "_").replace(".", "_")
    return os.path.join(ALERTS_DIR, f"alert_{user_str}.txt")

def alert_exists(alert_filename):
    """ Check if an alert file exists and return its timestamp """
    if os.path.exists(alert_filename):
        with open(alert_filename, "r") as f:
            first_line = f.readline().strip()
            if first_line.startswith("Timestamp:"):
                return first_line.replace("Timestamp: ", "")
    return None

def save_alert(alert_filename, content):
    timestamp = datetime.utcnow().isoformat()
    with open(alert_filename, "w") as f:
        f.write(f"Timestamp: {timestamp}\n{content}")

def send_email(recipient, subject, body):
    msg = MIMEText(body)
    msg["Subject"] = subject
    #msg["From"] = recipient
    #msg["From"] = f"{SENDER_NAME} <{SENDER_EMAIL}>"
    msg["From"] = f"{SENDER_NAME}"
    msg["To"] = recipient
    # Add High Priority Headers
    msg["X-Priority"] = "1"  # 1 = High, 3 = Normal, 5 = Low
    msg["X-MSMail-Priority"] = "High"  # Outlook-specific priority
    msg["Importance"] = "High"  # For email clients like Thunderbird

    #with smtplib.SMTP("localhost") as server:
    #    server.sendmail(recipient, [recipient], msg.as_string())
    with smtplib.SMTP("localhost") as server:
        server.sendmail(SENDER_EMAIL, [recipient], msg.as_string())

def list_saved_rules(verbose=False):
    """ List saved rule files and optionally display rule details. """
    for file in os.listdir(RULES_DIR):
        file_path = os.path.join(RULES_DIR, file)
        with open(file_path, "r") as f:
            data = json.load(f)

        user = file.replace(".json", "")
        timestamp = data["timestamp"]
        rule_count = len(data["rules"])
        print(f"{user} - Last Download: {timestamp} - Rules: {rule_count}")

        if verbose:
            for rule in data["rules"]:
                print(f"  {rule.get('displayName', 'Unnamed Rule')}: {parse_conditions(rule)}")
            print("-" * 40)

# Function to execute rule checking
def check_rules(action, users, debug=False, email=None):
    token = get_access_token()
    if not token:
        print("❌ Failed to authenticate.")
        return

    exceptions = {}

    for user in users:
        rules_data = get_inbox_rules(user, token, debug)
        if rules_data is None:
            continue

        if action == "get-current":
            save_rules(user, rules_data)
        elif action == "compare":
            changes = compare_rules(user, rules_data["rules"])
            if changes:
                exceptions[user] = changes
                print(user)
                print("\n".join(changes))
                print("-" * 40)

    if email and exceptions:
        subject = f"{EMAIL_SUBJECT_PREFIX}: " + ", ".join([f"{u} ({len(exceptions[u])})" for u in exceptions])
        body = "\n".join([f"{u}\n" + "\n".join(exceptions[u]) for u in exceptions])
        alert_filename = get_alert_filename(exceptions.keys())

        existing_alert_timestamp = alert_exists(alert_filename)
        if existing_alert_timestamp:
            print(f"🚫 Alert already sent on {existing_alert_timestamp}. Skipping email.")
            return

        send_email(email, subject, body)
        save_alert(alert_filename, body)
        print(f"📧 Email sent to {email}. Alert saved to {alert_filename}")

def clear_alerts():
    """ Move alert files to the archive folder with a timestamped name """
    for file in os.listdir(ALERTS_DIR):
        original_path = os.path.join(ALERTS_DIR, file)
        
        # Get the current timestamp in YYYY-MM-DD-HHMM format
        timestamp = datetime.utcnow().strftime("%Y-%m-%d-%H%M")
        
        # Extract original file name without extension
        base_name, ext = os.path.splitext(file)
        
        # New filename format: <original-name>-YYYY-MM-DD-HHMM.txt
        new_file_name = f"{base_name}-{timestamp}.txt"
        new_path = os.path.join(ARCHIVE_DIR, new_file_name)
        
        # Move and rename the file
        shutil.move(original_path, new_path)
        print(f"🗑 Cleared alert: {file} → Archived as {new_file_name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-get-current", action="store_true", help="Fetch and save current inbox rules.")
    parser.add_argument("-compare", action="store_true", help="Compare current rules against saved rules.")
    parser.add_argument("-clear", action="store_true", help="Clear saved alert flags.")
    parser.add_argument("-ls", action="store_true", help="List saved rule snapshots.")
    parser.add_argument("-lsv", action="store_true", help="List saved rules with verbose output.")
    parser.add_argument("-u", "--users", help="Comma-separated list of users.")
    parser.add_argument("-m", "--email", help="Send email if exceptions are found.")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug output.")

    args = parser.parse_args()

    users = args.users.split(",") if args.users else get_users_from_file()

    if args.ls:
        list_saved_rules()
    elif args.clear:
        clear_alerts()        
    elif args.lsv:
        list_saved_rules(verbose=True)
    elif args.get_current:
        check_rules("get-current", users, args.debug)
    elif args.compare:
        check_rules("compare", users, args.debug, args.email)
