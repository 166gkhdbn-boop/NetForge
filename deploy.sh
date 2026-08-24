#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  NetForge VLESS - XHTTP/Netlify Relay Manager               ║
# ║  Single-file deployment script                               ║
# ║  Usage: bash deploy.sh                                      ║
# ╚══════════════════════════════════════════════════════════════╝
SELF="$0"
CDIR="$HOME/.vless-netlify"
mkdir -p "$CDIR"
PY="$CDIR/manager.py"

# Handle pipe/fd execution (bash <(curl ...) or curl | bash)
case "$SELF" in
  /dev/fd/*|/proc/*/fd/*|bash|""|-bash)
    echo "  Downloading script to file..."
    SELF="$CDIR/deploy.sh"
    curl -sL "https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh" -o "$SELF" || { echo "  Download failed"; exit 1; }
    ;;
esac

if [ ! -f "$PY" ] || [ "$SELF" -nt "$PY" ]; then
  sed -n "/^__PYBOT__/,\$ p" "$SELF" | sed "1d" > "$PY"
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
    if default:
        hint = dim(f"  [{default}]")
        rv = input(f"  {cyn(ARR)} {wht(prompt)} {hint}: ").strip()
        return rv if rv else default
    rv = input(f"  {cyn(ARR)} {wht(prompt)}: ").strip()
    while not rv:
        rv = input(f"  {red(CRS)} {ylw("Required")}: ").strip()
    return rv

def askyn(prompt, default=True):
    hint = dim("[Y/n]") if default else dim("[y/N]")
    rv = input(f"  {cyn(ARR)} {wht(prompt)} {hint} ").strip().lower()
    if not rv: return default
    return rv in ("y", "yes", "1", "بله")

def pause(msg="Press Enter to continue..."):
    input(f"\n  {dim(T * 40)}\n  {gry(msg)}  ")

def choose(prompt, options, width=62):
    """
    options: list of (key, label, hint)
    Returns selected key or None for back/0.
    """
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
XDIR = "/usr/local/xray"

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
        "uuid": "", "sni": "kind.sigs.k8s.io", "alt_sni": "dl.google.com",
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
        f"{gold(DIA)}  {cyn('SNI')}            {wht(st.get('sni', 'N/A'))}",
        f"{gold(DIA)}  {cyn('Alt SNI')}        {dim(st.get('alt_sni', 'N/A'))}",
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
def install_xray(st):
    print(f"\n  {section_divider('XRAY INSTALLATION')}\n")
    
    if st.get('xray_installed') and os.path.isfile(f"{XDIR}/xray"):
        if not askyn("Xray is already installed. Reinstall?", False):
            print(f"  {gry('Cancelled.')}")
            pause()
            return st
    
    print(f"  {cyn(DOT)}  {wht('Detecting latest Xray release...')}")
    
    try:
        req = urllib.request.Request(
            "https://api.github.com/repos/XTLS/Xray-core/releases/latest",
            headers={"User-Agent": "NetForge/2.0"}
        )
        data = json.loads(urllib.request.urlopen(req, timeout=15).read())
        tag = data["tag_name"]
        
        # Find linux 64-bit asset
        asset = None
        for a in data.get("assets", []):
            name = a["name"].lower()
            if "linux" in name and "64" in name and name.endswith(".zip") and "arm" not in name and "mips" not in name and "loong" not in name and "ppc" not in name and "riscv" not in name and "s390" not in name:
                asset = a
                break
        if not asset:
            print(f"  {red(CRS)}  {red('Could not find suitable release asset.')}")
            pause()
            return st
        
        url = asset["browser_download_url"]
        print(f"  {grn(STR)}  {grn('Found:')} {wht(tag)}")
        print(f"  {cyn(DOT)}  {wht('Downloading...')}")
        
        sp = spinner_start(f"Downloading {asset['name']}")
        tmp = "/tmp/xray-install.zip"
        try:
            urllib.request.urlretrieve(url, tmp)
        finally:
            spinner_stop()
        
        print(f"  {grn(STR)}  {grn('Download complete. Extracting...')}")
        
        os.makedirs(XDIR, exist_ok=True)
        import zipfile
        with zipfile.ZipFile(tmp, 'r') as zf:
            zf.extractall('/tmp/xray-extract')
        # Find xray binary and copy
        import glob as _glob, shutil as _shutil
        for xb in _glob.glob('/tmp/xray-extract/**/xray', recursive=True):
            _shutil.copy2(xb, f'{XDIR}/xray')
            break
        os.chmod(f'{XDIR}/xray', 0o755)
        subprocess.run(['rm', '-rf', '/tmp/xray-extract', tmp], capture_output=True)
        
        # Test binary
        ver_out = subprocess.run([f"{XDIR}/xray", "version"], capture_output=True, text=True, timeout=10)
        ver_line = ver_out.stdout.strip().split("\n")[0] if ver_out.stdout else tag
        
        # Create systemd service
        svc = f"""[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
ExecStart={XDIR}/xray run -config {XDIR}/config.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"""
        with open("/etc/systemd/system/xray.service", "w") as f:
            f.write(svc)
        
        subprocess.run(["systemctl", "daemon-reload"], capture_output=True, timeout=10)
        
        st["xray_installed"] = True
        st["xray_version"] = ver_line
        save_st(st)
        
        print(f"  {grn(CHK)}  {grn('Xray installed successfully!')}")
        print(f"  {gry(f'  Version: {ver_line}')}")
        
    except Exception as e:
        print(f"  {red(CRS)}  {red(f'Install failed: {e}')}")
    
    pause()
    return st

