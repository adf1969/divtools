import msal
import requests
import os
from dotenv import load_dotenv

# Load environment variables from .env file
env_path = os.path.join(os.path.dirname(__file__), "secrets", ".env")
load_dotenv(env_path)

# Retrieve credentials from environment variables
TENANT_ID = os.getenv("TENANT_ID")
CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")

if not all([TENANT_ID, CLIENT_ID, CLIENT_SECRET]):
    raise ValueError("Missing required environment variables. Please check your .env file.")

AUTHORITY = f"https://login.microsoftonline.com/{TENANT_ID}"
GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0"

# Function to authenticate and get an access token
def get_access_token():
    app = msal.ConfidentialClientApplication(
        CLIENT_ID, authority=AUTHORITY, client_credential=CLIENT_SECRET
    )
    token_response = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])

    if "access_token" in token_response:
        return token_response["access_token"]
    else:
        print("Error getting token:", token_response.get("error_description", "Unknown error"))
        return None

# Test authentication
if __name__ == "__main__":
    token = get_access_token()
    if token:
        print("Authentication successful!")
        print("Access Token:", token[:50] + "... (truncated)")
