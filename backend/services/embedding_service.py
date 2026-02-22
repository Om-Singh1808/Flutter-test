"""
embedding_service.py
Singleton sentence-transformers model — loaded once at import time.
"""

from typing import List

from sentence_transformers import SentenceTransformer

# ---------------------------------------------------------------------------
# Model loaded once at module import so every request re-uses the same object.
# all-MiniLM-L6-v2 is fast, lightweight, and gives good semantic quality.
# ---------------------------------------------------------------------------
_MODEL_NAME = "all-MiniLM-L6-v2"
print(f"[embedding_service] Loading model '{_MODEL_NAME}' …")
_model = SentenceTransformer(_MODEL_NAME)
print(f"[embedding_service] Model loaded successfully.")


def generate_embeddings(chunks: List[str]) -> List[List[float]]:
    """
    Encodes a list of text chunks into dense float vectors.

    Args:
        chunks: List of non-empty text strings.

    Returns:
        List of embedding vectors (each a List[float]).
        Maintains the same order as the input chunks.
    """
    if not chunks:
        return []

    print(
        f"[embedding_service] Generating embeddings for {len(chunks)} chunk(s) …")
    # encode() returns a numpy ndarray; convert to plain Python lists for JSON-safety.
    embeddings_np = _model.encode(chunks, show_progress_bar=False)
    embeddings: List[List[float]] = embeddings_np.tolist()
    print(
        f"[embedding_service] Embeddings generated. Dimensionality: {len(embeddings[0])}.")
    return embeddings
