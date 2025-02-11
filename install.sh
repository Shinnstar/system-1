#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Harap jalankan script ini sebagai root!"
    exit 1
fi

# Install dependensi
echo "🔹 Menginstall dependensi..."
apt update && apt install -y python3 python3-pip curl nano git

# Tentukan lokasi file tujuan (di sini kita gunakan /root)
TARGET_DIR="/root"
SYSTEM_PANEL_FILE="$TARGET_DIR/system-1/system-panel.py"

# Unduh file system-panel.py dari GitHub
# Ganti URL berikut dengan URL raw dari file system-panel.py di repo GitHub kamu
GITHUB_URL="https://raw.githubusercontent.com/arzanoffc1/system-1/main/system-panel.py"

echo "🔹 Mengunduh file system-panel.py dari GitHub..."
curl -s -o "$SYSTEM_PANEL_FILE" "$GITHUB_URL"

if [ ! -f "$SYSTEM_PANEL_FILE" ]; then
    echo "❌ Gagal mengunduh file system-panel.py"
    exit 1
fi

# Beri izin eksekusi ke system-panel.py
chmod +x "$SYSTEM_PANEL_FILE"

# Tambahkan cron job untuk menjalankan system-panel.py setiap pukul 00:00
echo "🔹 Menambahkan cron job untuk menjalankan system-panel.py setiap pukul 00:00..."
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/python3 $SYSTEM_PANEL_FILE") | crontab -

echo "✅ Instalasi selesai! Script akan berjalan otomatis setiap jam 00:00."
echo "📄 Log dapat dicek di: ${TARGET_DIR}/system-panel.log"
