---
name: read-pdf-comments
description: Extract reviewer comments/annotations from a PDF as clean Markdown. Use when the user wants to read, list, or act on the comments, highlights, sticky notes, or markup in a reviewed PDF (for example paper reviews). Requires PyMuPDF (pip install pymupdf).
---

This skill bundles `pdf-comments`, a PyMuPDF-based extractor that prints a PDF's
annotations as readable Markdown (or JSON with `--json`).

## Requirement

PyMuPDF must be installed: `pip install pymupdf`. If it is missing, the script
exits with an error telling you so.

## Usage

Run the bundled script with the PDF path:

    python3 <skill-dir>/pdf-comments <file.pdf>            # Markdown to stdout
    python3 <skill-dir>/pdf-comments <file.pdf> --json     # structured JSON
    python3 <skill-dir>/pdf-comments <file.pdf> -o notes.md

`<skill-dir>` is this skill's base directory (printed when the skill loads).
