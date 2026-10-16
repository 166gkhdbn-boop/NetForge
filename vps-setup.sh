#!/bin/bash
# NetForge standalone VPS setup (alternative to the deploy.sh menu).
# Generates a FRESH UUID + secret path on every run — never hardcode credentials.
set -euo pipefail

UUID="$(cat /proc/sys/kernel/random/uuid)"
SECP="/nf-$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')"
PORT="${NF_PORT:-444}"

echo "[1/4] Installing Xray..."
if [ -f /usr/local/xray/xray ]; then
  echo "Xray already installed: $(/usr/local/xray/xray version 2>&1 | head -1)"
else
  bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
fi

echo "[2/4] Writing config..."
mkdir -p /usr/local/xray
cat > /usr/local/xray/config.json << XCFG
{
  "log": {
    "loglevel": "warning"
  },
  "stats": {},
  "inbounds": [
    {
      "tag": "vless-xhttp",
      "port": $PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
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
          "path": "$SECP/",
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
chmod 600 /usr/local/xray/config.json

echo "[3/4] Tuning network (BBR + buffers, best-effort)..."
cat > /etc/sysctl.d/99-netforge.conf << 'SYSCTL'
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
SYSCTL
sysctl --system >/dev/null 2>&1 || true

echo "[4/4] Starting Xray..."
cat > /etc/systemd/system/xray.service << XSVC
[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/xray/xray run -config /usr/local/xray/config.json
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
XSVC

systemctl daemon-reload
systemctl enable xray 2>/dev/null || true
systemctl restart xray
sleep 2

# Firewall
iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || true
ufw allow "$PORT"/tcp 2>/dev/null || true

echo ""
echo "=== STATUS ==="
systemctl is-active xray
ss -tlnp 2>/dev/null | grep ":$PORT" || true

echo ""
echo "=== XRAY READY on port $PORT ==="
echo "UUID:        $UUID"
echo "Secret path: $SECP/"
echo ""
echo "Save these credentials somewhere safe — they are unique to this install."
