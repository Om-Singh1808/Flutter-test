"""
main.py — FastAPI entry-point for the PDF memory ingestion service.

Run with:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

import os
import shutil
import tempfile
import uuid
from typing import Any, Dict

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from services.pdf_processor import process_pdf
from services.document_processor import process_document
from services.embedding_service import generate_embeddings
from services.vector_store import store_document

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
app = FastAPI(
    title="PDF Memory Ingestion API",
    description="Ingest PDFs into a persistent ChromaDB vector store for semantic memory.",
    version="1.0.0",
)

# Allow requests from any origin so the Flutter app (any host/port) can reach us.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
@app.get("/health")
def health_check() -> Dict[str, str]:
    """Simple liveness probe."""
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# PDF upload endpoint — the core ingestion pipeline
# ---------------------------------------------------------------------------
@app.post("/upload_pdf")
async def upload_pdf(file: UploadFile = File(...)) -> Dict[str, Any]:
    """
    Accepts a multipart PDF upload, runs the full ingestion pipeline, and
    stores embeddings in ChromaDB.

    Field name : file
    Content-Type: multipart/form-data
    Accepted MIME: application/pdf

    Returns:
        {
            "status": "success",
            "document_id": "<uuid>",
            "chunks_stored": <int>
        }
    """
    # ── 1. Validate file type ──────────────────────────────────────────────
    if file.content_type not in ("application/pdf", "application/octet-stream"):
        if not (file.filename or "").lower().endswith(".pdf"):
            raise HTTPException(
                status_code=400,
                detail="Only PDF files are accepted. Please upload a .pdf file.",
            )

    print(
        f"\n[main] PDF received: '{file.filename}' (content-type: {file.content_type})")

    # ── 2. Save to a temp file ─────────────────────────────────────────────
    tmp_path: str = ""
    try:
        suffix = ".pdf"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            shutil.copyfileobj(file.file, tmp)
            tmp_path = tmp.name
        print(f"[main] Saved temp file: {tmp_path}")

        # ── 3. Extract text + chunk ────────────────────────────────────────
        chunks = process_pdf(tmp_path)
        if not chunks:
            raise HTTPException(
                status_code=422,
                detail="No text could be extracted from the uploaded PDF. "
                       "The file may be scanned/image-only.",
            )
        print(f"[main] Chunks created: {len(chunks)}")

        # ── 4. Generate embeddings ─────────────────────────────────────────
        embeddings = generate_embeddings(chunks)
        print(f"[main] Embeddings generated: {len(embeddings)}")

        # ── 5. Assign document ID and persist in vector DB ─────────────────
        document_id = str(uuid.uuid4())
        store_document(document_id, chunks, embeddings)
        print(f"[main] Stored in vector DB — document_id: {document_id}")

    finally:
        # ── 6. Clean up temp file ──────────────────────────────────────────
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)
            print(f"[main] Temp file removed: {tmp_path}")

    return {
        "status": "success",
        "document_id": document_id,
        "chunks_stored": len(chunks),
    }


# ---------------------------------------------------------------------------
# Multi-format document upload endpoint — PDF, DOCX, PPTX
# ---------------------------------------------------------------------------
_ALLOWED_EXTENSIONS = {".pdf", ".docx", ".pptx"}
_EXTENSION_CONTENT_TYPES = {
    ".pdf":  {"application/pdf", "application/octet-stream"},
    ".docx": {
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/octet-stream",
    },
    ".pptx": {
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "application/octet-stream",
    },
}


@app.post("/upload_document")
async def upload_document(file: UploadFile = File(...)) -> Dict[str, Any]:
    """
    Accepts a multipart document upload (PDF / DOCX / PPTX), runs the full
    ingestion pipeline, and stores embeddings in ChromaDB.

    Field name : file
    Content-Type: multipart/form-data
    Accepted types: .pdf, .docx, .pptx

    Returns:
        {
            "status": "success",
            "document_id": "<uuid>",
            "chunks_stored": <int>
        }
    """
    # ── 1. Determine file extension and validate ───────────────────────────
    filename = (file.filename or "").lower()
    file_ext = os.path.splitext(filename)[1]  # e.g. ".pdf"

    if file_ext not in _ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Unsupported file type '{file_ext}'. "
                "Accepted: .pdf, .docx, .pptx"
            ),
        )

    print(
        f"\n[main] Document received: '{file.filename}' "
        f"(ext={file_ext}, content-type: {file.content_type})"
    )

    # ── 2. Save to a temp file (preserve extension so parsers work) ────────
    tmp_path: str = ""
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as tmp:
            shutil.copyfileobj(file.file, tmp)
            tmp_path = tmp.name
        print(f"[main] Saved temp file: {tmp_path}")

        # ── 3. Extract text + chunk ────────────────────────────────────────
        chunks = process_document(tmp_path, file_ext)
        if not chunks:
            raise HTTPException(
                status_code=422,
                detail="No text could be extracted from the uploaded file.",
            )
        print(f"[main] Chunks created: {len(chunks)}")

        # ── 4. Generate embeddings ─────────────────────────────────────────
        embeddings = generate_embeddings(chunks)
        print(f"[main] Embeddings generated: {len(embeddings)}")

        # ── 5. Assign document ID and persist in vector DB ─────────────────
        document_id = str(uuid.uuid4())
        store_document(document_id, chunks, embeddings)
        print(f"[main] Stored in vector DB — document_id: {document_id}")

    finally:
        # ── 6. Clean up temp file ──────────────────────────────────────────
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)
            print(f"[main] Temp file removed: {tmp_path}")

    return {
        "status": "success",
        "document_id": document_id,
        "chunks_stored": len(chunks),
    }
