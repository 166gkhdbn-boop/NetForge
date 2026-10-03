// ─────────────────────────────────────────────────────────────
// NetForge relay edge function — TEMPLATE
// This file is generated at deploy time by deploy.sh (RELAY_TPL).
// __SECPATH__ and __ORIGIN__ are placeholders replaced per-deployment.
// Do NOT commit real server IPs, secret paths, or UUIDs to this repo.
// ─────────────────────────────────────────────────────────────
const SP="__SECPATH__";
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
      // Allow the request body to stream (faster uploads, lower memory)
      opts.duplex = "half";
    }
    try {
      const resp = await fetch(origin + path + url.search, opts);
      const rh = new Headers(resp.headers);
      rh.delete("content-encoding");
      // XHTTP download is a long-lived streaming GET. If the CDN caches or
      // buffers it, the stream hangs and the client never receives data.
      // Forbid any caching/buffering of relayed responses.
      rh.set("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
      rh.set("Pragma", "no-cache");
      rh.set("CDN-Cache-Control", "no-store");
      return new Response(resp.body, {status: resp.status, headers: rh});
    } catch(e) {
      return new Response("relay error: " + e.message, {status: 502});
    }
  }

  return new Response("Not Found", {status: 404});
};
