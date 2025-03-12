import os
import json
import argparse
import requests
from o365_auth import get_access_token  # Import authentication function

# Microsoft Graph API endpoint for listing users
GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0/users"

# Output directory
OUTPUT_DIR = "o365_users"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def get_users(debug=False):
    """ Retrieve all email addresses/accounts, including license and login status. """
    token = get_access_token()
    if not token:
        print("❌ Failed to authenticate.")
        return None

    headers = {"Authorization": f"Bearer {token}"}
    
    # Fetch user email, display name, license status, and login enabled status
    url = f"{GRAPH_API_ENDPOINT}?$select=displayName,mail,userPrincipalName,accountEnabled,assignedLicenses"

    users = []
    while url:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            users.extend(data.get("value", []))
            url = data.get("@odata.nextLink", None)  # Handle pagination
        else:
            print(f"❌ Failed to fetch users: {response.text}")
            return None

    # Only keep users with an email address
    users = [user for user in users if user.get("mail")]

    if debug:
        print(json.dumps(users, indent=4))

    return users


def save_users(users):
    """ Save the list of users to a file """
    file_path = os.path.join(OUTPUT_DIR, "o365_users.json")
    with open(file_path, "w") as f:
        json.dump(users, f, indent=4)

    print(f"✅ User list saved to {file_path}")


def list_users(users, verbose=False):
    """ Print users, including whether they are licensed and enabled for login. """
    for user in users:
        email = user.get("mail", "").strip()
        name = user.get("displayName", "").strip()
        account_enabled = user.get("accountEnabled", False)  # True = Login enabled
        has_license = bool(user.get("assignedLicenses"))  # True = Has at least 1 license

        if email:
            if verbose:
                print(f"{name} ({email}) - Login: {'✔️ Enabled' if account_enabled else '❌ Disabled'} | License: {'✔️ Licensed' if has_license else '❌ Unlicensed'}")
            else:
                #print(f"{email},{account_enabled},{has_license}")
                print(f"{email},{'Enabled' if account_enabled else 'Disabled'},{'Licensed' if has_license else 'Unlicensed'}")



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Retrieve Office 365 email addresses.")
    parser.add_argument("-ls", action="store_true", help="List users in Office 365")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show detailed user info")
    parser.add_argument("-save", action="store_true", help="Save users to o365_users.json")
    parser.add_argument("-d", "--debug", action="store_true", help="Debug mode (show raw JSON)")

    args = parser.parse_args()

    users = get_users(args.debug)
    if not users:
        exit(1)

    if args.ls:
        list_users(users, args.verbose)

    if args.save:
        save_users(users)
