#!/bin/bash
set -e
echo "[1/3] Installing Xray..."
if [ -f /usr/local/xray/xray ]; then
  echo "Xray already installed: $(/usr/local/xray/xray version 2>&1 | head -1)"
else
  bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
fi

echo "[2/3] Writing config..."
mkdir -p /usr/local/xray
cat > /usr/local/xray/config.json << 'XCFG'
{
  "log": {
    "loglevel": "warning"
  },
  "stats": {},
  "inbounds": [
    {
      "tag": "vless-xhttp",
      "port": 444,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "e71bd6ad-23a5-4dea-bf74-78b7886b0b37",
            "flow": ""
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "path": "/nf-d94e3af0/",
          "mode": "auto",
          "extra": {
            "xPaddingBytes": "1-1",
            "xPaddingObfsMode": true,
            "xPaddingKey": "iran",
            "xPaddingHeader": "iran",
            "scMaxEachPostBytes": "1000000"
          }
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
XCFG

echo "[3/3] Starting Xray..."
cat > /etc/systemd/system/xray.service << 'XSVC'
[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/xray/xray run -config /usr/local/xray/config.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
XSVC

systemctl daemon-reload
systemctl enable xray 2>/dev/null
systemctl restart xray
sleep 2

# Firewall
iptables -I INPUT -p tcp --dport 444 -j ACCEPT 2>/dev/null || true
ufw allow 444/tcp 2>/dev/null || true

echo ""
echo "=== STATUS ==="
systemctl is-active xray
ss -tlnp | grep :444

echo ""
echo "=== XRAY READY on port 444 ==="
