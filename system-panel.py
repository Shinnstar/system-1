#!/usr/bin/python3
import requests
from datetime import datetime
import os

# Ambil nilai PANEL_URL dan API_KEY dari environment variable,
# jika tidak ada, minta input dari user.
PANEL_URL = os.environ.get("PANEL_URL")
if not PANEL_URL:
    PANEL_URL = input("Masukkan URL Panel Pterodactyl (contoh: https://your-panel.com): ").strip()

API_KEY = os.environ.get("API_KEY")
if not API_KEY:
    API_KEY = input("Masukkan API Key Admin: ").strip()

# Ambil daftar user ID yang dikecualikan dari environment variable
# (dengan format "1,2,3"), atau minta input jika belum diset.
excluded_env = os.environ.get("EXCLUDED_USERS")
if excluded_env:
    try:
        EXCLUDED_USERS = [int(x) for x in excluded_env.split(",") if x.strip()]
    except Exception as e:
        print("Error memparsing EXCLUDED_USERS dari environment, menggunakan default [1, 2].")
        EXCLUDED_USERS = [1, 2]
else:
    user_input = input("Masukkan daftar user ID yang dikecualikan (pisahkan dengan koma, misal: 1,2). Tekan Enter untuk menggunakan default [1,2]: ").strip()
    if user_input == "":
        EXCLUDED_USERS = [1, 2]
    else:
        try:
            EXCLUDED_USERS = [int(x.strip()) for x in user_input.split(",") if x.strip().isdigit()]
        except Exception as e:
            print("Input tidak valid, menggunakan default [1, 2].")
            EXCLUDED_USERS = [1, 2]

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

    # Lewati user yang ada di daftar pengecualian
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
