#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Harap jalankan script ini sebagai root!"
    exit 1
fi

# Pastikan script berjalan di dalam /root
INSTALL_DIR="/root"
if [ "$PWD" != "$INSTALL_DIR" ]; then
    echo "⚠️  Harap jalankan script ini dari /root"
    echo "Gunakan: cd /root && bash install.sh"
    exit 1
fi

# Install dependensi
echo "🔹 Menginstall dependensi..."
apt update && apt install -y python3 python3-pip curl nano

# Buat file script Python utama
echo "🔹 Mengunduh script auto-delete..."
cat <<EOF > system-panel.py
import requests
from datetime import datetime

# Konfigurasi API Pterodactyl
PANEL_URL = "https://your-panel.com"  # Ganti dengan URL panel Pterodactyl kamu
API_KEY = "YOUR_ADMIN_API_KEY"  # Ganti dengan API Key Admin

# Daftar user ID yang tidak boleh dihapus
EXCLUDED_USERS = [1, 2]  # Ganti dengan ID user yang ingin dikecualikan

# File log
LOG_FILE = "system-panel.log"

def log(message):
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now()}] {message}\\n")

# Fungsi untuk mendapatkan daftar user
def get_users():
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    response = requests.get(f"{PANEL_URL}/api/application/users", headers=headers)
    return response.json()["data"]

# Fungsi untuk menghapus server berdasarkan ID
def delete_server(server_id):
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    requests.delete(f"{PANEL_URL}/api/application/servers/{server_id}", headers=headers)

# Fungsi untuk menghapus user berdasarkan ID
def delete_user(user_id):
    headers = {"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}
    requests.delete(f"{PANEL_URL}/api/application/users/{user_id}", headers=headers)

# Cek user yang sudah 30 hari
users = get_users()
now = datetime.utcnow()

for user in users:
    user_id = user["attributes"]["id"]
    
    # Skip user yang ada di daftar pengecualian
    if user_id in EXCLUDED_USERS:
        log(f"User {user['attributes']['username']} dikecualikan, tidak dihapus.")
        continue

    created_at_str = user["attributes"]["created_at"]

    try:
        created_at = datetime.strptime(created_at_str, "%Y-%m-%dT%H:%M:%S.%fZ")  # Format dengan microsecond
    except ValueError:
        created_at = datetime.strptime(created_at_str, "%Y-%m-%dT%H:%M:%S%z")  # Format tanpa microsecond

    days_since_creation = (now - created_at.replace(tzinfo=None)).days

    if days_since_creation >= 30:
        servers = requests.get(f"{PANEL_URL}/api/application/users/{user_id}/servers", headers={"Authorization": f"Bearer {API_KEY}", "Accept": "application/json"}).json()["data"]

        for server in servers:
            delete_server(server["attributes"]["id"])
            log(f"Server {server['attributes']['id']} milik {user['attributes']['username']} dihapus.")

        delete_user(user_id)
        log(f"User {user['attributes']['username']} dihapus bersama semua servernya.")
EOF

# Beri izin eksekusi ke script
chmod +x system-panel.py

# Tambahkan cron job otomatis
echo "🔹 Menambahkan cron job untuk menjalankan script setiap pukul 00:00..."
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/python3 /root/system-panel.py") | crontab -

# Selesai
echo "✅ Instalasi selesai! Script akan berjalan otomatis setiap jam 00:00."
echo "📄 Log bisa dicek di: /root/system-panel.log"
