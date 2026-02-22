"""
pdf_processor.py
Extracts text from a PDF file using a 3-stage pipeline:
  1. pypdf         — instant text-layer extraction (digital PDFs)
  2. pdf2image + pytesseract — full-page OCR fallback (scanned / image-only PDFs)
  3. pypdf image extraction + pytesseract — OCR on every embedded image in the PDF

All text from the three stages is combined, de-duplicated, and split into
overlapping chunks ready for embedding.
"""

from __future__ import annotations

import io
import re
from typing import List

import pypdf
import pytesseract
from PIL import Image

# ── System binary paths ───────────────────────────────────────────────────────
# Tesseract-OCR installed by the UB-Mannheim installer (silent /S)
_TESSERACT_CMD = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# Poppler extracted to D:\poppler (required by pdf2image)
_POPPLER_PATH = r"D:\poppler\poppler-24.08.0\Library\bin"

# Configure pytesseract once at import time
pytesseract.pytesseract.tesseract_cmd = _TESSERACT_CMD


# ── Optional lazy import for pdf2image ───────────────────────────────────────
# pdf2image requires poppler on the system PATH.
# It is imported lazily so a missing system dep gives a clear error message.


def _import_pdf2image():
    try:
        from pdf2image import convert_from_path
        return convert_from_path
    except ImportError:
        raise RuntimeError(
            "pdf2image is not installed. Run: pip install pdf2image"
        )


# ── Chunking config ───────────────────────────────────────────────────────────
_CHUNK_SIZE = 500
_CHUNK_OVERLAP = 50


# ═════════════════════════════════════════════════════════════════════════════
# Stage 1 — pypdf text-layer extraction
# ═════════════════════════════════════════════════════════════════════════════