# ═══════════════════════════════════════════════════════════
#  XRAY CONFIG GENERATION
# ═══════════════════════════════════════════════════════════
RELAY_TPL = '''const SP="__SECPATH__";
const FAKE_HTML = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>DevPulse</title><style>body{background:#0a0e1a;color:#c8d6e5;font-family:-apple-system,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}h1{background:linear-gradient(90deg,#00d4ff,#7c3aed);-webkit-background-clip:text;-webkit-text-fill-color:transparent;font-size:2rem}</style></head><body><h1>DevPulse Analytics</h1></body></html>";
export default async (request, context) => {
  const url = new URL(request.url);
  const path = url.pathname;
  if (path === "/" || path === "/index.html") {
    return new Response(FAKE_HTML, {headers:{"content-type":"text/html;charset=utf-8"}});
  }
  if (path === SP || path.startsWith(SP + "/")) {
    const origin = "__ORIGIN__";
    const headers = new Headers(request.headers);
    headers.set("x-forwarded-for", request.headers.get("x-nf-client-connection-ip") || "");
    const opts = {method: request.method, headers};
    opts.body = !["GET","HEAD"].includes(request.method) ? request.body : undefined;
    try {
      const resp = await fetch(origin + path + url.search, opts);
      const rh = new Headers(resp.headers);
      rh.delete("content-encoding");
      return new Response(resp.body, {status: resp.status, headers: rh});
    } catch(e) {
      return new Response("relay error", {status: 502});
    }
  }
  return new Response("Not Found", {status: 404});
};
'''

TOML_CFG = r"""[build]
  publish = "public"

[[edge_functions]]
  function = "relay"
  path = "/__SECPATH__/*"

[[edge_functions]]
  function = "relay"
  path = "/"
"""

