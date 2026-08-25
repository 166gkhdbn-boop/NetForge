const SP="/nf-d94e3af0";
const FAKE_HTML = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>DevPulse</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:#0a0e1a;color:#c8d6e5;display:flex;justify-content:center;align-items:center;height:100vh}h1{background:linear-gradient(90deg,#00d4ff,#7c3aed);-webkit-background-clip:text;-webkit-text-fill-color:transparent;font-size:2rem}</style></head><body><h1>DevPulse Analytics</h1></body></html>`;

export default async (request, context) => {
  const url = new URL(request.url);
  const path = url.pathname;

  if (path === "/" || path === "/index.html") {
    return new Response(FAKE_HTML, {headers: {"content-type": "text/html; charset=utf-8"}});
  }

  if (path === SP || path.startsWith(SP + "/")) {
    const origin = "http://31.56.176.104:444";
    const headers = new Headers(request.headers);
    const clientIP = request.headers.get("x-nf-client-connection-ip") || "";
    headers.set("x-forwarded-for", clientIP);
    headers.set("x-real-ip", clientIP);
    const opts = {method: request.method, headers};
    if (!["GET", "HEAD"].includes(request.method)) { opts.body = request.body; }
    try {
      const resp = await fetch(origin + path + url.search, opts);
      const rh = new Headers(resp.headers);
      rh.delete("content-encoding");
      return new Response(resp.body, {status: resp.status, headers: rh});
    } catch(e) { return new Response("relay error: " + e.message, {status: 502}); }
  }
  return new Response("Not Found", {status: 404});
};