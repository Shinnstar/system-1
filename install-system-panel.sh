#!/bin/bash

# Pastikan script dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
   echo "Script ini harus dijalankan sebagai root."
   exit 1
fi

echo "📂 Membuat direktori /root/system-1 jika belum ada..."
INSTALL_DIR="/root/system-1"
mkdir -p $INSTALL_DIR

SCRIPT_PATH="$INSTALL_DIR/system-panel.py"
LOG_FILE="$INSTALL_DIR/system-panel.log"

echo "📜 Membuat script system-panel.py..."
cat << 'EOF' > $SCRIPT_PATH
#!/usr/bin/python3
import requests
from datetime import datetime

# 🔧 Konfigurasi API Pterodactyl
PANEL_URL = "https://kampus.paneldigital.me" # Ganti dengan URL panel Pterodactyl kamu
API_KEY = "ptla_lkB37XevhOdnhPoYEVRjzvMLJPqenHPAHTlAmwSad5r"  # Ganti dengan API Key Admin

# 🔒 Daftar user ID yang tidak boleh dihapus
EXCLUDED_USERS = [1]  # Ganti dengan ID user yang ingin dikecualikan

# 📝 File log
LOG_FILE = "system-panel.log"

def log(message):
    """Menyimpan log ke file."""
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now()}] {message}\n")
    print(message)

def get_users():
    """Mengambil daftar user dari Pterodactyl API."""
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    response = requests.get(f"{PANEL_URL}/api/application/users", headers=headers)

    try:
        data = response.json()
    except requests.exceptions.JSONDecodeError:
        log("⚠️ Gagal decode JSON dari API get_users().")
        return []

    return data.get("data", [])

def get_servers(user_id):
    """Mengambil daftar server milik user tertentu."""
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    response = requests.get(f"{PANEL_URL}/api/application/servers", headers=headers)

    try:
        data = response.json()
    except requests.exceptions.JSONDecodeError:
        log(f"⚠️ Gagal decode JSON untuk user {user_id}.")
        return []

    return [s for s in data.get("data", []) if s["attributes"]["user"] == user_id]

def delete_server(server_id):
    """Menghapus server berdasarkan ID dengan validasi ulang."""
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}

    # Pastikan server masih ada sebelum menghapus
    response_check = requests.get(f"{PANEL_URL}/api/application/servers/{server_id}", headers=headers)
    if response_check.status_code == 404:
        log(f"✅ Server {server_id} sudah tidak ada, lewati.")
        return True

    # Coba hapus server
    response = requests.delete(f"{PANEL_URL}/api/application/servers/{server_id}", headers=headers)

    if response.status_code == 204:
        log(f"✅ Server {server_id} berhasil dihapus.")
        return True
    else:
        log(f"❌ Gagal menghapus server {server_id}: {response.text}")
        return False

def delete_all_servers(user_id):
    """Menghapus semua server milik user sebelum menghapus user."""
    servers = get_servers(user_id)

    for server in servers:
        server_id = server["attributes"]["id"]

        for attempt in range(3):  # Coba hapus hingga 3 kali
            if delete_server(server_id):
                break
            log(f"🔄 Percobaan {attempt+1} gagal, coba lagi...")

    # Cek apakah masih ada server
    if get_servers(user_id):
        log(f"❌ Masih ada server yang tersisa untuk user {user_id}, tidak bisa hapus user.")
        return False
    return True

def delete_user(user_id):
    """Menghapus user setelah semua servernya dihapus."""
    if not delete_all_servers(user_id):
        return

    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    response = requests.delete(f"{PANEL_URL}/api/application/users/{user_id}", headers=headers)

    if response.status_code == 204:
        log(f"✅ User {user_id} berhasil dihapus.")
    else:
        log(f"❌ Gagal menghapus user {user_id}: {response.text}")

# 🔄 Mulai proses pengecekan
users = get_users()
now = datetime.utcnow()

for user in users:
    user_id = user["attributes"]["id"]

    # Lewati user yang dikecualikan
    if user_id in EXCLUDED_USERS:
        log(f"⏩ User {user['attributes']['username']} dikecualikan, tidak dihapus.")
        continue

    created_at_str = user["attributes"]["created_at"]

    # Tangani format tanggal yang berbeda
    try:
        created_at = datetime.strptime(created_at_str, "%Y-%m-%dT%H:%M:%S.%fZ")
    except ValueError:
        try:
            created_at = datetime.strptime(created_at_str, "%Y-%m-%dT%H:%M:%S%z")
        except ValueError:
            log(f"⚠️ Format tanggal tidak dikenal untuk user {user['attributes']['username']}: {created_at_str}")
            continue

    days_since_creation = (now - created_at.replace(tzinfo=None)).days

    if days_since_creation >= 30:
        log(f"🗑️ Menghapus user {user['attributes']['username']} (ID: {user_id}) dan semua servernya.")
        delete_user(user_id)
EOF

# Pastikan script bisa dieksekusi
chmod +x $SCRIPT_PATH

echo "📦 Mengupdate paket dan menginstall dependensi..."
apt update && apt install -y python3 python3-pip

echo "🐍 Menginstall pustaka Python yang diperlukan..."
pip3 install requests

# Menambahkan cron job
echo "⏳ Menjadwalkan cron job..."
CRON_JOB="0 0 * * * /usr/bin/python3 $SCRIPT_PATH >> $LOG_FILE 2>&1"

# Cek apakah sudah ada cron job yang sama
(crontab -l 2>/dev/null | grep -F "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "✅ Instalasi selesai. System Panel Auto Cleanup sudah dibuat dan dijadwalkan setiap jam!"
