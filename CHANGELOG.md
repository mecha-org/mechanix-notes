# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0+2] - 2026-11-16

- **Standalone Tantivy Index & Clean Markdown Storage**:
  - Replaced the ObjectBox database with Tantivy as the single search and metadata index; Markdown (`.md`) files are the sole source of truth.
- **Live Folder Sync & Directory Watching**:
  - Added real-time directory watching to automatically reflect external file creations, modifications, renames, and deletions without app restarts.
  - Handles external file renames seamlessly while notes are actively open in the editor.
- **Automatic Reindexing & Self-Healing Index Recovery**:
  - Automatically rebuilds the entire Tantivy index from on-disk `.md` files if the index directory is deleted, missing, or corrupted.
  - Performs startup reconciliation to detect external changes, purge deleted ghost notes, and index newly added files.

## [1.0.0+1] - 2026-10-14

- **Live Markdown Editor**:
  - Replaced the Flutter Quill rich-text editor with a native live Markdown editor (`live_markdown_editor`).
  - Added markdown formatting toolbar controls for headings, bold, italics, strikethrough, links, blockquotes, and code blocks.
- **Plain Markdown Filesystem Storage**:
  - Migrated note content storage from database records to human-readable `.md` files in `~/Documents/notes` (or `$XDG_DOCUMENTS_DIR/notes`).
  - Added `NoteFileStorage` service supporting atomic writes (via temporary files), filename sanitization from note titles, and duplicate filename resolution.
  - Updated `NoteModel` in ObjectBox to store `fileName` mappings while keeping ObjectBox for fast metadata queries.
- **Fast Full-Text Search**:
  - Integrated Rust-based Tantivy search library via `flutter_tantivy` for indexed, instant full-text search across note titles and content.
- **Organization & Note Management**:
  - Added chronological note grouping (Today, Yesterday, Last 7 Days, This Month, Last Month, etc.).
  - Added note pinning support (`isPinned`) to keep important notes at the top.
  - Added swipe-to-delete action on note cards.
- **Localization**:
  - Added internationalization (`l10n`) infrastructure with English localization strings.
