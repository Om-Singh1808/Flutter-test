"""
vector_store.py
ChromaDB persistent client — initialised once at module import.
"""

import os
from datetime import datetime, timezone
from typing import Any, Dict, List

import chromadb
from chromadb.config import Settings

# ---------------------------------------------------------------------------
# Resolve the storage path relative to this file's location so it works
# regardless of the working directory the server is started from.
# ---------------------------------------------------------------------------
_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_VECTOR_DB_PATH = os.path.join(_BASE_DIR, "data", "vector_db")
_COLLECTION_NAME = "pdf_memory"

print(f"[vector_store] Initialising ChromaDB at: {_VECTOR_DB_PATH}")
_client = chromadb.PersistentClient(path=_VECTOR_DB_PATH)
_collection = _client.get_or_create_collection(
    name=_COLLECTION_NAME,
    metadata={"hnsw:space": "cosine"},  # cosine similarity for semantic search
)
print(
    f"[vector_store] Collection '{_COLLECTION_NAME}' ready ({_collection.count()} existing chunks).")


def store_document(
    document_id: str,
    chunks: List[str],
    embeddings: List[List[float]],
) -> None:
    """
    Stores chunks and their pre-computed embeddings in ChromaDB.

    Each chunk gets a stable, unique ID: "{document_id}_chunk_{index}".
    Metadata includes the original chunk text and an ISO-8601 timestamp.

    Args:
        document_id: UUID string identifying the parent document.
        chunks:      List of text chunks (same order as embeddings).
        embeddings:  List of embedding vectors (one per chunk).
    """
    if not chunks:
        print("[vector_store] No chunks to store — skipping.")
        return

    timestamp = datetime.now(timezone.utc).isoformat()

    ids: List[str] = []
    metadatas: List[Dict[str, Any]] = []

    for i, chunk_text in enumerate(chunks):
        ids.append(f"{document_id}_chunk_{i}")
        metadatas.append(
            {
                "document_id": document_id,
                "chunk_text": chunk_text,      # stored for retrieval without re-query
                "chunk_index": i,
                "timestamp": timestamp,
            }
        )

    _collection.add(
        ids=ids,
        embeddings=embeddings,
        documents=chunks,
        metadatas=metadatas,
    )

    print(
        f"[vector_store] Stored {len(chunks)} chunk(s) for document_id='{document_id}'. "
        f"Collection total: {_collection.count()} chunks."
    )


def query_similar(
    text: str,
    top_k: int = 5,
) -> List[Dict[str, Any]]:
    """
    Semantic similarity search — reserved for the future LLM retrieval phase.

    Args:
        text:  Query string to embed and search against.
        top_k: Maximum number of results to return.

    Returns:
        List of dicts with keys: chunk_text, document_id, timestamp, distance.
    """
    from services.embedding_service import generate_embeddings  # local import avoids circular

    query_embedding = generate_embeddings([text])[0]

    results = _collection.query(
        query_embeddings=[query_embedding],
        n_results=min(top_k, _collection.count()),
        include=["metadatas", "distances"],
    )

    output: List[Dict[str, Any]] = []
    for meta, dist in zip(results["metadatas"][0], results["distances"][0]):
        output.append(
            {
                "chunk_text": meta.get("chunk_text", ""),
                "document_id": meta.get("document_id", ""),
                "timestamp": meta.get("timestamp", ""),
                "distance": dist,
            }
        )

    return output
