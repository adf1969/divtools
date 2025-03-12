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

# Directory to store admin roles
ADMIN_ROLES_DIR = "o365_admin_roles"
# Ensure directory exists
os.makedirs(ADMIN_ROLES_DIR, exist_ok=True)

# Alert directories
ALERTS_DIR = "alerts"
ARCHIVE_DIR = "alerts.archive"
os.makedirs(ALERTS_DIR, exist_ok=True)
os.makedirs(ARCHIVE_DIR, exist_ok=True)

SENDER_NAME = "Office365 Monitor"
SENDER_EMAIL = "avcorp.smtp@gmail.com"


def get_all_users(token, debug=False):
    """ Retrieve all users from Microsoft Graph API. """
    url = f"{GRAPH_API_ENDPOINT}/users"
    headers = {"Authorization": f"Bearer {token}"}
    users = []

    while url:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            if debug:
                print("📜 Raw User Data:")
                print(json.dumps(data, indent=4))

            users.extend(data.get("value", []))
            url = data.get("@odata.nextLink")  # Handle pagination
        else:
            print(f"❌ Failed to retrieve users: {response.text}")
            return []

    return users


def get_admin_roles(user_id, token, debug=False):
    """ Retrieve Azure AD Admin Roles assigned to a user. """
    url = f"{GRAPH_API_ENDPOINT}/users/{user_id}/memberOf"
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        groups = response.json().get("value", [])

        if debug:
            print(f"📜 Raw Role Data for {user_id}:")
            print(json.dumps(groups, indent=4))

        # Filter only Directory Roles (Admin Roles)
        admin_roles = [group["displayName"] for group in groups if "roleTemplateId" in group]
        return admin_roles
    else:
        print(f"❌ Failed to retrieve admin roles for {user_id}: {response.text}")
        return []


def save_admin_roles(user_email, data):
    """ Save retrieved admin roles to a file. """
    file_path = os.path.join(ADMIN_ROLES_DIR, f"{user_email}.json")
    with open(file_path, "w") as f:
        json.dump(data, f, indent=4)
    print(f"✅ Saved admin roles for {user_email} (Timestamp: {data['timestamp']}) to {file_path}")


def load_saved_roles(user_email):
    """ Load previously saved admin roles for a user. """
    file_path = os.path.join(ADMIN_ROLES_DIR, f"{user_email}.json")
    if not os.path.exists(file_path):
        return None
    with open(file_path, "r") as f:
        data = json.load(f)
    return data  # Includes timestamp and roles


def compare_admin_roles(user_email, current_roles):
    """ Compare saved roles with current roles. """
    saved_data = load_saved_roles(user_email)
    if saved_data is None:
        return None

    saved_roles = set(saved_data["roles"])
    current_roles = set(current_roles)

    changes = []

    # Identify new roles
    new_roles = current_roles - saved_roles
    if new_roles:
        for role in new_roles:
            changes.append(f"NEW: {role}")

    # Identify removed roles
    removed_roles = saved_roles - current_roles
    if removed_roles:
        for role in removed_roles:
            changes.append(f"DEL: {role}")

    return changes if changes else None


def get_alert_filename(user_email):
    """ Generate alert filename for admin roles. """
    return os.path.join(ALERTS_DIR, f"admrole_{user_email}.txt")


def alert_exists(alert_filename):
    """ Check if an alert file exists and return its timestamp. """
    if os.path.exists(alert_filename):
        with open(alert_filename, "r") as f:
            first_line = f.readline().strip()
            if first_line.startswith("Timestamp:"):
                return first_line.replace("Timestamp: ", "")
    return None


def save_alert(alert_filename, content):
    """ Save the alert to a file with timestamp. """
    timestamp = datetime.utcnow().isoformat()
    with open(alert_filename, "w") as f:
        f.write(f"Timestamp: {timestamp}\n{content}")