FAKE_HTML_FILE = r"""<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DevPulse - Developer Analytics</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0e1a;color:#c8d6e5;line-height:1.6}header{background:linear-gradient(135deg,#0f1729,#1a1f35);padding:2rem;text-align:center;border-bottom:1px solid #1e2d4a}.logo{font-size:2rem;font-weight:700;background:linear-gradient(90deg,#00d4ff,#7c3aed);-webkit-background-clip:text;-webkit-text-fill-color:transparent}nav{display:flex;justify-content:center;gap:2rem;padding:1rem;background:#0d1220}nav a{color:#8892b0;text-decoration:none;font-size:.9rem}nav a:hover{color:#00d4ff}.hero{padding:4rem 2rem;text-align:center;max-width:800px;margin:0 auto}.hero h2{font-size:2.5rem;margin-bottom:1rem;color:#e6f1ff}.hero p{color:#8892b0;font-size:1.1rem;max-width:600px;margin:0 auto 2rem}.features{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:2rem;padding:3rem 2rem;max-width:1000px;margin:0 auto}.feature{background:#111827;border:1px solid #1e2d4a;border-radius:8px;padding:1.5rem;transition:transform .2s}.feature:hover{transform:translateY(-2px)}.feature h3{color:#00d4ff;margin-bottom:.5rem}.feature p{color:#8892b0;font-size:.9rem}footer{text-align:center;padding:2rem;color:#4a5568;font-size:.8rem;border-top:1px solid #1e2d4a}</style></head><body><header><div class="logo">DevPulse</div><p style="color:#64ffda;margin-top:.5rem">Real-time developer analytics platform</p></header><nav><a href="#">Dashboard</a><a href="#">Analytics</a><a href="#">Monitoring</a><a href="#">Docs</a></nav><section class="hero"><h2>Monitor. Analyze. Optimize.</h2><p>Powerful developer analytics and monitoring for modern applications. Track performance metrics in real-time.</p><button style="background:linear-gradient(135deg,#00d4ff,#7c3aed);color:#fff;border:none;padding:.75rem 2rem;border-radius:6px;font-size:1rem;cursor:pointer">Get Started Free</button></section><section class="features"><div class="feature"><h3>Real-time Metrics</h3><p>Monitor application performance with sub-second granularity and custom dashboards.</p></div><div class="feature"><h3>Error Tracking</h3><p>Capture and analyze errors with full stack traces and contextual information.</p></div><div class="feature"><h3>API Analytics</h3><p>Track API response times, throughput, and error rates across all endpoints.</p></div></section><footer>DevPulse Analytics Platform &copy; 2025</footer></body></html>"""

