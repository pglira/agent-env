---
name: archive-paper
description: Rename a scientific paper to a canonical filename, file it in the right subdirectory of the literature library, and write a companion BibTeX file. Use when the user wants to archive, file, or add a paper/PDF to their literature collection.
argument-hint: "path to the paper file (e.g. ~/Downloads/paper.pdf)"
---

Archive a scientific paper into the user's literature library. This replaces the old
`archive-paper.sh` GUI script: instead of asking the user to fill in a form, read the
paper and the BibTeX yourself, propose values, and let the user correct them.

## Inputs

- **Source file**: the path passed as the argument. If none was given, ask for it.
- **Library root**: `$LITERATUREDIR` if set, otherwise `/data1/Dropbox/Literatur`.

If the source file does not exist, stop and report it.

## Procedure

1. **Read the paper.** For a PDF, extract its text (e.g. `pdftotext "<file>" -` or read the
   first pages) and metadata (`pdfinfo "<file>"`). From this, determine:
   - **first author** — surname of the first author only (optional)
   - **year** — publication year (optional)
   - **type** — short tag for the kind of document. Only set it for `BOOK`, `MANUAL`,
     `THESIS`, or `REPORT`. Leave it empty for journal articles, conference papers, and
     anything unclear.
   - **title** — the paper's title (mandatory)

2. **Find the BibTeX.** Look for a citation. If the PDF or a sidecar file contains one, use
   it. Otherwise search the web (Google Scholar / Semantic Scholar / Crossref by DOI or
   title) for the entry. If you cannot find a reliable one, proceed without a `.bib` file and
   say so.

3. **Choose the target subdirectory.** List the immediate subdirectories of the library root
   (`ls -d "$LITERATUREDIR"/*/`) and propose the best-matching one based on the paper's topic.

4. **Confirm with the user.** Present the proposed first author, year, type, title, target
   subdirectory, and the BibTeX. Let the user correct anything before you write. Treat the
   metadata as a proposal, not a decision.

5. **Build the canonical filename.** Assemble the basename from the parts that are present, in
   this exact order (this matches the original script — note the **uppercasing**):

   - first author, uppercased, followed by a space — if given
   - year, followed by a space — if given
   - `- ` (dash + space) — if author **or** year is present
   - type, uppercased, followed by ` - ` — if given
   - title, uppercased

   Sanitize the title first: replace every character that is **not** in `A-Za-z0-9. _-` with
   an underscore (`_`). Keep the source file's extension.

   The `.bib` file shares the same basename, with a `.bib` extension.

   Examples (library subdir `JOURNALS`):
   | author | year | type | title | result |
   |---|---|---|---|---|
   | smith | 2020 | thesis | Deep Learning for Lidar | `SMITH 2020 - THESIS - DEEP LEARNING FOR LIDAR.pdf` |
   | smith | 2020 | — | Deep Learning for Lidar | `SMITH 2020 - DEEP LEARNING FOR LIDAR.pdf` |
   | — | — | — | Deep Learning for Lidar | `DEEP LEARNING FOR LIDAR.pdf` |

6. **Place the file.** The target path is `<target subdir>/<basename>.<ext>`. If a file already
   exists at that path, stop and report it — never overwrite. Otherwise `mv` the source there
   (always move, never copy).

7. **Write the BibTeX.** If you have a citation, write it to the matching `.bib` path next to
   the paper. Always rewrite the citation key to the format `<author><year><letter>`: the
   lowercased first-author surname, the year, and a trailing lowercase letter (default `a`,
   e.g. `glira2026a`; use `b`, `c`, … only to avoid a clash). Then format it with
   `latexindent -w "<bibfile>"` if `latexindent` is available (the original script used it).
   If `latexindent` is missing, leave the file unformatted and mention it.

## Output

Report the final paper path and the `.bib` path (or that none was written).