def send_email(recipient, subject, body):
    """ Send email notification. """
    msg = MIMEText(body)
    msg["Subject"] = subject
    #msg["From"] = f"{SENDER_NAME} <{SENDER_EMAIL}>"
    msg["From"] = f"{SENDER_NAME}"
    msg["To"] = recipient
    # Add High Priority Headers
    msg["X-Priority"] = "1"  # 1 = High, 3 = Normal, 5 = Low
    msg["X-MSMail-Priority"] = "High"  # Outlook-specific priority
    msg["Importance"] = "High"  # For email clients like Thunderbird    

    with smtplib.SMTP("localhost") as server:
        server.sendmail(SENDER_EMAIL, [recipient], msg.as_string())


def clear_alerts():
    """ Move alert files to the archive folder with a timestamped name. """
    for file in os.listdir(ALERTS_DIR):
        original_path = os.path.join(ALERTS_DIR, file)
        timestamp = datetime.utcnow().strftime("%Y-%m-%d-%H%M")
        new_file_name = f"{file.replace('.txt', '')}-{timestamp}.txt"
        new_path = os.path.join(ARCHIVE_DIR, new_file_name)

        shutil.move(original_path, new_path)
        print(f"🗑 Cleared alert: {file} → Archived as {new_file_name}")


def list_saved_roles(verbose=False):
    """ List saved admin roles. """
    for file in os.listdir(ADMIN_ROLES_DIR):
        user = file.replace(".json", "")
        file_path = os.path.join(ADMIN_ROLES_DIR, file)

        with open(file_path, "r") as f:
            data = json.load(f)

        print(f"{user}: {len(data['roles'])} Admin Roles")

        if verbose:
            for role in data["roles"]:
                print(f"  - {role}")
            print("-" * 40)


def get_all_admin_roles(action, debug=False, email=None):
    """ Retrieve and process admin roles for all users. """
    token = get_access_token()
    if not token:
        print("❌ Failed to authenticate.")
        return

    users = get_all_users(token, debug)
    if not users:
        print("❌ No users found.")
        return

    exceptions = {}

    print("🔍 Retrieving Admin Roles for all users...\n")

    for user in users:
        user_email = user.get("userPrincipalName", "Unknown")
        user_id = user.get("id", "")

        admin_roles = get_admin_roles(user_id, token, debug)
        if action == "get-current":
            save_admin_roles(user_email, {"timestamp": datetime.utcnow().isoformat(), "roles": admin_roles})
        elif action == "compare":
            changes = compare_admin_roles(user_email, admin_roles)
            if changes:
                exceptions[user_email] = changes
                print(f"{user_email}")
                print("\n".join(changes))
                print("-" * 40)

    if email and exceptions:
        subject = f"Office365 Admin Role Exceptions: " + ", ".join([f"{u} ({len(exceptions[u])})" for u in exceptions])
        body = "\n".join([f"{u}\n" + "\n".join(exceptions[u]) for u in exceptions])
        alert_filename = get_alert_filename("admin_roles")  # Store a single alert file for admin roles

        existing_alert_timestamp = alert_exists(alert_filename)
        if existing_alert_timestamp:
            print(f"🚫 Alert already sent on {existing_alert_timestamp}. Skipping email.")
        else:
            send_email(email, subject, body)
            save_alert(alert_filename, body)
            print(f"📧 Email sent to {email}. Alert saved to {alert_filename}")



if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-get-current", action="store_true")
    parser.add_argument("-compare", action="store_true")
    parser.add_argument("-clear", action="store_true")
    parser.add_argument("-ls", action="store_true")
    parser.add_argument("-lsv", action="store_true")
    parser.add_argument("-m", "--email")
    parser.add_argument("-d", "--debug", action="store_true")

    args = parser.parse_args()

    if args.clear:
        clear_alerts()
    elif args.ls:
        list_saved_roles()
    elif args.lsv:
        list_saved_roles(verbose=True)
    else:
        action = "get-current" if args.get_current else "compare" if args.compare else None
        if action:
            get_all_admin_roles(action, args.debug, args.email)
