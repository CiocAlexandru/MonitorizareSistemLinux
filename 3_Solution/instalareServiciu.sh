#!/bin/bash

# === CONFIG ===
SCRIPT_PATH="/home/cioc/Practica/MonitorizareSistemLinux/3_Solution/monitorizare.sh"
SERVICE_NAME="monitorizare"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LOG_PATH="/var/log/${SERVICE_NAME}.log"
ERR_PATH="/var/log/${SERVICE_NAME}.err"

# === VERIFICĂM EXISTENȚA SCRIPTULUI ===
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "❌ Scriptul $SCRIPT_PATH nu există. Modifică variabila SCRIPT_PATH."
    exit 1
fi

# === FACEM SCRIPTUL EXECUTABIL ===
chmod +x "$SCRIPT_PATH"

# === CREĂM FIȘIERUL DE SERVICIU ===
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Monitorizare sistem - serviciu custom
After=network.target

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
User=root
StandardOutput=file:$LOG_PATH
StandardError=file:$ERR_PATH

[Install]
WantedBy=multi-user.target
EOF

# === REÎNCĂRCĂM systemd și activăm serviciul ===
sudo systemctl daemon-reexec
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

echo "✅ Serviciul '$SERVICE_NAME' a fost instalat și pornit."
echo "📋 Status: sudo systemctl status $SERVICE_NAME"

