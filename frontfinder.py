#!/usr/bin/env python3
"""
FrontFinder — Domain-fronting scanner for NetForge
==================================================
Finds innocent-looking domains on the same CDN (Netlify) that can be used
as a "front" for your relay:

    SNI = front domain (what DPI sees, e.g. kind.sigs.k8s.io)
    HTTP Host = your site (where Netlify actually routes)

For each candidate domain it:
  1. Resolves DNS and opens TLS to :443 with SNI = candidate
  2. Verifies the presented certificate actually belongs to the candidate
  3. Sends  GET /  with  Host: <your-site>
  4. Compares the response body with your site's real content
  5. Reports it as a working front only if the bodies match

Termux usage:
    pkg install python
    python frontfinder.py --site nf-e2489eeb.netlify.app
    python frontfinder.py --site nf-e2489eeb.netlify.app --candidates mylist.txt
    python frontfinder.py --site nf-e2489eeb.netlify.app --marker "DevPulse"

Stdlib only — no pip packages needed.
"""

import argparse
import concurrent.futures
import socket
import ssl
import sys
import time

# ── Starter candidates ──────────────────────────────────────────
# kind.sigs.k8s.io is user-verified (2026-10-03). The rest are plausible
# Netlify-hosted domains — the scanner verifies each one behaviorally,
# so wrong guesses are harmless (they just fail the test).
STARTER_CANDIDATES = [
    "kind.sigs.k8s.io",
    "k8s.io",
    "kubernetes.io",
    "sigs.k8s.io",
    "git.k8s.io",
    "testgrid.k8s.io",
]

TIMEOUT = 10


def log(msg):
    print(msg, flush=True)


def fetch_raw(sni_host, http_host, path="/", timeout=TIMEOUT):
    """TLS to sni_host:443 (SNI=sni_host), then HTTP GET with Host=http_host.
    Returns (status_line, headers_dict, body_bytes)."""
    ctx = ssl.create_default_context()
    # We check the cert manually so a mismatch is a clean "no" instead of an exception.
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_REQUIRED

    raw = socket.create_connection((sni_host, 443), timeout=timeout)
    try:
        tls = ctx.wrap_socket(raw, server_hostname=sni_host)
        try:
            cert = tls.getpeercert()
            req = (
                f"GET {path} HTTP/1.1\r\n"
                f"Host: {http_host}\r\n"
                f"User-Agent: Mozilla/5.0 (Linux; Android 14)\r\n"
                f"Connection: close\r\n\r\n"
            )
            tls.sendall(req.encode())
            tls.settimeout(timeout)
            data = b""
            while True:
                try:
                    chunk = tls.recv(65536)
                except socket.timeout:
                    break
                if not chunk:
                    break
                data += chunk
        finally:
            tls.close()
    finally:
        raw.close()

    if b"\r\n\r\n" not in data:
        return None, {}, b""
    head, _, body = data.partition(b"\r\n\r\n")
    lines = head.decode("latin1").split("\r\n")
    status = lines[0] if lines else ""
    headers = {}
    for ln in lines[1:]:
        if ":" in ln:
            k, v = ln.split(":", 1)
            headers[k.strip().lower()] = v.strip()
    # NOTE: not decoding chunked bodies — we only need a fingerprint compare,
    # and both reference & candidate go through the same path.
    return status, headers, body


