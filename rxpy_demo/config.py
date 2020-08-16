import os

TOKEN = os.environ("GIT_PERSONEAL_ACCESS_TOKEN")
headers = {
    "Content-Type": "application/json",
    "Authorization": f"token {TOKEN}"
}
GITHUB_API_URL = "https://api.github.com"
orgs = ["/twitter/repos", "/auth0/repos", "/nasa/repos", "/mozilla/repos", "/adobe/repos"]
GIT_ORG = f"{GITHUB_API_URL}/orgs"
