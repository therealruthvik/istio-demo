"""
database-svc – mock data service
Returns fake product records. No real DB needed.
"""
import os
import random
import socket

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="database-svc")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

VERSION = os.getenv("VERSION", "v1")
HOSTNAME = socket.gethostname()

PRODUCTS = [
    {"id": 1, "name": "Laptop Pro", "price": 1299.99, "stock": 42},
    {"id": 2, "name": "Wireless Mouse", "price": 29.99, "stock": 150},
    {"id": 3, "name": "Mechanical Keyboard", "price": 89.99, "stock": 75},
    {"id": 4, "name": "4K Monitor", "price": 449.99, "stock": 30},
    {"id": 5, "name": "USB-C Hub", "price": 49.99, "stock": 200},
]


@app.get("/health")
def health():
    return {"status": "ok", "service": "database-svc", "version": VERSION, "pod": HOSTNAME}


@app.get("/products")
def get_products():
    return {
        "products": PRODUCTS,
        "served_by": HOSTNAME,
        "version": VERSION,
    }


@app.get("/products/{product_id}")
def get_product(product_id: int):
    for p in PRODUCTS:
        if p["id"] == product_id:
            return {"product": p, "served_by": HOSTNAME, "version": VERSION}
    return {"error": "not found"}, 404
