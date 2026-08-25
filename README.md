<p align="center">
  <img src="https://img.shields.io/badge/Version-2.0-00d4ff?style=for-the-badge&logo=github&logoColor=white" alt="Version">
  <img src="https://img.shields.io/badge/License-MIT-00d4ff?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/Python-3.8+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/XRay-Core-1.8+-00d4ff?style=for-the-badge" alt="XRay">
</p>

<h1 align="center">
  <br>
  <a href="https://github.com/166gkhdbn-boop/NetForge"><img src="https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/.github/banner.png" alt="NetForge" width="500"></a>
  <br>
  <br>
</h1>

<p align="center">
  <b>Stealth VLESS XHTTP Relay Behind Netlify CDN</b><br>
  <i>Beautiful interactive CLI manager — single file, zero dependencies</i>
</p>

<p align="center">
  <a href="/166gkhdbn-boop/NetForge/blob/main/README-fa.md">🇮🇷 فارسی</a>
  •
  <a href="#features">✨ Features</a>
  •
  <a href="#quick-start">🚀 Quick Start</a>
  •
  <a href="#installation">💾 Installation</a>
  •
  <a href="#screenshots">📸 Screenshots</a>
</p>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🗡️ **Stealth Relay** | Routes VLESS traffic through Netlify CDN, hiding your server's real IP |
| 🌐 **XHTTP Transport** | Uses XHTTP (split-stream) protocol for maximum stealth |
| 🔲 **Xray Auto-Install** | Automatically downloads and configures the latest Xray-core |
| 📦 **Single File** | Everything in one `deploy.sh` file — no dependencies, no git clone needed |
| 🎨 **Beautiful CLI** | Gradient text, animated spinners, double-line boxes, 256-color terminal UI |
| 🔄 **Easy Deploy** | One command to deploy a relay site to Netlify |
| 📋 **VLESS Link Generator** | Generates ready-to-use connection links with xPadding |
| 📝 **Config Manager** | Interactive configuration for UUID, SNI, ports, and paths |
| 📱 **Fake Website** | Deploys a realistic DevPulse analytics site as cover |
| 🐐 **Systemd Service** | Manages Xray as a system service with start/stop/restart |
| 🔧 **Deployment Manager** | View, track, and delete Netlify deployments |

---

## 🚀 Quick Start

```bash
# One-line install and run
bash <(curl -sL https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh)
```

That's it. The script will launch an interactive menu where you can:

1. **Install Xray** — automatically downloads latest release
2. **Configure** — set UUID, SNI, port, secret path
3. **Set Token** — enter your Netlify personal access token
4. **Deploy** — create a stealth relay site on Netlify
5. **Generate Link** — get your VLESS connection string

---

## 💾 Installation

### ⚡ One-Line (Recommended)

```bash
bash <(curl -sL https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh)
```

### 📝 Manual Install

```bash
# Download the script
wget https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh -O deploy.sh

# Make executable
chmod +x deploy.sh

# Run
bash deploy.sh
```

### 🤖 Using Git

```bash
git clone https://github.com/166gkhdbn-boop/NetForge.git
cd NetForge
bash deploy.sh
```

### Requirements

- **Python 3.8+** (usually pre-installed on most servers)
- **Root access** (for Xray installation and systemd service)
- **Netlify account** with a Personal Access Token
- **TLS certificate** for your server's domain (for Xray TLS)

---

## 📸 Screenshots

```

  ╔═════════════════════════════════════════════════════════════════╗
  ║ ║
  ║     ██╗  ██╗██╗██╗██╗██╗██╗ ║
  ║     ██║  ██║██║██║██║██║██║ ║
  ║     ██║  ██║██║██║██║██║██║ ║
  ║     ██║  ██║██║██║██║██║██║ ║
  ║     ██╗  ██║██║██╗██║██║██╗ ║
  ║     ╚══╝  ╚═╝╚═╝╚═╝╚═╝╚═╝╚═╝ ║
  ║ ║
  ║        ★ XHTTP/Netlify Relay Manager ★        ║
  ║           v2.0  |  by NetForge                ║
  ║ ║
  ╠════════════════════════════════════════════════════════════════╖
  ║                                                       ║
  ║  ◆  Server IP       185.x.x.x                   ║
  ║  ◆  Xray Status     ✔ v1.8.24                   ║
  ║  ◆  Xray Port       444                         ║
  ║  ◆  UUID            a1b2c3d4...                  ║
  ║  ◆  SNI             kind.sigs.k8s.io            ║
  ║  ◆  Netlify Token   SET                         ║
  ║  ◆  Site URL        https://dp-abc.netlify.app  ║
  ║  ■ [1] Install / Update Xray    Download & setup  ║
  ║  ■ [2] Configure Settings       UUID, SNI, port   ║
  ║  ■ [3] Set Netlify Token        Access token       ║
  ║  ■ [4] Deploy to Netlify        Create relay       ║
  ║  ■ [5] Generate VLESS Link      Connection string  ║
  ╚════════════════════════════════════════════════════════════════╝

```

