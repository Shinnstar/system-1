#!/usr/bin/python3
import os
import requests
import time
from datetime import datetime
from dateutil import parser

# Konfigurasi API Pterodactyl
PANEL_URL = "https://arzan.official-store.live"  # Ganti dengan URL panel Pterodactyl kamu
API_KEY = os.getenv("ptla_C4ozAF4OaFJWESw8FJRipVbEwL9QCCoJvZnZBUGHJdg")  # API Key diambil dari environment variable

# Daftar user ID yang tidak boleh dihapus
EXCLUDED_USERS = [1]  # Ganti dengan ID user yang ingin dikecualikan

# File log
LOG_FILE = "system-panel.log"

def log(message):
    """Menulis log ke file dengan timestamp."""
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now()}] {message}\n")

def get_headers():
    """Membuat header autentikasi untuk API request."""
    return {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}

def get_users():
    """Mengambil daftar pengguna dari API Pterodactyl."""
    try:
        response = requests.get(f"{PANEL_URL}/api/application/users", headers=get_headers(), timeout=10)
        response.raise_for_status()
        return response.json().get("data", [])
    except requests.RequestException as e:
        log(f"Error saat mengambil daftar user: {e}")
        return []

def get_user_servers(user_id):
    """Mengambil daftar server yang dimiliki pengguna."""
    try:
        response = requests.get(f"{PANEL_URL}/api/application/users/{user_id}/servers", headers=get_headers(), timeout=10)
        response.raise_for_status()
        return response.json().get("data", [])
    except requests.RequestException as e:
        log(f"Error saat mengambil server user {user_id}: {e}")
        return []

def delete_server(server_id):
    """Menghapus server berdasarkan ID."""
    try:
        response = requests.delete(f"{PANEL_URL}/api/application/servers/{server_id}", headers=get_headers(), timeout=10)
        if response.status_code == 204:
            log(f"Server {server_id} berhasil dihapus.")
        else:
            log(f"Gagal menghapus server {server_id}: {response.text}")
    except requests.RequestException as e:
        log(f"Error saat menghapus server {server_id}: {e}")

def delete_user(user_id):
    """Menghapus pengguna berdasarkan ID."""
    try:
        response = requests.delete(f"{PANEL_URL}/api/application/users/{user_id}", headers=get_headers(), timeout=10)
        if response.status_code == 204:
            log(f"User {user_id} berhasil dihapus.")
        else:
            log(f"Gagal menghapus user {user_id}: {response.text}")
    except requests.RequestException as e:
        log(f"Error saat menghapus user {user_id}: {e}")

def main():
    """Proses utama pengecekan dan penghapusan pengguna yang sudah lama."""
    users = get_users()
    now = datetime.utcnow()

    for user in users:
        user_id = user["attributes"]["id"]
        username = user["attributes"]["username"]

        # Lewati user yang dikecualikan
        if user_id in EXCLUDED_USERS:
            log(f"User {username} dikecualikan, tidak dihapus.")
            continue

        # Ambil tanggal pembuatan akun
        created_at_str = user["attributes"]["created_at"]
        created_at = parser.isoparse(created_at_str)
        days_since_creation = (now - created_at.replace(tzinfo=None)).days

        if days_since_creation >= 30:
            # Hapus semua server milik user
            servers = get_user_servers(user_id)
            for server in servers:
                delete_server(server["attributes"]["id"])
                time.sleep(1)  # Hindari rate limiting

            # Hapus user setelah servernya dihapus
            delete_user(user_id)
            log(f"User {username} dihapus bersama semua servernya.")
        else:
            log(f"User {username} belum mencapai 30 hari, tidak dihapus.")

if __name__ == "__main__":
    main()