def gen_xray_cfg(st):
    ip = st["server_ip"] or "0.0.0.0"
    port = st.get("xray_port", 444)
    uuid = st["uuid"]
    sni = st.get("sni", "kind.sigs.k8s.io")
    alt_sni = st.get("alt_sni", "dl.google.com")
    secp = st.get("secp", "/secpath-" + rhex(8))
    st["secp"] = secp
    
    # Check if real TLS certs exist
    has_certs = os.path.isfile(f"{XDIR}/cert.pem") and os.path.isfile(f"{XDIR}/key.pem")
    
    stream = {
        "network": "xhttp",
        "security": "tls" if has_certs else "none",
        "xhttpSettings": {
            "path": secp,
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
    
    cfg_path = f"{XDIR}/config.json"
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
    print(f"  {icon_kv(SQR, 'SNI', st.get('sni', 'N/A'))}")
    print(f"  {icon_kv(SQR, 'Alt SNI', st.get('alt_sni', 'N/A'))}")
    print(f"  {icon_kv(SQR, 'Secret Path', st.get('secp', 'auto-gen'))}")
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
    
    st['sni'] = ask("Primary SNI", st.get('sni', 'kind.sigs.k8s.io'))
    st['alt_sni'] = ask("Alternative SNI", st.get('alt_sni', 'dl.google.com'))
    st['secp'] = ask("Secret Path", st.get('secp', '/secpath-' + rhex(8)))
    
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
    
    secp = st.get('secp', '/secpath-' + rhex(8))
    st['secp'] = secp
    port = st.get('xray_port', 444)
    sni = st.get('sni', 'kind.sigs.k8s.io')
    
    origin = f"http://{ip}:{port}"
    
    print(f"  {cyn(DOT)}  {wht('Preparing deployment files...')}")
    
    relay_js = RELAY_TPL.replace("__SECPATH__", secp).replace("__ORIGIN__", origin)
    toml_content = TOML_CFG.replace("__SECPATH__", secp)
    
    site_name = f"dp-{rhex(8)}"
    st['site_name'] = site_name
    
    print(f"  {icon_kv(SQR, 'Site Name', site_name)}")
    print(f"  {icon_kv(SQR, 'Origin', origin)}")
    print(f"  {icon_kv(SQR, 'Secret Path', secp)}")
    print()
    
    if not askyn("Proceed with deployment?", True):
        print(f"  {gry('Cancelled.')}")
        pause()
        return st
    
    auth_header = {"Authorization": f"Bearer {token}"}
    
    # Build ZIP in memory
    print(f"  {cyn(DOT)}  {wht('Creating deployment package...')}")
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("public/index.html", FAKE_HTML_FILE)
        zf.writestr("netlify/edge-functions/relay.js", relay_js)
        zf.writestr("netlify.toml", toml_content)
    zip_bytes = buf.getvalue()
    print(f"  {grn(STR)}  {grn('Package created:')} {wht(f'{len(zip_bytes)} bytes')}")
    
    # Create site
    print(f"  {cyn(DOT)}  {wht('Creating Netlify site...')}")
    sp = spinner_start("Creating site...")
    try:
        req = urllib.request.Request(
            "https://api.netlify.com/api/v1/sites",
            data=json.dumps({"name": site_name}).encode(),
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
    print(f"  {cyn(DOT)}  {wht('Uploading deploy package...')}")
    
    # Deploy ZIP
    sp = spinner_start("Uploading...")
    try:
        deploy_req = urllib.request.Request(
            f"https://api.netlify.com/api/v1/sites/{site_id}/deploys",
            data=zip_bytes,
            headers={**auth_header, "Content-Type": "application/zip"}
        )
        deploy_resp = json.loads(urllib.request.urlopen(deploy_req, timeout=120).read())
        deploy_id = deploy_resp["id"]
        deploy_state = deploy_resp.get("state", "")
    except Exception as e:
        spinner_stop()
        print(f"  {red(CRS)}  {red(f'Upload failed: {e}')}")
        pause()
        return st
    spinner_stop()
    
    print(f"  {grn(STR)}  {grn('Package uploaded. Waiting for deploy...')}")
    
    # Poll deploy status (should be fast with ZIP)
    sp = spinner_start("Deploying...")
    built = False
    for i in range(24):  # 120 seconds
        time.sleep(5)
        try:
            check = urllib.request.Request(
                f"https://api.netlify.com/api/v1/sites/{site_id}/deploys/{deploy_id}",
                headers=auth_header
            )
            info = json.loads(urllib.request.urlopen(check, timeout=15).read())
            state = info.get("state", "")
            if state == "ready":
                built = True
                break
            elif state == "error":
                spinner_stop()
                print(f"  {red(CRS)}  {red('Deploy failed!')}")
                print(f"  {dim(str(info.get('error_message', '')))}")
                save_st(st)
                pause()
                return st
        except: pass
    spinner_stop()
    
    # Save deployment info regardless
    dep = {
        "site_name": site_name,
        "site_id": site_id,
        "site_url": site_url,
        "deploy_id": deploy_id,
        "time": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    deps = st.get('deployments', [])
    deps.append(dep)
    st['deployments'] = deps
    save_st(st)
    
    if built:
        print(f"  {grn(CHK)}  {grn('Deployment successful!')}")
        print(f"  {icon_kv(SQR, 'Site URL', site_url, val_color=mint)}")
    else:
        print(f"  {ylw('⚠')}  {ylw('Deploy timeout. Site created but may still be processing.')}")
        print(f"  {dim('Check Netlify dashboard or try Generate VLESS Link later.')}")
    
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
    sni = st.get('sni', 'kind.sigs.k8s.io')
    secp = st.get('secp', '')
    site = st['site_url']
    # Strip protocol from site URL for host parameter
    site_host = site.replace('https://', '').replace('http://', '')
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
    
    # Address = SNI domain, host param = Netlify site hostname (no protocol)
    link = (
        f"vless://{uuid}@{sni}:443?"
        f"type=xhttp&security=tls&sni={sni}"
        f"&path={urllib.parse.quote(secp)}&mode=auto"
        f"&alpn=h2%2Chttp%2F1.1&encryption=none"
        f"&fp=chrome&insecure=0&allowInsecure=0"
        f"&host={site_host}"
        f"&extra={extra_encoded}"
        f"#NetForge"
    )
    
    # Short version for QR
    link_short = (
        f"vless://{uuid}@{sni}:443?"
        f"type=xhttp&security=tls&sni={sni}"
        f"&path={urllib.parse.quote(secp)}&mode=auto"
        f"&host={site_host}"
        f"&extra={extra_encoded}"
        f"#NetForge"
    )
    
    lines = [
        f"{gold(DIA)}  {cyn('Address')}       {mint(sni)}",
        f"{gold(DIA)}  {cyn('Host')}          {wht(site)}",
        f"{gold(DIA)}  {cyn('Port')}          {wht('443')}",
        f"{gold(DIA)}  {cyn('UUID')}          {dim(uuid[:18])}...",
        f"{gold(DIA)}  {cyn('Network')}       {wht('xhttp')}",
        f"{gold(DIA)}  {cyn('Security')}      {wht('tls')}",
        f"{gold(DIA)}  {cyn('SNI')}           {wht(sni)}",
        f"{gold(DIA)}  {cyn('Path')}          {wht(secp)}",
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
    
    installed = os.path.isfile(f"{XDIR}/xray")
    
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
        f"{gold(DIA)}  {cyn('Primary SNI')}     {wht(st.get('sni', ''))}",
        f"{gold(DIA)}  {cyn('Alt SNI')}         {silver(st.get('alt_sni', ''))}",
        f"{gold(DIA)}  {cyn('Secret Path')}     {wht(st.get('secp', ''))}",
        f"{gold(DIA)}  {cyn('Netlify Token')}   {mint('SET (' + st.get('netlify_token','')[:8] + '...)') if st.get('netlify_token') else red('NOT SET')}",
        f"{gold(DIA)}  {cyn('Site Name')}       {wht(st.get('site_name', ''))}",
        f"{gold(DIA)}  {cyn('Site URL')}        {mint(st.get('site_url', '')) if st.get('site_url') else red('N/A')}",
        f"{gold(DIA)}  {cyn('Site ID')}         {dim(st.get('site_id', '')[:20] + '...' if st.get('site_id') else 'N/A')}",
        f"{gold(DIA)}  {cyn('Xray Version')}    {wht(st.get('xray_version', 'N/A'))}",
        f"{gold(DIA)}  {cyn('Xray Binary')}     {grn('/usr/local/xray/xray') if os.path.isfile(f'{XDIR}/xray') else red('Not found')}",
        f"{gold(DIA)}  {cyn('TLS Cert')}        {grn('Present') if os.path.isfile(f'{XDIR}/cert.pem') else red('Missing')}",
        f"{gold(DIA)}  {cyn('TLS Key')}         {grn('Present') if os.path.isfile(f'{XDIR}/key.pem') else red('Missing')}",
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
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════
if __name__ == "__main__":
    try:
        st = load_st()
        main_menu(st)
    except KeyboardInterrupt:
        print(f"\n\n  {gry('Interrupted. Goodbye!')}")
    except Exception as e:
        print(f"\n  {red(f'Error: {e}')}")
        import traceback
        traceback.print_exc()
