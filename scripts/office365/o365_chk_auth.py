import json
from o365_auth import get_access_token
import requests

def main():
    print("🔐 Checking Office365 access token...")

    try:
        token = get_access_token()
        if not token:
            print("❌ No token returned from get_access_token()")
            return

        print("✅ Token retrieved.")
        print("Access token (truncated):")
        print(token[:80] + "..." if len(token) > 80 else token)

        headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json"
        }

        resp = requests.get("https://graph.microsoft.com/v1.0/me", headers=headers)

        if resp.status_code == 200:
            profile = resp.json()
            print("✅ Token is valid. Connected to Office365 account:")
            print(f"  Name: {profile.get('displayName')}")
            print(f"  Email: {profile.get('userPrincipalName')}")
        else:
            print(f"❌ Token is invalid or expired. Status: {resp.status_code}")
            print(resp.text)

    except Exception as e:
        print("❌ Error while checking token:")
        print(e)


if __name__ == "__main__":
    main()
