# NetForge — Security Model

This document describes what NetForge protects against, what it does **not**
protect against, and how to install it as safely as possible. Please read it
before deploying.

## Traffic path

```
You (V2Ray client)
   │  VLESS over XHTTP, TLS-encrypted (Netlify's certificate)
   ▼
Netlify CDN / Edge Function          ← TLS ends here
   │  plain HTTP to your VPS
   ▼
Xray on your VPS (VLESS inbound)
```

## What this means

1. **Your VPS IP is hidden from clients and censors.** Clients only ever see
   Netlify's IP addresses. Your server's real IP never appears in the VLESS
   link or in client-visible traffic.
2. **Client → Netlify is encrypted with TLS.** An observer between you and
   Netlify sees only an ordinary HTTPS connection to a Netlify domain.
3. **Netlify → VPS is plain HTTP.** Your VLESS UUID (the only authentication
   credential) travels unencrypted on this hop. In practice this means:
   - Anyone able to observe traffic between Netlify's edge and your VPS
     (e.g. a network-level adversary on that path) could recover your UUID.
   - Netlify itself can see the relayed traffic metadata.
4. **The edge function has no authentication** beyond the secrecy of the
   relay path (`/nf-<random>/`). If the path leaks, anyone can proxy traffic
   through your deployment and consume your Netlify bandwidth. Rotate the
   secret path (menu → Configure → new Secret Path → redeploy) if you suspect
   a leak.

## Recommendations

- **Use a fresh secret path + UUID per deployment.** The script generates
  both randomly; don't reuse them across servers.
- **Prefer `vps-setup.sh` or the interactive menu** over piping unknown
  scripts as root.
- **Install integrity.** The one-line installer downloads `deploy.sh` from
  GitHub on every run. If you want to verify before executing:
  ```bash
  curl -sL https://raw.githubusercontent.com/166gkhdbn-boop/NetForge/main/deploy.sh -o deploy.sh
  # inspect deploy.sh, then:
  bash deploy.sh
  ```
  For `--auto` mode, prefer the `NETLIFY_AUTH_TOKEN` environment variable
  over `--token` so the token never appears in `ps` output or shell history.
- **File permissions.** The script stores the Netlify token and UUID in
  `~/.vless-netlify/config.json` and the Xray config with mode `600`
  (owner-only). Don't copy these files to shared machines.
- **Credential rotation.** If your server IP, UUID, or secret path is ever
  exposed: generate a new UUID + secret path, redeploy, and delete the old
  Netlify site.

## Reporting issues

Security issues: please open a GitHub issue describing the problem
**without** including your token, UUID, server IP, or secret path.
