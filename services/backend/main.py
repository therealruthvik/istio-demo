"""
backend – business logic layer
Calls database-svc, adds computed fields, returns enriched data.
"""
import os
import socket

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="backend")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

VERSION = os.getenv("VERSION", "v1")
HOSTNAME = socket.gethostname()
DB_URL = os.getenv("DB_URL", "http://database-svc:8000")


@app.get("/health")
def health():
    return {"status": "ok", "service": "backend", "version": VERSION, "pod": HOSTNAME}


@app.get("/products")
def get_products():
    try:
        resp = httpx.get(f"{DB_URL}/products", timeout=5.0)
        resp.raise_for_status()
        data = resp.json()
    except httpx.RequestError as e:
        raise HTTPException(status_code=503, detail=f"database-svc unreachable: {e}")
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502, detail=f"database-svc error: {e}")

    # Enrich: add discount field
    for p in data.get("products", []):
        p["discounted_price"] = round(p["price"] * 0.9, 2)
        p["on_sale"] = p["stock"] > 100

    return {
        "products": data.get("products", []),
        "backend_pod": HOSTNAME,
        "backend_version": VERSION,
        "db_pod": data.get("served_by"),
        "db_version": data.get("version"),
    }


@app.get("/products/{product_id}")
def get_product(product_id: int):
    try:
        resp = httpx.get(f"{DB_URL}/products/{product_id}", timeout=5.0)
        resp.raise_for_status()
        data = resp.json()
    except httpx.RequestError as e:
        raise HTTPException(status_code=503, detail=f"database-svc unreachable: {e}")

    product = data.get("product", {})
    product["discounted_price"] = round(product.get("price", 0) * 0.9, 2)
    return {
        "product": product,
        "backend_pod": HOSTNAME,
        "backend_version": VERSION,
        "db_pod": data.get("served_by"),
    }
