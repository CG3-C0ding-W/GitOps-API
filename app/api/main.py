from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FASTAPI(title="myapp-api")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

ITEMS = [
    {"id": 1, "name": "Widget"}, 
    {"id": 2, "name": "Gadget"},
    {"id": 3, "name": "Gizmo"},
]

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/api/items")
def list_items():
    return ITEMS