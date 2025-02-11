#!/usr/bin/python3
import requests
from datetime import datetime

# Konfigurasi API Pterodactyl
PANEL_URL = "https://your-panel.com"  # Ganti dengan URL panel Pterodactyl kamu
API_KEY = "YOUR_ADMIN_API_KEY"        # Ganti dengan API Key Admin

# Daftar user ID yang tidak boleh dihapus
EXCLUDED_USERS = [1, 2]  # Ganti dengan ID user yang ingin dikecualikan

# File log (akan dibuat di folder yang sama dengan script)
LOG_FILE = "system-panel.log"

def log(message):
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now()}] {message}\n")

def get_users():
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    response = requests.get(f"{PANEL_URL}/api/application/users", headers=headers)
    return response.json()["data"]

def delete_server(server_id):
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    requests.delete(f"{PANEL_URL}/api/application/servers/{server_id}", headers=headers)

def delete_user(user_id):
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    requests.delete(f"{PANEL_URL}/api/application/users/{user_id}", headers=headers)

# Proses pengecekan dan penghapusan
users = get_users()
now = datetime.utcnow()

for user in users:
    user_id = user["attributes"]["id"]

    # Lewati user yang dikecualikan
    if user_id in EXCLUDED_USERS:
        log(f"User {user['attributes']['username']} dikecualikan, tidak dihapus.")
        continue

    created_at_str = user["attributes"]["created_at"]

    try:
        # Coba format dengan microsecond
        created_at = datetime.strptime(created_at_str, "%Y-%m-%dT%H:%M:%S.%fZ")
    except ValueError:
        # Jika gagal, coba format tanpa microsecond
        created_at = datetime.strptime(created_at_str, "%Y-%m-%dT%H:%M:%S%z")

    days_since_creation = (now - created_at.replace(tzinfo=None)).days

    if days_since_creation >= 30:
        # Ambil server milik user
        servers = requests.get(
            f"{PANEL_URL}/api/application/users/{user_id}/servers",
            headers={"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
        ).json()["data"]

        # Hapus semua server milik user
        for server in servers:
            delete_server(server["attributes"]["id"])
            log(f"Server {server['attributes']['id']} milik {user['attributes']['username']} dihapus.")

        # Hapus user setelah servernya dihapus
        delete_user(user_id)
        log(f"User {user['attributes']['username']} dihapus bersama semua servernya.")