def _extract_text_native(reader: pypdf.PdfReader) -> str:
    """
    Fast path: pull the text layer that PDF authoring tools embed.
    Works perfectly for digitally-created PDFs; returns '' for scanned ones.
    """
    pages: List[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        if text.strip():
            pages.append(text)
    raw = "\n".join(pages)
    return re.sub(r"\s+", " ", raw).strip()


# ═════════════════════════════════════════════════════════════════════════════
# Stage 2 — full-page OCR (scanned PDFs)
# ═════════════════════════════════════════════════════════════════════════════

def _extract_text_ocr(file_path: str) -> str:
    """
    Converts every PDF page to a raster image and runs Tesseract OCR on it.
    This is the primary path for DocScanner-style scanned documents.
    """
    convert_from_path = _import_pdf2image()

    print("[pdf_processor] Running page-level OCR via pdf2image + pytesseract …")
    pages = convert_from_path(file_path, dpi=300, poppler_path=_POPPLER_PATH)
    texts: List[str] = []

    for i, page_img in enumerate(pages):
        text = pytesseract.image_to_string(page_img, lang="eng")
        text = text.strip()
        if text:
            print(f"[pdf_processor]   OCR page {i + 1}: {len(text)} chars")
            texts.append(text)
        else:
            print(f"[pdf_processor]   OCR page {i + 1}: no text detected")

    combined = "\n".join(texts)
    return re.sub(r"\s+", " ", combined).strip()


# ═════════════════════════════════════════════════════════════════════════════
# Stage 3 — embedded image extraction + OCR
# ═════════════════════════════════════════════════════════════════════════════

def _extract_images_text(reader: pypdf.PdfReader) -> str:
    """
    Iterates over every image embedded inside the PDF (charts, photos, figures)
    and runs Tesseract OCR on each one.

    Returns a concatenated string of all text found inside embedded images.
    Image-only PDFs (where the *page* is an image, not an embedded resource)
    are handled by Stage 2; this stage targets images *within* a mixed PDF.
    """
    image_texts: List[str] = []
    total_images = 0

    for page_num, page in enumerate(reader.pages):
        try:
            images = page.images   # pypdf ≥ 3.x
        except Exception:
            continue

        for img_obj in images:
            total_images += 1
            try:
                pil_img = Image.open(io.BytesIO(img_obj.data)).convert("RGB")
                text = pytesseract.image_to_string(pil_img, lang="eng").strip()
                if text:
                    image_texts.append(text)
                    print(
                        f"[pdf_processor]   Embedded image (page {page_num + 1} "
                        f"'{img_obj.name}'): {len(text)} chars"
                    )
            except Exception as exc:
                print(
                    f"[pdf_processor]   Skipping embedded image on page "
                    f"{page_num + 1}: {exc}"
                )

    if total_images:
        print(
            f"[pdf_processor] Processed {total_images} embedded image(s), "
            f"found text in {len(image_texts)}."
        )

    combined = "\n".join(image_texts)
    return re.sub(r"\s+", " ", combined).strip()


# ═════════════════════════════════════════════════════════════════════════════
# Chunking
# ═════════════════════════════════════════════════════════════════════════════

def _split_into_chunks(text: str, chunk_size: int = _CHUNK_SIZE, overlap: int = _CHUNK_OVERLAP) -> List[str]:
    """
    Sliding-window splitter.
    step = chunk_size - overlap  →  consecutive chunks share `overlap` characters.
    """
    if not text:
        return []

    step = chunk_size - overlap
    chunks: List[str] = []
    start = 0

    while start < len(text):
        chunk = text[start: start + chunk_size].strip()
        if chunk:
            chunks.append(chunk)
        start += step

    return chunks


# ═════════════════════════════════════════════════════════════════════════════
# Public entry-point
# ═════════════════════════════════════════════════════════════════════════════

def process_pdf(file_path: str) -> List[str]:
    """
    Runs the 3-stage extraction pipeline and returns overlapping text chunks.

    Stage 1 — pypdf native text  (fast, works for digital PDFs)
    Stage 2 — page-level OCR     (fallback for fully-scanned PDFs)
    Stage 3 — embedded image OCR (picks up text inside charts / figures)

    Stages 2 and 3 always run regardless of Stage 1 to capture any additional
    information not in the text layer.

    Args:
        file_path: Absolute path to the PDF file.

    Returns:
        List of non-empty string chunks, or [] if nothing could be extracted.
    """
    reader = pypdf.PdfReader(file_path)
    parts: List[str] = []

    # ── Stage 1: native text layer ────────────────────────────────────────────
    print(f"[pdf_processor] Stage 1 — native text extraction: {file_path}")
    native_text = _extract_text_native(reader)
    if native_text:
        print(f"[pdf_processor] Stage 1 extracted {len(native_text)} chars.")
        parts.append(native_text)
    else:
        print("[pdf_processor] Stage 1: no text layer found (scanned PDF).")

    # ── Stage 2: page-level OCR (always attempt for scanned content) ──────────
    print("[pdf_processor] Stage 2 — page-level OCR …")
    try:
        ocr_text = _extract_text_ocr(file_path)
        if ocr_text:
            print(
                f"[pdf_processor] Stage 2 extracted {len(ocr_text)} chars via OCR.")
            parts.append(ocr_text)
        else:
            print("[pdf_processor] Stage 2: OCR found no text.")
    except RuntimeError as e:
        print(f"[pdf_processor] Stage 2 skipped — {e}")

    # ── Stage 3: embedded image OCR ───────────────────────────────────────────
    print("[pdf_processor] Stage 3 — embedded image OCR …")
    try:
        img_text = _extract_images_text(reader)
        if img_text:
            print(
                f"[pdf_processor] Stage 3 extracted {len(img_text)} chars from images.")
            parts.append(img_text)
        else:
            print("[pdf_processor] Stage 3: no text found in embedded images.")
    except RuntimeError as e:
        print(f"[pdf_processor] Stage 3 skipped — {e}")

    # ── Combine & chunk ───────────────────────────────────────────────────────
    combined = re.sub(r"\s+", " ", " ".join(parts)).strip()

    if not combined:
        print("[pdf_processor] ERROR: No text could be extracted from the PDF.")
        return []

    chunks = _split_into_chunks(combined)
    print(
        f"[pdf_processor] Total: {len(combined)} chars → "
        f"{len(chunks)} chunks (size={_CHUNK_SIZE}, overlap={_CHUNK_OVERLAP})."
    )
    return chunks
