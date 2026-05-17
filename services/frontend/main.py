"""
frontend – user-facing service
Calls backend, renders a simple HTML product catalog.
Also exposes JSON endpoints for curl-based demos.
"""
import os
import socket

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

app = FastAPI(title="frontend")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

VERSION = os.getenv("VERSION", "v1")
HOSTNAME = socket.gethostname()
BACKEND_URL = os.getenv("BACKEND_URL", "http://backend:8000")


@app.get("/health")
def health():
    return {"status": "ok", "service": "frontend", "version": VERSION, "pod": HOSTNAME}


@app.get("/api/products")
def api_products():
    """JSON endpoint – useful for curl demos."""
    try:
        resp = httpx.get(f"{BACKEND_URL}/products", timeout=5.0)
        resp.raise_for_status()
        data = resp.json()
    except httpx.RequestError as e:
        raise HTTPException(status_code=503, detail=f"backend unreachable: {e}")
    data["frontend_pod"] = HOSTNAME
    data["frontend_version"] = VERSION
    return data


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    """HTML product catalog – shows full call chain."""
    try:
        resp = httpx.get(f"{BACKEND_URL}/products", timeout=5.0)
        resp.raise_for_status()
        data = resp.json()
        products = data.get("products", [])
        error = None
    except Exception as e:
        products = []
        error = str(e)
        data = {}

    rows = ""
    for p in products:
        sale = "🔥 SALE" if p.get("on_sale") else ""
        rows += f"""
        <tr>
          <td>{p['id']}</td>
          <td>{p['name']} {sale}</td>
          <td>${p['price']}</td>
          <td style="color:#4ade80">${p['discounted_price']}</td>
          <td>{p['stock']}</td>
        </tr>"""

    chain = f"""
    <p>🌐 <b>frontend</b> pod: <code>{HOSTNAME}</code> ({VERSION})</p>
    <p>⚙️  <b>backend</b> pod: <code>{data.get('backend_pod','?')}</code> ({data.get('backend_version','?')})</p>
    <p>🗄️  <b>database-svc</b> pod: <code>{data.get('db_pod','?')}</code> ({data.get('db_version','?')})</p>
    """

    err_block = f'<div style="color:#f87171;padding:12px;background:#1a0000;border-radius:8px">⚠️ {error}</div>' if error else ""

    html = f"""<!DOCTYPE html>
<html>
<head>
  <title>Istio Demo – Product Catalog</title>
  <style>
    body {{ font-family: system-ui; background:#0a0a0a; color:#ececec; padding:32px; }}
    h1   {{ color:#60a5fa; }}
    table {{ border-collapse:collapse; width:100%; margin-top:16px; }}
    th,td {{ border:1px solid #333; padding:10px 14px; text-align:left; }}
    th    {{ background:#1e1e1e; color:#93c5fd; }}
    tr:hover {{ background:#111; }}
    code  {{ background:#1e1e1e; padding:2px 6px; border-radius:4px; font-size:13px; }}
    .chain {{ background:#111; border:1px solid #222; border-radius:8px; padding:16px; margin:16px 0; }}
  </style>
</head>
<body>
  <h1>🕸️ Istio Demo — Product Catalog</h1>
  {err_block}
  <div class="chain">
    <b>Call chain (Istio mTLS between every hop):</b>
    {chain}
  </div>
  <table>
    <tr><th>ID</th><th>Name</th><th>Price</th><th>Sale Price (−10%)</th><th>Stock</th></tr>
    {rows if rows else '<tr><td colspan="5" style="color:#555">No data</td></tr>'}
  </table>
  <p style="color:#555;font-size:12px;margin-top:24px">
    Refresh to see Istio load-balancing across pods ·
    <a href="/api/products" style="color:#60a5fa">JSON</a>
  </p>
</body>
</html>"""
    return HTMLResponse(content=html)
