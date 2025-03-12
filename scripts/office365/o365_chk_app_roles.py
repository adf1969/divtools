import os
import json
import argparse
import requests
from datetime import datetime
from o365_auth import get_access_token  # Import authentication function

# Microsoft Graph API endpoints
GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0"
ROLE_DIR = "o365_admin_roles"  # Directory to store admin roles

# Ensure the directory exists
os.makedirs(ROLE_DIR, exist_ok=True)

# Function to get all users in Office 365
def get_all_users(token):
    users = []
    url = f"{GRAPH_API_ENDPOINT}/users?$select=id,displayName,mail"
    headers = {"Authorization": f"Bearer {token}"}

    while url:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            users.extend(data.get("value", []))
            url = data.get("@odata.nextLink", None)  # Handle pagination
        else:
            print(f"❌ Failed to fetch users: {response.text}")
            return None

    return users

# Function to get assigned roles for a user
def get_user_roles(user_id, token):
    url = f"{GRAPH_API_ENDPOINT}/users/{user_id}/appRoleAssignments"
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.json().get("value", [])
    else:
        print(f"❌ Failed to get roles for {user_id}: {response.text}")
        return None

# Function to save admin roles to a file
def save_roles(user_email, roles):
    file_path = os.path.join(ROLE_DIR, f"{user_email}.json")
    data = {
        "timestamp": datetime.utcnow().isoformat(),
        "roles": roles
    }
    with open(file_path, "w") as f:
        json.dump(data, f, indent=4)
    print(f"✅ Saved roles for {user_email} ({len(roles)} roles) to {file_path}")

# Function to fetch and store admin roles for all users
def fetch_admin_roles():
    token = get_access_token()
    if not token:
        print("❌ Failed to authenticate.")
        return

    users = get_all_users(token)
    if not users:
        print("❌ No users found.")
        return

    print(f"🔍 Checking admin roles for {len(users)} users...\n")

    for user in users:
        user_email = user.get("mail", user.get("id"))  # Use email if available
        if not user_email:
            print(f"⚠️ Skipping user {user.get('displayName', 'Unknown')} (No email)")
            continue

        roles = get_user_roles(user['id'], token)
        if roles is not None:
            save_roles(user_email, roles)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Retrieve Office 365 Admin Roles for All Users")
    parser.add_argument("-get", action="store_true", help="Retrieve current admin roles for all users")
    args = parser.parse_args()

    if args.get:
        fetch_admin_roles()