---

## 📖 How It Works

```
User (V2Ray Client)
       \
        v  VLESS over XHTTP (TLS)
  +-----------+     +-----------------+     +----------+
  |  Netlify  | --> |  Edge Function  | --> |  Xray    |
  |  CDN      |     |  (relay.js)    |     |  Server  |
  +-----------+     +-----------------+     +----------+
  
  Public IP          Stealth relay          Your VPS
  (Netlify's)        (invisible)            (hidden)
```

1. **Netlify CDN** — Your domain points to Netlify (or uses their `.netlify.app` domain)
2. **Edge Function** — A relay function at the secret path forwards traffic to your Xray server
3. **Xray Server** — Runs on your VPS, handles the actual VLESS protocol
4. **xPadding** — Extra obfuscation layer that mimics normal HTTP traffic patterns

The result: your server's real IP is completely hidden behind Netlify's CDN.

---

## ⚙️ Configuration

All settings are stored in `~/.vless-netlify/config.json` and persist between runs.

| Setting | Default | Description |
|---------|---------|-------------|
| `uuid` | Auto-generated | VLESS user UUID |
| `sni` | `kind.sigs.k8s.io` | Primary TLS SNI |
| `alt_sni` | `dl.google.com` | Alternative SNI |
| `xray_port` | `444` | Xray listening port |
| `secp` | Random | Secret path for relay |
| `netlify_token` | — | Netlify Personal Access Token |

---

## 💡 Getting a Netlify Token

1. Go to [Netlify User Applications](https://app.netlify.com/user/applications#personal-access-tokens)
2. Click **Create a personal access token**
3. Give it a name (e.g., "NetForge")
4. Select scopes: **Sites: Read & Write**
5. Copy the token and paste it in the script's menu option 3

---

## 📞 Menu Options

| # | Option | Description |
|---|--------|-------------|
| 1 | Install / Update Xray | Downloads latest Xray-core from GitHub releases |
| 2 | Configure Settings | Set UUID, SNI, server IP, port, secret path |
| 3 | Set Netlify Token | Configure your Netlify Personal Access Token |
| 4 | Deploy to Netlify | Create a new relay site with edge function |
| 5 | Generate VLESS Link | Create connection links (full + QR-friendly) |
| 6 | Manage Deployments | View, delete, or clear Netlify deployments |
| 7 | Xray Service Control | Start, stop, restart Xray; view logs |
| 8 | Show Full Config | Display all current settings |

---

## ⚠️ Important Notes

- **TLS Certificate Required**: You need a valid TLS certificate for your server's domain before starting Xray
- **Xray listens on HTTP/2**: The XHTTP transport requires H2 support
- **Netlify Free Tier**: Works on Netlify's free plan (100GB bandwidth/month)
- **One Deployment per Run**: Each deploy creates a new Netlify site

---

## 🌟 Credits

- [Xray-core](https://github.com/XTLS/Xray-core) — The core proxy engine
- [Netlify Edge Functions](https://docs.netlify.com/edge-functions/overview/) — CDN relay layer
- [VLESS Protocol](https://xtls.github.io/en/development/protocols/vless.html) — Lightweight proxy protocol

---

<p align="center">
  <b>NetForge</b> — Building invisible bridges across borders
  <br><br>
  <img src="https://img.shields.io/badge/Made%20with-%E2%9D%A4%EF%B8%8F-red?style=for-the-badge" alt="Love">
  <img src="https://img.shields.io/badge/for-Freedom-00d4ff?style=for-the-badge" alt="Freedom">
</p>