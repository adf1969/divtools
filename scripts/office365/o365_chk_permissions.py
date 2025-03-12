import requests
import argparse
from o365_auth import get_access_token  # Import authentication function

# Microsoft Graph API endpoint
GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0"

# High-Value Target Users (e.g., Global Admins)
HIGH_VALUE_USERS = ["Andrew Fields", "Caleb Fields"]

# Function to get a list of all users and their emails
def get_all_users(token):
    url = f"{GRAPH_API_ENDPOINT}/users?$select=id,displayName,userPrincipalName"
    headers = {"Authorization": f"Bearer {token}"}
    
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return {user["displayName"]: user["userPrincipalName"] for user in response.json().get("value", [])}
    else:
        print(f"❌ Failed to retrieve user list: {response.text}")
        return {}

# Function to get a mailbox's Full Access delegates
def get_full_access_delegates(user_id, token):
    url = f"{GRAPH_API_ENDPOINT}/users/{user_id}/appRoleAssignments"
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        roles = response.json().get("value", [])
        return [role.get("principalDisplayName", "Unknown") for role in roles]
    else:
        print(f"❌ Failed to get Full Access delegates for {user_id}: {response.text}")
        return []

# Function to get a mailbox's Send As/Send on Behalf delegates
def get_send_as_delegates(user_id, token):
    url = f"{GRAPH_API_ENDPOINT}/users/{user_id}/transitiveMemberOf"
    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        groups = response.json().get("value", [])
        return [group.get("displayName", "Unknown") for group in groups if "Send As" in group.get("displayName", "")]
    else:
        return []

# Function to check mailbox delegation for high-value users
def check_mailbox_delegation(verbose=False):
    token = get_access_token()
    if not token:
        print("❌ Failed to authenticate.")
        return

    print("🔍 Checking mailbox delegation permissions...\n")

    all_users = get_all_users(token)
    if not all_users:
        print("❌ No users found.")
        return

    for target_name in HIGH_VALUE_USERS:
        if target_name not in all_users:
            print(f"⚠️ Skipping {target_name}: User not found.")
            continue

        user_email = all_users[target_name]
        user_id = user_email  # Graph API allows using email as ID

        full_access_delegates = get_full_access_delegates(user_id, token)
        send_as_delegates = get_send_as_delegates(user_id, token)

        # Convert delegate names to emails if possible
        full_access_delegates = [all_users.get(name, name) for name in full_access_delegates]
        send_as_delegates = [all_users.get(name, name) for name in send_as_delegates]

        if verbose:
            print(f"📜 Raw JSON Response for {user_email}:\nFull Access: {full_access_delegates}\nSend As: {send_as_delegates}\n")

        if full_access_delegates or send_as_delegates:
            print(f"⚠️ Delegation Permissions for {user_email}:")
            if full_access_delegates:
                print(f"  - Full Access Delegates: {', '.join(full_access_delegates)}")
            if send_as_delegates:
                print(f"  - Send As Delegates: {', '.join(send_as_delegates)}")
        else:
            print(f"✅ No delegation permissions found for {user_email}.")
        print("-" * 40)

# Main function to parse command-line arguments
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check Office 365 mailbox delegation permissions for high-value users.")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose mode to display raw JSON responses.")
    args = parser.parse_args()

    check_mailbox_delegation(verbose=args.verbose)
