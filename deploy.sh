#!/bin/bash
# NetForge VLESS - XHTTP/Netlify Relay Manager
# Single-file deployment script
CDIR="$HOME/.vless-netlify"
mkdir -p "$CDIR"
SELF="$0"
PY="$CDIR/manager.py"

# Handle pipe/fd execution (bash <(curl ...) or curl | bash)
case "$SELF" in
  /dev/fd/*|/proc/*/fd/*|bash|""|-bash)
    # Piped execution - always download fresh copy from GitHub
    # (cp from fd is unreliable as the fd may be drained)
    echo "  Downloading script to file..."
    SELF="$CDIR/deploy.sh"
    curl -sL "https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh" -o "$SELF" || { echo "  Download failed"; exit 1; }
    ;;
esac

if [ ! -f "$PY" ] || [ "$SELF" -nt "$PY" ]; then
  sed -n '/^__PYBOT__/,$ p' "$SELF" | sed '1d' > "$PY"
fi
exec python3 "$PY" "$@"

__PYBOT__
"""
╔═══════════════════════════════════════════════════════════╗
║  NetForge VLESS — XHTTP/Netlify Relay Manager            ║
║  Stealth VLESS behind Netlify CDN · Single-file CLI      ║
╚═══════════════════════════════════════════════════════════╝
"""

import json, urllib.parse, urllib.request, time, random, os, sys
import subprocess, textwrap, shutil, re, math, threading, zipfile, io

# Global auto mode flag
AUTO_MODE = False

# ═══════════════════════════════════════════════════════════
#  COLOR SYSTEM  —  256-color xterm palette
# ═══════════════════════════════════════════════════════════
class C:
    RST   = "\033[0m"
    BOLD  = "\033[1m"
    DIM   = "\033[2m"
    ITAL  = "\033[3m"
    # Foreground
    BLK   = "\033[38;5;0m"
    WHT   = "\033[97m"
    GRY   = "\033[38;5;245m"
    DGRY  = "\033[38;5;240m"
    RED   = "\033[91m"
    LRED  = "\033[38;5;203m"
    GRN   = "\033[92m"
    LGRN  = "\033[38;5;82m"
    YLW   = "\033[93m"
    LYLW  = "\033[38;5;227m"
    BLU   = "\033[38;5;75m"
    LBLU  = "\033[38;5;117m"
    CYN   = "\033[38;5;45m"
    LCYN  = "\033[38;5;87m"
    MAG   = "\033[38;5;177m"
    ORG   = "\033[38;5;208m"
    TEAL  = "\033[38;5;78m"
    MINT  = "\033[38;5;121m"
    PINK  = "\033[38;5;213m"
    GOLD  = "\033[38;5;220m"
    SILVER= "\033[38;5;189m"
    # Background
    BG0   = "\033[48;5;0m"
    BG18  = "\033[48;5;18m"
    BG23  = "\033[48;5;23m"
    BGGRN = "\033[42m\033[30m"
    BGGRY = "\033[100m"
    BGCYN = "\033[46m\033[30m"
    BGRED = "\033[41m\033[37m"

# ═══════════════════════════════════════════════════════════
#  BOX-DRAWING CHARS
# ═══════════════════════════════════════════════════════════
T  = "\u2500"   # horizontal
V  = "\u2502"   # vertical
TL = "\u250c"   # top-left
TR = "\u2510"   # top-right
BL = "\u2514"   # bottom-left
BR = "\u2518"   # bottom-right
DTL= "\u2554"   # double top-left
DTR= "\u2557"   # double top-right
DBL= "\u255a"   # double bottom-left
DBR= "\u255d"   # double bottom-right
DT = "\u2550"   # double horizontal
DV = "\u2551"   # double vertical
LT = "\u252c"   # left tee
RT = "\u2524"   # right tee
TT = "\u2566"   # double left tee
TB = "\u2569"   # double right tee
# Symbols
OK = "\u2714"
NO = "\u2718"
ARR = "\u25b8"
STR = "\u2605"
DOT = "\u2022"
SQR = "\u25a0"
DIA = "\u25c6"
TRG = "\u25b6"
CHK = "\u2713"
CRS = "\u2717"
LAR = "\u2192"
UAR = "\u2191"
RAR = "\u2192"
DAR = "\u2193"

# ═══════════════════════════════════════════════════════════
#  TEXT HELPERS
# ═══════════════════════════════════════════════════════════
def _sa(s): return re.sub(r"\033\[[0-9;]*m", "", s)
def _vw(s): return len(_sa(s))
def _tw(): 
    try: return os.get_terminal_size().columns
    except: return 80

def tx(col, txt):
    return f"{col}{txt}{C.RST}"

def bold(t):  return tx(C.BOLD, t)
def dim(t):   return tx(C.DIM, t)
def italic(t):return tx(C.ITAL, t)
def red(t):   return tx(C.RED, t)
def grn(t):  return tx(C.GRN, t)
def ylw(t):  return tx(C.YLW, t)
def cyn(t):  return tx(C.CYN, t)
def blu(t):  return tx(C.BLU, t)
def mag(t):  return tx(C.MAG, t)
def org(t):  return tx(C.ORG, t)
def wht(t):  return tx(C.WHT, t)
def gry(t):  return tx(C.GRY, t)
def teal(t): return tx(C.TEAL, t)
def mint(t): return tx(C.MINT, t)
def pink(t): return tx(C.PINK, t)
def gold(t): return tx(C.GOLD, t)
def silver(t):return tx(C.SILVER, t)

def centered(text, width=60, fill=" "):
    vw = _vw(text)
    if vw >= width: return text
    total = width - vw
    left = total // 2
    right = total - left
    return fill * left + text + fill * right

# ═══════════════════════════════════════════════════════════
#  GRADIENT TEXT
# ═══════════════════════════════════════════════════════════
GRAD_CYAN_BLUE = [45, 39, 33, 38, 75, 117]
GRAD_GOLD_RED  = [220, 214, 208, 202, 196, 203]
GRAD_GREEN     = [78, 82, 46, 48, 82, 120]
GRAD_PURPLE    = [177, 171, 165, 135, 99, 93]

def gradient_text(text, palette=GRAD_CYAN_BLUE):
    result = []
    chars = _sa(text)
    ci = 0
    for ch in chars:
        idx = int(ci / max(len(chars), 1) * len(palette))
        idx = min(idx, len(palette) - 1)
        result.append(f"\033[38;5;{palette[idx]}m{ch}{C.RST}")
        ci += 1
    return "".join(result)

# ═══════════════════════════════════════════════════════════
#  PANEL / BOX RENDERING
# ═══════════════════════════════════════════════════════════
def double_box(lines, width=62, title=None, title_color=None, border_color=None):
    """Render a double-line box with optional title."""
    bc = border_color or C.TEAL
    tc = title_color or C.GOLD
    iw = width - 4
    out = []
    if title:
        tvw = _vw(title)
        t_fill = iw - tvw - 4
        if t_fill < 2: t_fill = 2
        out.append(f"{bc}{DTL}{DT}{DT}{C.RST} {tc}{bold(title)}{C.RST} {bc}{DT * t_fill}{DTR}{C.RST}")
    else:
        out.append(f"{bc}{DTL}{DT * (width - 2)}{DTR}{C.RST}")
    for ln in lines:
        vw = _vw(ln)
        pad = iw - vw
        if pad < 0: pad = 0
        out.append(f"{bc}{DV}{C.RST} {ln}{" " * pad} {bc}{DV}{C.RST}")
    out.append(f"{bc}{DBL}{DT * (width - 2)}{DBR}{C.RST}")
    return "\n".join(out)

def box(lines, width=62, title=None, title_color=None, border_color=None, rounded=False):
    """Render a single-line box."""
    bc = border_color or C.TEAL
    tc = title_color or C.WHT
    iw = width - 4
    tl, tr, bl, br = (TL, TR, BL, BR)
    out = []
    if title:
        tvw = _vw(title)
        t_fill = iw - tvw - 4
        if t_fill < 2: t_fill = 2
        out.append(f"{bc}{tl}{T}{T}{C.RST} {tc}{bold(title)}{C.RST} {bc}{T * t_fill}{tr}{C.RST}")
    else:
        out.append(f"{bc}{tl}{T * (width - 2)}{tr}{C.RST}")
    for ln in lines:
        vw = _vw(ln)
        pad = iw - vw
        if pad < 0: pad = 0
        out.append(f"{bc}{V}{C.RST} {ln}{" " * pad} {bc}{V}{C.RST}")
    out.append(f"{bc}{bl}{T * (width - 2)}{br}{C.RST}")
    return "\n".join(out)

def hr(width=62, char=T, color=None):
    """Horizontal rule."""
    col = color or C.GRY
    return f"{col}{char * width}{C.RST}"

def section_divider(title, width=62):
    """Centered section divider with decorative chars."""
    vw = _vw(title)
    if vw >= width - 6:
        return f"  {bold(title)}"
    rem = width - 4 - vw
    left = rem // 2
    right = rem - left
    parts = []
    if left > 2:
        parts.append(f"{C.DGRY}{T * (left - 1)}{C.RST}")
    parts.append(f"{cyn(bold(f" {title} "))}")
    if right > 2:
        parts.append(f"{C.DGRY}{T * (right - 1)}{C.RST}")
    return "".join(parts)

def kv_line(key, val, key_width=16, val_color=None):
    """Key-value line with aligned keys."""
    vc = val_color or wht
    pad = key_width - len(key)
    if pad < 1: pad = 1
    return f"  {cyn(key)}{dim(T * pad)}  {vc(val)}"

def icon_kv(icon, key, val, key_width=14, val_color=None):
    """Icon + key-value line."""
    vc = val_color or wht
    pad = key_width - len(key)
    if pad < 1: pad = 1
    return f"  {gold(icon)}  {cyn(key)}{dim(T * pad)}  {vc(val)}"

def status_dot(active):
    """Green/red status dot."""
    return grn(f" {STR} ") if active else red(f" {NO} ")

def progress_bar(pct, width=24, label="", show_pct=True):
    """Colored progress bar."""
    filled = int(pct / 100 * width)
    empty = width - filled
    bar = f"{C.BGGRN}{T * filled}{C.RST}{C.BGGRY}{T * empty}{C.RST}"
    pct_str = f"{pct:5.1f}%" if show_pct else ""
    lbl_str = f" {dim(label)}" if label else ""
    return f"  {bar}{lbl_str} {cyn(pct_str)}"

# ═══════════════════════════════════════════════════════════
#  SPINNER / ANIMATION
# ═══════════════════════════════════════════════════════════
SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
SPINNER_LOCK = threading.Lock()
SPINNER_RUNNING = False
SPINNER_MSG = ""

def _spin_thread():
    global SPINNER_RUNNING
    i = 0
    while SPINNER_RUNNING:
        frame = SPINNER_FRAMES[i % len(SPINNER_FRAMES)]
        sys.stdout.write(f"\r  {cyn(frame)}  {SPINNER_MSG}")
        sys.stdout.flush()
        time.sleep(0.08)
        i += 1
    sys.stdout.write(f"\r  {grn(STR)}  {SPINNER_MSG}\n")
    sys.stdout.flush()

def spinner_start(msg):
    global SPINNER_RUNNING, SPINNER_MSG
    SPINNER_MSG = msg
    SPINNER_RUNNING = True
    t = threading.Thread(target=_spin_thread, daemon=True)
    t.start()
    return t

def spinner_stop():
    global SPINNER_RUNNING
    SPINNER_RUNNING = False
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════
#  INPUT HELPERS
# ═══════════════════════════════════════════════════════════
def ask(prompt, default=""):
    if AUTO_MODE:
        return default
    if default:
        hint = dim(f"  [{default}]")
        rv = input(f"  {cyn(ARR)} {wht(prompt)} {hint}: ").strip()
        return rv if rv else default
    rv = input(f"  {cyn(ARR)} {wht(prompt)}: ").strip()
    while not rv:
        rv = input(f"  {red(CRS)} {ylw("Required")}: ").strip()
    return rv

def askyn(prompt, default=True):
    if AUTO_MODE:
        return default
    hint = dim("[Y/n]") if default else dim("[y/N]")
    rv = input(f"  {cyn(ARR)} {wht(prompt)} {hint} ").strip().lower()
    if not rv: return default
    return rv in ("y", "yes", "1", "بله")

def pause(msg="Press Enter to continue..."):
    if AUTO_MODE:
        return
    input(f"\n  {dim(T * 40)}\n  {gry(msg)}  ")

def choose(prompt, options, width=62):
    """
    options: list of (key, label, hint)
    Returns selected key or None for back/0.
    """
    if AUTO_MODE:
        # Return first option key in auto mode
        return options[0][0] if options else None
    # Calculate max label width for alignment
    max_label = max(_vw(lbl) for _, lbl, _ in options) if options else 10
    
    for key, lbl, hint_text in options:
        key_str = bold(f"[{key}]")
        label_str = wht(lbl)
        pad = max_label - _vw(lbl) + 2
        if pad < 2: pad = 2
        line = f"    {cyn(key_str)}  {label_str}{" " * pad}"
        if hint_text:
            line += dim(f"  {hint_text}")
        print(line)
    
    print(f"    {hr(width - 8, char=T * 3, color=C.DGRY)}")
    print(f"    {cyn(bold("[0]"))}  {gry("Back / Exit")}")
    print()
    rv = input(f"  {cyn(ARR)} {wht(prompt)}: ").strip()
    if rv == "0": return None
    return rv

# ═══════════════════════════════════════════════════════════
#  BANNER
# ═══════════════════════════════════════════════════════════
def banner():
    tw = _tw()
    w = min(tw, 64)
    
    # Compact text for narrow terminals
    if w < 52:
        art_lines = [
            r'  <>  N E T F O R G E  <>',
            r'  ~~  XHTTP/Netlify  ~~',
        ]
    else:
        art_lines = [
            r'  ██╗  ██╗██╗   ██╗ ██████╗ ██████╗ ███╗   ██╗',
            r'  ██║  ██║██║   ██║██╔════╝██╔═══██╗████╗  ██║',
            r'  ███████║██║   ██║██║     ██║   ██║██╔██╗ ██║',
            r'  ██╔══██║██║   ██║██║     ██║   ██║██║╚██╗██║',
            r'  ██║  ██║╚██████╔╝╚██████╗╚██████╔╝██║ ╚████║',
            r'  ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝',
        ]
    
    sub = centered(f"{silver(STR)} {italic('XHTTP/Netlify Relay Manager')} {silver(STR)}", w - 4)
    ver = centered(dim(f"v2.0  |  by NetForge  |  Stealth Networking Tools"), w - 4)
    
    max_art = max(len(l) for l in art_lines)
    indent = (w - max_art - 4) // 2
    if indent < 0: indent = 0
    
    art_out = []
    for line in art_lines:
        art_out.append(" " * indent + gradient_text(line, GRAD_CYAN_BLUE))
    
    # Separator
    sep_len = max(w - 12, 10)
    sep = centered(f"{C.DGRY}{'─' * sep_len}{C.RST}", w)
    
    # Build final banner
    out_lines = ["", ""]
    out_lines.extend(art_out)
    out_lines.append("")
    out_lines.append(sub)
    out_lines.append(ver)
    out_lines.append(sep)
    
    return "\n".join(out_lines)

# ═══════════════════════════════════════════════════════════
#  STATUS DASHBOARD
# ═══════════════════════════════════════════════════════════
SDIR = os.path.expanduser("~/.vless-netlify")
SFILE = os.path.join(SDIR, "config.json")
# Xray binary search order
XRAY_SEARCH_PATHS = ["/usr/local/bin/xray", "/usr/local/xray/xray", "/usr/bin/xray"]

def find_xray_bin():
    for p in XRAY_SEARCH_PATHS:
        if os.path.isfile(p):
            try:
                subprocess.run([p, "version"], capture_output=True, timeout=5)
                return p
            except: pass
    return None

def get_xray_paths(xbin):
    """Return (bin_path, cfg_dir, cfg_file) based on where xray binary is."""
    if xbin and "/usr/local/xray/" in xbin:
        return xbin, "/usr/local/xray", "/usr/local/xray/config.json"
    return "/usr/local/bin/xray", "/usr/local/etc/xray", "/usr/local/etc/xray/config.json"

# Defaults (will be updated after detection)
XBIN = "/usr/local/bin/xray"
XCFG_DIR = "/usr/local/etc/xray"
XCFG = os.path.join(XCFG_DIR, "config.json")
XDIR = XCFG_DIR  # legacy compat

def rhex(n): return ''.join(random.choices('0123456789abcdef', k=n))
def guuid(): return f"{rhex(8)}-{rhex(4)}-4{rhex(3)}-{rhex(1)}{rhex(3)}-{rhex(12)}"

def get_ip():
    for u in ["https://api.ipify.org?format=text", "https://ifconfig.me/ip"]:
        try: return urllib.request.urlopen(u, timeout=5).read().decode().strip()
        except: pass
    try:
        for ip in subprocess.run(["hostname", "-I"], capture_output=True, text=True, timeout=5).stdout.strip().split():
            if not ip.startswith("127.") and ":" not in ip: return ip
    except: pass
    return "0.0.0.0"

def load_st():
    dd = {
        "uuid": "", "sni": "", "alt_sni": "",
        "xray_port": 444, "server_ip": "", "netlify_token": "",
        "deployments": [], "xray_installed": False, "xray_version": "",
        "site_name": "", "site_id": "", "site_url": ""
    }
    if os.path.isfile(SFILE):
        try:
            with open(SFILE) as f: saved = json.load(f)
            dd.update(saved)
        except: pass
    if not dd["uuid"]: dd["uuid"] = guuid()
    if not dd["server_ip"]: dd["server_ip"] = get_ip()
    save_st(dd)
    return dd

def save_st(dd):
    os.makedirs(SDIR, exist_ok=True)
    with open(SFILE, "w") as f: json.dump(dd, f, indent=2, ensure_ascii=False)

def show_status(st):
    tw = _tw()
    w = min(max(tw, 48), 66)
    lines = [
        f"{gold(DIA)}  {cyn('Server IP')}      {wht(st.get('server_ip', 'N/A'))}",
        f"{gold(DIA)}  {cyn('Xray Status')}    {status_dot(st.get('xray_installed', False))} {wht(st.get('xray_version', 'Not installed'))}",
        f"{gold(DIA)}  {cyn('Xray Port')}      {wht(str(st.get('xray_port', 444)))}",
        f"{gold(DIA)}  {cyn('UUID')}           {dim(st.get('uuid', '')[:16])}...",
        f"{gold(DIA)}  {cyn('Netlify Token')}  {mint('SET') if st.get('netlify_token') else red('NOT SET')}",
        f"{gold(DIA)}  {cyn('Site URL')}       {wht(st.get('site_url', 'No deployment')) if st.get('site_url') else dim('No deployment')}",
        f"{gold(DIA)}  {cyn('Deployments')}    {wht(str(len(st.get('deployments', []))))}",
    ]
    
    # Header
    header = f"{teal(bold('  SYSTEM STATUS'))}" + centered(f"{dim(time.strftime('%H:%M:%S  |  %Y-%m-%d'))}", w - 18)
    
    print(f"\n  {header}")
    print()
    print(double_box(lines, w, title="Overview", title_color=C.GOLD, border_color=C.TEAL))

# ═══════════════════════════════════════════════════════════
#  XRAY INSTALLATION
# ═══════════════════════════════════════════════════════════
def _detect_xray():
    """Detect existing Xray installation. Returns (bin_path, version_str) or (None, None)."""
    for p in XRAY_SEARCH_PATHS:
        if os.path.isfile(p):
            try:
                r = subprocess.run([p, "version"], capture_output=True, text=True, timeout=10)
                if r.returncode == 0:
                    ver = r.stdout.strip().split("\n")[0] if r.stdout else "unknown"
                    return p, ver
            except: pass
    return None, None

def install_xray(st):
    global XBIN, XCFG_DIR, XCFG, XDIR
    print(f"\n  {section_divider('XRAY INSTALLATION')}\n")
    
    # Detect existing Xray
    xbin, xver = _detect_xray()
    
    if xbin and st.get('xray_installed'):
        if not askyn("Xray is already installed. Reinstall?", False):
            if AUTO_MODE:
                print(f"  {grn(CHK)}  {grn(f'Xray found at {xbin}, skipping install.')}")
            else:
                print(f"  {gry('Cancelled.')}")
                pause()
            # Update global paths to match detected location
            XBIN, XCFG_DIR, XCFG = get_xray_paths(xbin)
            XDIR = XCFG_DIR
            return st
    
    print(f"  {cyn(DOT)}  {wht('Installing Xray using official install script...')}")
    
    try:
        # Stop any existing xray service first
        subprocess.run(["systemctl", "stop", "xray"], capture_output=True, timeout=10)
        subprocess.run(["systemctl", "disable", "xray"], capture_output=True, timeout=10)
        
        # Use official Xray install script - it handles binary, config dir, and systemd
        sp = spinner_start("Installing Xray...")
        result = subprocess.run(
            ["bash", "-c", "bash <(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install 2>&1"],
            capture_output=True, text=True, timeout=180
        )
        spinner_stop()
        
        if result.returncode != 0:
            print(f"  {dim(result.stdout[-300:] if result.stdout else '')}")
            print(f"  {dim(result.stderr[-200:] if result.stderr else '')}")
            # Fallback: check if xray binary exists anyway
            xbin2, _ = _detect_xray()
            if not xbin2:
                print(f"  {red(CRS)}  {red('Official install failed and no Xray binary found.')}")
                pause()
                return st
            print(f"  {ylw(chr(0x26a0))}  {ylw('Install script had errors but Xray binary found.')}")
        
        # Detect where Xray was installed
        xbin, xver = _detect_xray()
        if not xbin:
            print(f"  {red(CRS)}  {red('Xray binary not found after install.')}")
            pause()
            return st
        
        # Update global paths
        XBIN, XCFG_DIR, XCFG = get_xray_paths(xbin)
        XDIR = XCFG_DIR
        
        # Ensure config directory exists
        os.makedirs(XCFG_DIR, exist_ok=True)
        
        # Create our own systemd service (overwrite any existing)
        svc = f"""[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
ExecStart={XBIN} run -config {XCFG}
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
"""
        with open("/etc/systemd/system/xray.service", "w") as f:
            f.write(svc)
        
        # Remove any leftover drop-in overrides from official script
        dropin = "/etc/systemd/system/xray.service.d"
        if os.path.isdir(dropin):
            shutil.rmtree(dropin)
        
        subprocess.run(["systemctl", "daemon-reload"], capture_output=True, timeout=10)
        subprocess.run(["systemctl", "enable", "xray"], capture_output=True, timeout=10)
        
        st["xray_installed"] = True
        st["xray_version"] = xver
        save_st(st)
        
        print(f"  {grn(CHK)}  {grn('Xray installed successfully!')}")
        print(f"  {gry(f'  Binary: {XBIN}')}")
        print(f"  {gry(f'  Config: {XCFG}')}")
        print(f"  {gry(f'  Version: {xver}')}")
        
    except Exception as e:
        print(f"  {red(CRS)}  {red(f'Install failed: {e}')}")
    
    pause()
    return st

# ═══════════════════════════════════════════════════════════
#  XRAY CONFIG GENERATION
# ═══════════════════════════════════════════════════════════
RELAY_TPL = r'''const SP="__SECPATH__";
const FAKE_HTML = `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DevPulse</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:#0a0e1a;color:#c8d6e5;display:flex;justify-content:center;align-items:center;height:100vh}h1{background:linear-gradient(90deg,#00d4ff,#7c3aed);-webkit-background-clip:text;-webkit-text-fill-color:transparent;font-size:2rem}</style></head><body><h1>DevPulse Analytics</h1></body></html>`;

export default async (request, context) => {
  const url = new URL(request.url);
  const path = url.pathname;

  if (path === "/" || path === "/index.html") {
    return new Response(FAKE_HTML, {headers: {"content-type": "text/html; charset=utf-8"}});
  }

  if (path === SP || path.startsWith(SP + "/")) {
    const origin = "__ORIGIN__";
    const headers = new Headers(request.headers);
    const clientIP = request.headers.get("x-nf-client-connection-ip") || "";
    headers.set("x-forwarded-for", clientIP);
    headers.set("x-real-ip", clientIP);

    const opts = {method: request.method, headers};
    if (!["GET", "HEAD"].includes(request.method)) {
      opts.body = request.body;
    }

    try {
      const resp = await fetch(origin + path + url.search, opts);
      const rh = new Headers(resp.headers);
      rh.delete("content-encoding");
      return new Response(resp.body, {status: resp.status, headers: rh});
    } catch(e) {
      return new Response("relay error: " + e.message, {status: 502});
    }
  }

  return new Response("Not Found", {status: 404});
};
'''

TOML_CFG = r"""[build]
  publish = "public"

[[edge_functions]]
  function = "relay"
  path = "__SECPATH__"

[[edge_functions]]
  function = "relay"
  path = "__SECPATH__/*"

[[edge_functions]]
  function = "relay"
  path = "/"
"""

FAKE_HTML_FILE = r"""<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DevPulse - Developer Analytics</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0e1a;color:#c8d6e5;line-height:1.6}header{background:linear-gradient(135deg,#0f1729,#1a1f35);padding:2rem;text-align:center;border-bottom:1px solid #1e2d4a}.logo{font-size:2rem;font-weight:700;background:linear-gradient(90deg,#00d4ff,#7c3aed);-webkit-background-clip:text;-webkit-text-fill-color:transparent}nav{display:flex;justify-content:center;gap:2rem;padding:1rem;background:#0d1220}nav a{color:#8892b0;text-decoration:none;font-size:.9rem}nav a:hover{color:#00d4ff}.hero{padding:4rem 2rem;text-align:center;max-width:800px;margin:0 auto}.hero h2{font-size:2.5rem;margin-bottom:1rem;color:#e6f1ff}.hero p{color:#8892b0;font-size:1.1rem;max-width:600px;margin:0 auto 2rem}.features{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:2rem;padding:3rem 2rem;max-width:1000px;margin:0 auto}.feature{background:#111827;border:1px solid #1e2d4a;border-radius:8px;padding:1.5rem;transition:transform .2s}.feature:hover{transform:translateY(-2px)}.feature h3{color:#00d4ff;margin-bottom:.5rem}.feature p{color:#8892b0;font-size:.9rem}footer{text-align:center;padding:2rem;color:#4a5568;font-size:.8rem;border-top:1px solid #1e2d4a}</style></head><body><header><div class="logo">DevPulse</div><p style="color:#64ffda;margin-top:.5rem">Real-time developer analytics platform</p></header><nav><a href="#">Dashboard</a><a href="#">Analytics</a><a href="#">Monitoring</a><a href="#">Docs</a></nav><section class="hero"><h2>Monitor. Analyze. Optimize.</h2><p>Powerful developer analytics and monitoring for modern applications. Track performance metrics in real-time.</p><button style="background:linear-gradient(135deg,#00d4ff,#7c3aed);color:#fff;border:none;padding:.75rem 2rem;border-radius:6px;font-size:1rem;cursor:pointer">Get Started Free</button></section><section class="features"><div class="feature"><h3>Real-time Metrics</h3><p>Monitor application performance with sub-second granularity and custom dashboards.</p></div><div class="feature"><h3>Error Tracking</h3><p>Capture and analyze errors with full stack traces and contextual information.</p></div><div class="feature"><h3>API Analytics</h3><p>Track API response times, throughput, and error rates across all endpoints.</p></div></section><footer>DevPulse Analytics Platform &copy; 2025</footer></body></html>"""

def gen_xray_cfg(st):
    global XBIN, XCFG_DIR, XCFG, XDIR
    # Re-detect xray location in case it was installed after script load
    xbin, _ = _detect_xray()
    if xbin:
        XBIN, XCFG_DIR, XCFG = get_xray_paths(xbin)
        XDIR = XCFG_DIR
    
    ip = st["server_ip"] or "0.0.0.0"
    port = st.get("xray_port", 444)
    uuid = st["uuid"]
    secp = st.get("secp", "/nf-" + rhex(8))
    st["secp"] = secp
    
    # Check if real TLS certs exist (check both possible locations)
    has_certs = False
    for cert_dir in [XCFG_DIR, "/usr/local/xray", "/etc/ssl/xray"]:
        if os.path.isfile(f"{cert_dir}/cert.pem") and os.path.isfile(f"{cert_dir}/key.pem"):
            has_certs = True
            break
    
    stream = {
        "network": "xhttp",
        "security": "tls" if has_certs else "none",
        "xhttpSettings": {
            "path": secp + "/",
            "mode": "auto",
            "extra": {
                "xPaddingBytes": "1-1",
                "xPaddingObfsMode": True,
                "xPaddingKey": "iran",
                "xPaddingHeader": "iran",
                "scMaxEachPostBytes": "1000000"
            }
        }
    }
    
    if has_certs:
        stream["tlsSettings"] = {
            "certificates": [{
                "certificateFile": f"{XDIR}/cert.pem",
                "keyFile": f"{XDIR}/key.pem"
            }],
            "minVersion": "1.3",
            "alpn": ["h2", "http/1.1"],
            "fingerprint": "chrome"
        }
    
    cfg = {
        "log": {"loglevel": "warning"},
        "stats": {},
        "api": {"tag": "api", "services": ["StatsService"]},
        "policy": {"levels": {"0": {"statsUserUplink": True, "statsUserDownlink": True}}},
        "inbounds": [{
            "tag": "vless-xhttp",
            "port": port,
            "listen": "0.0.0.0",
            "protocol": "vless",
            "settings": {
                "clients": [{"id": uuid, "flow": ""}],
                "decryption": "none",
                "fallbacks": []
            },
            "streamSettings": stream,
            "sniffing": {"enabled": True, "destOverride": ["http", "tls"]}
        }],
        "outbounds": [{
            "tag": "direct",
            "protocol": "freedom",
            "settings": {}
        }, {
            "tag": "block",
            "protocol": "blackhole",
            "settings": {"response": {"type": "http"}}
        }]
    }
    
    cfg_path = XCFG
    os.makedirs(XDIR, exist_ok=True)
    with open(cfg_path, "w") as f:
        json.dump(cfg, f, indent=2)
    
    st["tls_enabled"] = has_certs
    return cfg_path

def configure(st):
    print(f"\n  {section_divider('CONFIGURATION')}\n")
    
    print(f"  {teal(bold('Current Settings:'))}\n")
    print(f"  {icon_kv(SQR, 'Server IP', st.get('server_ip', 'Auto'))}")
    print(f"  {icon_kv(SQR, 'Xray Port', str(st.get('xray_port', 444)))}")
    print(f"  {icon_kv(SQR, 'UUID', st.get('uuid', '')[:20] + '...')}")
    print(f"  {icon_kv(SQR, 'Secret Path', st.get('secp', 'auto-gen'))}")
    if st.get('site_url'):
        print(f"  {icon_kv(SQR, 'Site URL', st.get('site_url', ''))}")
        print(f"  {icon_kv(SQR, 'SNI (auto)', st.get('site_url', '').replace('https://', '').replace('http://', ''))}")
    print()
    
    if not askyn("Change settings?", True):
        pause()
        return st
    
    print()
    ip = ask("Server IP", st.get('server_ip', '') or 'auto')
    if ip == 'auto': ip = get_ip()
    st['server_ip'] = ip
    
    port = ask("Xray Port", str(st.get('xray_port', 444)))
    st['xray_port'] = int(port)
    
    if askyn("Generate new UUID?", False):
        st['uuid'] = guuid()
        print(f"  {grn(STR)}  {grn('New UUID:')} {wht(st['uuid'])}")
    
    uuid_input = ask("UUID (Enter to keep current)", "")
    if uuid_input:
        st['uuid'] = uuid_input
    
    st['secp'] = ask("Secret Path", st.get('secp', '/nf-' + rhex(8)))
    
    save_st(st)
    print(f"\n  {grn(CHK)}  {grn('Configuration saved!')}")
    pause()
    return st

# ═══════════════════════════════════════════════════════════
#  NETLIFY TOKEN
# ═══════════════════════════════════════════════════════════
def set_token(st):
    print(f"\n  {section_divider('NETLIFY TOKEN')}\n")
    
    cur = st.get('netlify_token', '')
    if cur:
        masked = cur[:8] + "..." + cur[-4:]
        print(f"  {icon_kv(SQR, 'Current Token', masked)}")
    else:
        print(f"  {icon_kv(SQR, 'Current Token', red('NOT SET'))}")
    
    print(f"\n  {dim('Get your token from:')} {cyn('https://app.netlify.com/user/applications#personal-access-tokens')}")
    print(f"  {dim('Required scopes:')} {wht('Sites: Read & Write')}")
    print()
    
    token = ask("Netlify Personal Access Token", "")
    if token and len(token) > 10:
        st['netlify_token'] = token.strip()
        save_st(st)
        print(f"  {grn(CHK)}  {grn('Token saved successfully!')}")
    else:
        print(f"  {red(CRS)}  {red('Invalid token.')}")
    
    pause()
    return st

# ═══════════════════════════════════════════════════════════
#  NETLIFY DEPLOY
# ═══════════════════════════════════════════════════════════
def deploy_netlify(st):
    print(f"\n  {section_divider('NETLIFY DEPLOYMENT')}\n")
    
    token = st.get('netlify_token', '')
    if not token:
        print(f"  {red(CRS)}  {red('Netlify token not set!')}")
        print(f"  {dim('Please set your token first from the main menu.')}")
        pause()
        return st
    
    ip = st.get('server_ip', '')
    if not ip or ip == '0.0.0.0':
        ip = get_ip()
        st['server_ip'] = ip
    
    secp = st.get('secp', '/nf-' + rhex(8))
    if not secp.startswith('/'):
        secp = '/' + secp
    st['secp'] = secp
    port = st.get('xray_port', 444)
    
    origin = f"http://{ip}:{port}"
    
    print(f"  {cyn(DOT)}  {wht('Preparing deployment files...')}")
    
    relay_js = RELAY_TPL.replace("__SECPATH__", secp).replace("__ORIGIN__", origin)
    toml_content = TOML_CFG.replace("__SECPATH__", secp)
    
    site_name = f"nf-{rhex(8)}"
    st['site_name'] = site_name
    
    print(f"  {icon_kv(SQR, 'Site Name', site_name)}")
    print(f"  {icon_kv(SQR, 'Origin', origin)}")
    print(f"  {icon_kv(SQR, 'Secret Path', secp + '/')}")
    print()
    
    if not askyn("Proceed with deployment?", True):
        print(f"  {gry('Cancelled.')}")
        pause()
        return st
    
    auth_header = {"Authorization": f"Bearer {token}"}
    
    # Create Netlify site with SSO disabled
    print(f"  {cyn(DOT)}  {wht('Creating Netlify site (SSO disabled)...')}")
    sp = spinner_start("Creating site...")
    try:
        req = urllib.request.Request(
            "https://api.netlify.com/api/v1/sites",
            data=json.dumps({"name": site_name, "sso_login": False}).encode(),
            headers={**auth_header, "Content-Type": "application/json"}
        )
        resp = json.loads(urllib.request.urlopen(req, timeout=30).read())
        site_id = resp["id"]
        site_url = resp["ssl_url"] or resp["url"]
        st['site_id'] = site_id
        st['site_url'] = site_url
    except Exception as e:
        spinner_stop()
        print(f"  {red(CRS)}  {red(f'Site creation failed: {e}')}")
        pause()
        return st
    spinner_stop()
    print(f"  {grn(STR)}  {grn('Site created:')} {wht(site_url)}")
    
    # Write deploy files to temp dir
    work_dir = f"/tmp/netforge-deploy-{site_name}"
    if os.path.exists(work_dir):
        shutil.rmtree(work_dir)
    os.makedirs(f"{work_dir}/netlify/edge-functions", exist_ok=True)
    os.makedirs(f"{work_dir}/public", exist_ok=True)
    
    with open(f"{work_dir}/netlify/edge-functions/relay.js", "w") as f:
        f.write(relay_js)
    with open(f"{work_dir}/netlify.toml", "w") as f:
        f.write(toml_content)
    with open(f"{work_dir}/public/index.html", "w") as f:
        f.write(FAKE_HTML_FILE)
    
    # Ensure Netlify CLI is available
    netlify_cli = shutil.which("netlify")
    if not netlify_cli:
        print(f"  {ylw(chr(0x26a0))}  {ylw('Netlify CLI not found. Installing...')}")
        # Ensure Node.js is available
        if not shutil.which("node"):
            print(f"  {cyn(DOT)}  {wht('Installing Node.js...')}")
            subprocess.run(["bash", "-c", "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs"],
                           capture_output=True, timeout=180)
        if not shutil.which("npm"):
            print(f"  {red(CRS)}  {red('npm not available. Install Node.js first.')}")
            pause()
            return st
        # Add swap if memory is low (< 1.5GB free)
        try:
            mem_out = subprocess.run(["free", "-m"], capture_output=True, text=True, timeout=5).stdout
            for line in mem_out.split("\n"):
                if "Mem:" in line:
                    parts = line.split()
                    free_mb = int(parts[6]) if len(parts) > 6 else 9999
                    if free_mb < 1500:
                        print(f"  {cyn(DOT)}  {wht('Adding swap space for npm...')}")
                        subprocess.run(["bash", "-c", "fallocate -l 1G /swapfile 2>/dev/null && chmod 600 /swapfile && mkswap /swapfile >/dev/null 2>&1 && swapon /swapfile"],
                                       capture_output=True, timeout=30)
                        break
        except: pass
        print(f"  {cyn(DOT)}  {wht('Installing netlify-cli (this may take a few minutes)...')}")
        sp = spinner_start("Installing netlify-cli...")
        result = subprocess.run(["npm", "install", "-g", "netlify-cli@17.36.4", "--no-audit", "--no-fund"],
                       capture_output=True, text=True, timeout=300)
        spinner_stop()
        if result.returncode != 0:
            print(f"  {dim(result.stdout[-300:] if result.stdout else '')}")
            print(f"  {dim(result.stderr[-200:] if result.stderr else '')}")
        if not shutil.which("netlify"):
            print(f"  {red(CRS)}  {red('Netlify CLI install failed.')}")
            pause()
            return st
        print(f"  {grn(STR)}  {grn('Netlify CLI installed!')}")

    print(f"  {cyn(DOT)}  {wht('Deploying via Netlify CLI...')}")
    sp = spinner_start("Deploying (bundling edge functions)...")
    try:
        env = os.environ.copy()
        env["NETLIFY_AUTH_TOKEN"] = token
        # Must cd into work_dir so netlify.toml is found for edge function bundling
        result = subprocess.run(
            ["netlify", "deploy", "--prod", "--dir=.", f"--site={site_id}"],
            capture_output=True, text=True, timeout=300, env=env,
            cwd=work_dir
        )
        if result.returncode != 0:
            spinner_stop()
            print(f"  {red(CRS)}  {red('Deploy failed!')}")
            out = result.stdout[-500:] if len(result.stdout) > 500 else result.stdout
            print(f"  {dim(out)}")
            if result.stderr:
                err = result.stderr[-500:] if len(result.stderr) > 500 else result.stderr
                print(f"  {dim(err)}")
            save_st(st)
            pause()
            return st
        
        # Extract URL from output
        output = result.stdout
        url_match = re.search(r'Production URL: <(https://[^>]+)>', output)
        if url_match:
            deployed_url = url_match.group(1)
        else:
            deployed_url = site_url
        
        if 'Edge Functions bundling' in output and 'completed' in output:
            print(f"  {grn(STR)}  {grn('Edge functions bundled successfully!')}")
    except Exception as e:
        spinner_stop()
        print(f"  {red(CRS)}  {red(f'Deploy error: {e}')}")
        save_st(st)
        pause()
        return st
    
    spinner_stop()
    
    # Disable SSO again
    try:
        patch = urllib.request.Request(
            f"https://api.netlify.com/api/v1/sites/{site_id}",
            data=json.dumps({"sso_login": False}).encode(),
            headers={**auth_header, "Content-Type": "application/json"},
            method="PATCH"
        )
        urllib.request.urlopen(patch, timeout=10)
    except: pass
    
    # Save deployment info
    dep = {
        "site_name": site_name,
        "site_id": site_id,
        "site_url": deployed_url,
        "time": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    deps = st.get('deployments', [])
    deps.append(dep)
    st['deployments'] = deps
    st['site_url'] = deployed_url
    save_st(st)
    
    # Quick test
    print(f"  {cyn(DOT)}  {wht('Testing edge function...')}")
    try:
        test_req = urllib.request.Request(f"{deployed_url}/")
        test_resp = urllib.request.urlopen(test_req, timeout=15)
        test_code = test_resp.status
        test_body = test_resp.read().decode()[:500]
        if test_code == 200 and 'DevPulse' in test_body:
            print(f"  {grn(CHK)}  {grn('Edge function is LIVE!')}")
        elif test_code == 401:
            print(f"  {ylw(chr(0x26a0))}  {ylw('SSO blocking - disabling...')}")
            # Retry SSO disable with more fields
            try:
                patch = urllib.request.Request(
                    f"https://api.netlify.com/api/v1/sites/{site_id}",
                    data=json.dumps({"sso_login": False, "force_sso": False}).encode(),
                    headers={**auth_header, "Content-Type": "application/json"},
                    method="PATCH"
                )
                urllib.request.urlopen(patch, timeout=10)
                time.sleep(3)
                # Retry test
                test_req2 = urllib.request.Request(f"{deployed_url}/")
                test_resp2 = urllib.request.urlopen(test_req2, timeout=15)
                if test_resp2.status == 200:
                    print(f"  {grn(CHK)}  {grn('SSO disabled, site is LIVE!')}")
            except: pass
        else:
            print(f"  {ylw(chr(0x26a0))}  {ylw(f'Test returned HTTP {test_code}')}")
    except Exception as e:
        print(f"  {ylw(chr(0x26a0))}  {ylw(f'Test failed: {e}')}")
    
    print(f"  {grn(CHK)}  {grn('Deployment successful!')}")
    print(f"  {icon_kv(SQR, 'Site URL', deployed_url, val_color=mint)}")
    print(f"  {icon_kv(SQR, 'SecPath', secp + '/')}")
    pause()
    return st

# ═══════════════════════════════════════════════════════════
#  VLESS LINK GENERATION
# ═══════════════════════════════════════════════════════════
def gen_vless(st):
    print(f"\n  {section_divider('VLESS LINK GENERATOR')}\n")
    
    if not st.get('site_url'):
        print(f"  {red(CRS)}  {red('No deployment found. Deploy first!')}")
        pause()
        return
    
    uuid = st['uuid']
    secp = st.get('secp', '')
    site = st['site_url']
    # Strip protocol from site URL for host parameter
    site_host = site.replace('https://', '').replace('http://', '').rstrip('/')
    # SNI must ALWAYS be the Netlify hostname for relay to work
    sni = site_host
    ip = st.get('server_ip', '')
    port = st.get('xray_port', 444)
    
    # Build extra JSON with all xPadding settings + x-host header
    extra_obj = {
        "xPaddingBytes": "1-1",
        "xPaddingObfsMode": True,
        "scMaxEachPostBytes": "1000000",
        "xPaddingKey": "iran",
        "xPaddingHeader": "iran",
        "headers": {
            "x-host": f"{ip}:{port}"
        }
    }
    extra_encoded = urllib.parse.quote(json.dumps(extra_obj, separators=(',', ':')))
    
    # Address = site's own domain, SNI = same
    link = (
        f"vless://{uuid}@{site_host}:443?"
        f"type=xhttp&security=tls&sni={site_host}"
        f"&path={urllib.parse.quote(secp + '/')}&mode=auto"
        f"&alpn=h2%2Chttp%2F1.1&encryption=none"
        f"&fp=chrome&insecure=0&allowInsecure=0"
        f"&host={site_host}"
        f"&extra={extra_encoded}"
        f"#NetForge"
    )
    
    # Short version for QR
    link_short = (
        f"vless://{uuid}@{site_host}:443?"
        f"type=xhttp&security=tls&sni={site_host}"
        f"&path={urllib.parse.quote(secp + '/')}&mode=auto"
        f"&host={site_host}"
        f"&extra={extra_encoded}"
        f"#NetForge"
    )
    
    lines = [
        f"{gold(DIA)}  {cyn('Address')}       {mint(site_host)}",
        f"{gold(DIA)}  {cyn('Host')}          {wht(site)}",
        f"{gold(DIA)}  {cyn('Port')}          {wht('443')}",
        f"{gold(DIA)}  {cyn('UUID')}          {dim(uuid[:18])}...",
        f"{gold(DIA)}  {cyn('Network')}       {wht('xhttp')}",
        f"{gold(DIA)}  {cyn('Security')}      {wht('tls')}",
        f"{gold(DIA)}  {cyn('SNI')}           {wht(site_host)}",
        f"{gold(DIA)}  {cyn('Path')}          {wht(secp + '/')}",
        f"{gold(DIA)}  {cyn('Mode')}          {wht('auto')}",
        f"{gold(DIA)}  {cyn('xPadding')}      {grn('enabled')}",
        f"{gold(DIA)}  {cyn('x-host')}        {dim(f'{ip}:{port}')}",
    ]
    
    print(double_box(lines, 64, title="Connection Details", title_color=C.GOLD, border_color=C.TEAL))
    
    # Show links
    print(f"\n  {teal(bold('Full VLESS Link:'))}")
    print(f"  {dim(T * 58)}")
    for i, chunk in enumerate(textwrap.wrap(link, 76)):
        print(f"  {mint(chunk)}")
    
    print(f"\n  {teal(bold('QR-Friendly Link:'))}")
    print(f"  {dim(T * 58)}")
    for i, chunk in enumerate(textwrap.wrap(link_short, 76)):
        print(f"  {silver(chunk)}")
    
    # In auto mode, print raw link for easy copying
    if AUTO_MODE:
        print(f"\n{link}")
        st['last_link'] = link
        save_st(st)
    
    pause()

# ═══════════════════════════════════════════════════════════
#  DEPLOYMENT MANAGEMENT
# ═══════════════════════════════════════════════════════════
def manage_deps(st):
    print(f"\n  {section_divider('DEPLOYMENT MANAGEMENT')}\n")
    
    deps = st.get('deployments', [])
    if not deps:
        print(f"  {gry('No deployments yet.')}")
        pause()
        return st
    
    for i, dep in enumerate(deps, 1):
        lines = [
            f"  {teal(f'#{i}')}  {wht(dep.get('site_name', '?'))}",
            f"  {gry(f'     URL: {dep.get("site_url", "?")}')}",
            f"  {gry(f'     Deployed: {dep.get("time", "?")}')}",
        ]
        print(f"\n  {box(lines, 58, title=f"Deployment #{i}", title_color=C.TEAL, border_color=C.TEAL)}")
    
    print()
    print(f"  Total: {bold(str(len(deps)))} deployment(s)")
    
    rv = choose("Action", [
        ("1", "Delete latest deployment", "Remove most recent"),
        ("2", "Clear all deployments", "Remove all records"),
        ("3", "Delete from Netlify", "Remove site from Netlify"),
    ])
    
    token = st.get('netlify_token', '')
    
    if rv == "1" and deps:
        removed = deps.pop()
        if token and removed.get('site_id'):
            try:
                req = urllib.request.Request(
                    f"https://api.netlify.com/api/v1/sites/{removed['site_id']}",
                    headers={"Authorization": f"Bearer {token}"}
                )
                req.get_method = lambda: 'DELETE'
                urllib.request.urlopen(req, timeout=15)
                print(f"  {grn(CHK)}  {grn(f"Site {removed['site_name']} deleted from Netlify.")}")
            except: pass
        save_st(st)
        print(f"  {grn(CHK)}  {grn('Latest deployment removed.')}")
    
    elif rv == "2":
        if token:
            for dep in deps:
                if dep.get('site_id'):
                    try:
                        req = urllib.request.Request(
                            f"https://api.netlify.com/api/v1/sites/{dep['site_id']}",
                            headers={"Authorization": f"Bearer {token}"}
                        )
                        req.get_method = lambda: 'DELETE'
                        urllib.request.urlopen(req, timeout=15)
                    except: pass
        st['deployments'] = []
        st['site_name'] = ''
        st['site_id'] = ''
        st['site_url'] = ''
        save_st(st)
        print(f"  {grn(CHK)}  {grn('All deployments cleared.')}")
    
    elif rv == "3" and deps:
        idx = input(f"  {cyn(ARR)} {wht('Deployment # to delete')}: ").strip()
        try:
            idx = int(idx) - 1
            if 0 <= idx < len(deps) and token:
                dep = deps[idx]
                req = urllib.request.Request(
                    f"https://api.netlify.com/api/v1/sites/{dep['site_id']}",
                    headers={"Authorization": f"Bearer {token}"}
                )
                req.get_method = lambda: 'DELETE'
                urllib.request.urlopen(req, timeout=15)
                deps.pop(idx)
                save_st(st)
                print(f"  {grn(CHK)}  {grn('Site deleted from Netlify.')}")
        except: print(f"  {red(CRS)}  {red('Invalid selection.')}")
    
    pause()
    return st

# ═══════════════════════════════════════════════════════════
#  XRAY SERVICE CONTROL
# ═══════════════════════════════════════════════════════════
def xray_menu(st):
    print(f"\n  {section_divider('XRAY SERVICE')}\n")
    
    xbin_detected = _detect_xray()[0]
    installed = xbin_detected is not None
    
    try:
        status = subprocess.run(["systemctl", "is-active", "xray"], capture_output=True, text=True, timeout=5).stdout.strip()
    except: status = "unknown"
    
    print(f"  {icon_kv(SQR, 'Installed', grn('Yes') if installed else red('No'))}")
    print(f"  {icon_kv(SQR, 'Service', grn(status) if status == 'active' else ylw(status))}")
    print(f"  {icon_kv(SQR, 'Version', st.get('xray_version', 'N/A'))}")
    print()
    
    rv = choose("Action", [
        ("1", "Generate Xray Config", "Create/update config.json"),
        ("2", "Start Xray", "systemctl start xray"),
        ("3", "Stop Xray", "systemctl stop xray"),
        ("4", "Restart Xray", "systemctl restart xray"),
        ("5", "View Xray Logs", "journalctl -u xray"),
    ])
    
    if rv == "1":
        cfg = gen_xray_cfg(st)
        save_st(st)
        print(f"  {grn(CHK)}  {grn(f'Config generated: {cfg}')}")
        
        # Check for TLS certs
        cert_path = f"{XDIR}/cert.pem"
        key_path = f"{XDIR}/key.pem"
        if not os.path.isfile(cert_path) or not os.path.isfile(key_path):
            print(f"\n  {ylw('⚠')}  {ylw('TLS certificates not found at:')}")
            print(f"    {dim(f'{cert_path}')}")
            print(f"    {dim(f'{key_path}')}")
            print(f"  {dim('Place your certificate files before starting Xray.')}")
    
    elif rv == "2":
        if not installed:
            print(f"  {red(CRS)}  {red('Xray not installed. Install first.')}")
        else:
            subprocess.run(["systemctl", "start", "xray"], timeout=10)
            print(f"  {grn(CHK)}  {grn('Xray started.')}")
    
    elif rv == "3":
        subprocess.run(["systemctl", "stop", "xray"], timeout=10)
        print(f"  {grn(CHK)}  {grn('Xray stopped.')}")
    
    elif rv == "4":
        if not installed:
            print(f"  {red(CRS)}  {red('Xray not installed.')}")
        else:
            subprocess.run(["systemctl", "restart", "xray"], timeout=10)
            print(f"  {grn(CHK)}  {grn('Xray restarted.')}")
    
    elif rv == "5":
        try:
            result = subprocess.run(["journalctl", "-u", "xray", "--no-pager", "-n", "30"], capture_output=True, text=True, timeout=10)
            print(f"\n  {teal(bold('Recent Xray Logs:'))}")
            print(f"  {hr(58)}")
            for line in result.stdout.strip().split("\n")[-20:]:
                print(f"  {gry(line)}")
        except Exception as e:
            print(f"  {red(CRS)}  {red(f'Failed: {e}')}")
    
    pause()
    return st

# ═══════════════════════════════════════════════════════════
#  FULL CONFIG VIEW
# ═══════════════════════════════════════════════════════════
def show_config(st):
    print(f"\n  {section_divider('FULL CONFIGURATION')}\n")
    
    lines = [
        f"{gold(DIA)}  {cyn('UUID')}            {wht(st.get('uuid', ''))}",
        f"{gold(DIA)}  {cyn('Server IP')}       {wht(st.get('server_ip', ''))}",
        f"{gold(DIA)}  {cyn('Xray Port')}       {wht(str(st.get('xray_port', 444)))}",
        f"{gold(DIA)}  {cyn('Secret Path')}     {wht(st.get('secp', ''))}",
        f"{gold(DIA)}  {cyn('Netlify Token')}   {mint('SET (' + st.get('netlify_token','')[:8] + '...)') if st.get('netlify_token') else red('NOT SET')}",
        f"{gold(DIA)}  {cyn('Site Name')}       {wht(st.get('site_name', ''))}",
        f"{gold(DIA)}  {cyn('Site URL')}        {mint(st.get('site_url', '')) if st.get('site_url') else red('N/A')}",
        f"{gold(DIA)}  {cyn('Site ID')}         {dim(st.get('site_id', '')[:20] + '...' if st.get('site_id') else 'N/A')}",
        f"{gold(DIA)}  {cyn('Xray Version')}    {wht(st.get('xray_version', 'N/A'))}",
        f"{gold(DIA)}  {cyn('Xray Binary')}     {grn(_detect_xray()[0] or 'Not found')}",
        f"{gold(DIA)}  {cyn('Deployments')}     {wht(str(len(st.get('deployments', []))))}",
    ]
    
    print(double_box(lines, 64, title="Complete Configuration", title_color=C.GOLD, border_color=C.TEAL))
    
    # Config file path
    print(f"\n  {dim('Config stored at:')} {cyn(SFILE)}")
    pause()

# ═══════════════════════════════════════════════════════════
#  MAIN MENU
# ═══════════════════════════════════════════════════════════
def main_menu(st):
    tw = _tw()
    w = min(max(tw, 48), 66)
    
    while True:
        # Clear screen
        print("\033[2J\033[H", end="")
        
        # Banner
        print(banner())
        
        # Status
        show_status(st)
        
        # Menu
        print(f"\n  {section_divider('MAIN MENU', w)}\n")
        
        menu_items = [
            ("1", "Install / Update Xray",    "Download & setup Xray core"),
            ("2", "Configure Settings",       "UUID, SNI, port, paths"),
            ("3", "Set Netlify Token",        "Personal access token"),
            ("4", "Deploy to Netlify",        "Create relay site"),
            ("5", "Generate VLESS Link",      "Connection string & QR"),
            ("6", "Manage Deployments",       "View, delete sites"),
            ("7", "Xray Service Control",     "Start, stop, restart, logs"),
            ("8", "Show Full Config",         "View all settings"),
        ]
        
        max_label_len = max(len(l) for _, l, _ in menu_items)
        
        for key, label, hint in menu_items:
            key_str = f" {bold(f'{key}')} "
            label_str = wht(label)
            # Show hints only if terminal is wide enough
            if w >= 58:
                pad = max_label_len - len(label) + 2
                if pad < 2: pad = 2
                print(f"    {teal(SQR)} {key_str} {label_str}{" " * pad}{dim(hint)}")
            else:
                print(f"    {teal(SQR)} {key_str} {label_str}")
        
        print(f"\n    {hr(w - 8, char=T * 3, color=C.DGRY)}")
        print(f"    {teal(SQR)}  {bold('[0]')}  {gry('Exit')}")
        print()
        
        rv = input(f"  {gold(ARR)} {bold('Select')} {dim('[0-8]')}: ").strip()
        
        if rv == "0" or rv.lower() == "q":
            print(f"\n  {gradient_text('  Goodbye!', GRAD_GREEN)}\n")
            break
        elif rv == "1": st = install_xray(st)
        elif rv == "2": st = configure(st)
        elif rv == "3": st = set_token(st)
        elif rv == "4": st = deploy_netlify(st)
        elif rv == "5": gen_vless(st)
        elif rv == "6": st = manage_deps(st)
        elif rv == "7": st = xray_menu(st)
        elif rv == "8": show_config(st)
        
        st = load_st()  # Refresh state

# ═══════════════════════════════════════════════════════════
#  AUTO SETUP — fully non-interactive
# ═══════════════════════════════════════════════════════════
def auto_setup(token):
    global AUTO_MODE, XBIN, XCFG_DIR, XCFG, XDIR
    AUTO_MODE = True

    print(banner())
    st = load_st()

    # 1. Set token
    print(f"\n  {section_divider('AUTO SETUP - STEP 1/5: SET TOKEN')}")
    st['netlify_token'] = token.strip()
    save_st(st)
    print(f"  {grn(CHK)}  {grn('Token set successfully!')}")

    # 2. Install Xray
    st = install_xray(st)
    if not st.get('xray_installed'):
        print(f"  {red(CRS)}  {red('Xray installation failed, aborting.')}")
        return

    # Re-detect Xray paths after install
    xbin, _ = _detect_xray()
    if xbin:
        XBIN, XCFG_DIR, XCFG = get_xray_paths(xbin)
        XDIR = XCFG_DIR
    print(f"  {gry(f'  Xray binary: {XBIN}')}")
    print(f"  {gry(f'  Config path: {XCFG}')}")

    # 3. Generate Xray config & start service
    print(f"\n  {section_divider('AUTO SETUP - STEP 2/5: GENERATE CONFIG')}")
    cfg_path = gen_xray_cfg(st)
    save_st(st)
    print(f"  {grn(CHK)}  {grn(f'Config written: {cfg_path}')}")

    # Open firewall (iptables + ufw if available)
    port = st.get('xray_port', 444)
    subprocess.run(['iptables', '-I', 'INPUT', '-p', 'tcp', '--dport', str(port), '-j', 'ACCEPT'], capture_output=True, timeout=10)
    try:
        subprocess.run(['ufw', 'allow', str(port) + '/tcp'], capture_output=True, timeout=10)
    except FileNotFoundError:
        pass
    subprocess.run(['systemctl', 'daemon-reload'], capture_output=True, timeout=10)
    subprocess.run(['systemctl', 'enable', 'xray'], capture_output=True, timeout=10)
    subprocess.run(['systemctl', 'restart', 'xray'], capture_output=True, timeout=10)
    
    # Verify Xray is running
    time.sleep(1)
    xstatus = subprocess.run(["systemctl", "is-active", "xray"], capture_output=True, text=True, timeout=5).stdout.strip()
    if xstatus == 'active':
        print(f"  {grn(CHK)}  {grn(f'Xray is running on port {port}')}")
    else:
        print(f"  {ylw(chr(0x26a0))}  {ylw(f'Xray status: {xstatus} - checking logs...')}")
        logs = subprocess.run(["journalctl", "-u", "xray", "--no-pager", "-n", "10"], capture_output=True, text=True, timeout=5).stdout
        print(f"  {dim(logs[-500:] if logs else 'No logs')}")

    # 4. Deploy to Netlify
    print(f"\n  {section_divider('AUTO SETUP - STEP 3/5: NETLIFY DEPLOY')}")
    st = deploy_netlify(st)
    if not st.get('site_url'):
        print(f"  {red(CRS)}  {red('Deployment failed, aborting.')}")
        return

    # 5. Generate VLESS link
    print(f"\n  {section_divider('AUTO SETUP - STEP 4/5: GENERATE LINK')}")
    gen_vless(st)

    print(f"\n  {section_divider('AUTO SETUP - COMPLETE')}")
    print(f"  {grn(CHK)}  {grn('All done! Your VLESS link is ready above.')}")
    print(f"  {gry('Run again without --auto for interactive menu.')}")
    print()

# ═══════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════
if __name__ == "__main__":
    try:
        # Parse command line args
        args = sys.argv[1:]
        token_arg = None
        auto = False
        i = 0
        while i < len(args):
            if args[i] in ('--token', '-t') and i + 1 < len(args):
                token_arg = args[i + 1]
                i += 2
            elif args[i] == '--auto' or args[i] == '-a':
                auto = True
                i += 1
            elif args[i] == '--token=':
                # --token=TOKEN format
                token_arg = args[i].split('=', 1)[1]
                i += 1
            else:
                i += 1

        if auto:
            if not token_arg:
                print(f"  {red(CRS)}  {red('Error: --auto requires --token <TOKEN>')}")
                sys.exit(1)
            auto_setup(token_arg)
        else:
            st = load_st()
            main_menu(st)
    except KeyboardInterrupt:
        print(f"\n\n  {gry('Interrupted. Goodbye!')}")
    except Exception as e:
        print(f"\n  {red(f'Error: {e}')}")
        import traceback
        traceback.print_exc()