def cert_matches_host(sni_host, timeout=TIMEOUT):
    """True if the TLS cert presented for SNI=sni_host actually covers sni_host."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_REQUIRED
    raw = socket.create_connection((sni_host, 443), timeout=timeout)
    try:
        tls = ctx.wrap_socket(raw, server_hostname=sni_host)
        try:
            cert = tls.getpeercert()
        finally:
            tls.close()
    finally:
        raw.close()
    if not cert:
        return False
    names = set()
    for typ, val in cert.get("subjectAltName", ()):
        if typ == "DNS":
            names.add(val.lower())
    host = sni_host.lower()
    return host in names or any(
        n.startswith("*.") and host.endswith(n[1:]) for n in names
    )


def test_candidate(candidate, site, ref_body, marker):
    """Returns (candidate, ok: bool, detail: str)."""
    t0 = time.time()
    try:
        try:
            ips = socket.getaddrinfo(candidate, 443, type=socket.SOCK_STREAM)
            ip = ips[0][4][0]
        except Exception as e:
            return candidate, False, f"DNS failed ({e})"

        if not cert_matches_host(candidate):
            return candidate, False, "cert does not cover candidate (not served here)"

        status, headers, body = fetch_raw(candidate, site)
        if not status:
            return candidate, False, "empty response"
        if "200" not in status:
            return candidate, False, f"HTTP {status.split(' ', 1)[1] if ' ' in status else status}"

        dt = time.time() - t0
        if marker:
            ok = marker.encode() in body
            detail = f"marker {'found' if ok else 'NOT found'} ({len(body)} bytes, {dt:.1f}s, {ip})"
        else:
            ok = body == ref_body and len(body) > 0
            detail = (
                f"body {'MATCHES' if ok else 'differs from'} site "
                f"({len(body)} bytes, {dt:.1f}s, {ip})"
            )
        return candidate, ok, detail
    except Exception as e:
        return candidate, False, f"error: {type(e).__name__}: {e}"


def main():
    ap = argparse.ArgumentParser(description="Find domain-fronting candidates for your Netlify relay.")
    ap.add_argument("--site", required=True, help="your Netlify hostname, e.g. nf-e2489eeb.netlify.app")
    ap.add_argument("--candidates", help="file with one domain per line (default: built-in starter list)")
    ap.add_argument("--marker", default="", help="unique string in your site's HTML (default: byte-compare full body)")
    ap.add_argument("--threads", type=int, default=20, help="parallel workers (default: 20)")
    ap.add_argument("--timeout", type=int, default=TIMEOUT, help="seconds per probe (default: 10)")
    ap.add_argument("--out", default="fronts.txt", help="file to save working fronts (default: fronts.txt)")
    args = ap.parse_args()

    global TIMEOUT
    TIMEOUT = args.timeout
    site = args.site.strip().lower()

    if args.candidates:
        with open(args.candidates) as f:
            candidates = [l.strip().lower() for l in f if l.strip() and not l.startswith("#")]
    else:
        candidates = STARTER_CANDIDATES[:]
    # dedupe, keep order
    candidates = list(dict.fromkeys(c for c in candidates if c and c != site))
    if not candidates:
        log("no candidates to test"); return 1

    log(f"[*] reference: fetching https://{site}/ directly ...")
    try:
        _, _, ref_body = fetch_raw(site, site)
    except Exception as e:
        log(f"[!] could not fetch reference site: {e}")
        return 1
    if not ref_body:
        log("[!] reference site returned empty body — aborting")
        return 1
    log(f"[*] reference body: {len(ref_body)} bytes")
    log(f"[*] testing {len(candidates)} candidates with {args.threads} threads ...\n")

    working = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.threads) as pool:
        futures = {pool.submit(test_candidate, c, site, ref_body, args.marker): c for c in candidates}
        for fut in concurrent.futures.as_completed(futures):
            cand, ok, detail = fut.result()
            mark = "✅ FRONT" if ok else "❌"
            log(f"{mark}  {cand}\n      └─ {detail}")
            if ok:
                working.append(cand)

    log(f"\n{'='*52}")
    if working:
        log(f"[+] {len(working)} working front domain(s):")
        for w in working:
            log(f"    • {w}")
        with open(args.out, "w") as f:
            f.write("\n".join(working) + "\n")
        log(f"[+] saved to {args.out}")
        log("\nUse in your client:  SNI / address = front domain,")
        log(f"                     Host header   = {site}")
    else:
        log("[-] no working fronts found. Add more candidates and retry.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
