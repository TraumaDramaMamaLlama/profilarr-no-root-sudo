#!/bin/bash
# =============================================================================
# Calibre Library Initializer
# =============================================================================
# Creates a Calibre library (metadata.db) at a given path without requiring
# root or sudo access. Designed for use on shared seedbox environments such as
# ultra.cc where Calibre-Web needs an existing library to connect to.
#
# Usage:
#   bash init-calibre-library.sh [LIBRARY_PATH]
#
# Examples:
#   bash init-calibre-library.sh
#   bash init-calibre-library.sh /home/usb364/media/Books/eBooks
#
# The LIBRARY_PATH defaults to ~/media/Books/eBooks when not specified.
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

LIBRARY_PATH="${1:-${HOME}/media/Books/eBooks}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERROR] $*" >&2; }

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

info "Calibre library path: $LIBRARY_PATH"

# Create directory structure (no sudo required)
mkdir -p "$LIBRARY_PATH"
chmod 755 "$LIBRARY_PATH"
info "Directory ready."

# Skip if a library already exists
if [ -f "$LIBRARY_PATH/metadata.db" ]; then
    ok "A Calibre library already exists at '$LIBRARY_PATH'."
    ok "metadata.db is present — no initialization needed."
    exit 0
fi

# ---------------------------------------------------------------------------
# Method 1: calibredb (preferred — uses Calibre's own tooling)
# ---------------------------------------------------------------------------

if command -v calibredb > /dev/null 2>&1; then
    info "calibredb found. Initializing library with calibredb..."
    # Running 'list' against an empty path forces Calibre to create metadata.db
    calibredb --with-library="$LIBRARY_PATH" list > /dev/null 2>&1 || true
    if [ -f "$LIBRARY_PATH/metadata.db" ]; then
        chmod 644 "$LIBRARY_PATH/metadata.db"
        ok "Library initialized successfully with calibredb."
        exit 0
    fi
    warn "calibredb did not create metadata.db — trying next method."
fi

# ---------------------------------------------------------------------------
# Method 2: calibre-debug Python bindings
# ---------------------------------------------------------------------------

if command -v calibre-debug > /dev/null 2>&1; then
    info "calibre-debug found. Initializing library via Python bindings..."
    calibre-debug -c "
from calibre.library import db as calibre_db
calibre_db('$LIBRARY_PATH').new_api
print('done')
" > /dev/null 2>&1 || true
    if [ -f "$LIBRARY_PATH/metadata.db" ]; then
        chmod 644 "$LIBRARY_PATH/metadata.db"
        ok "Library initialized successfully with calibre-debug."
        exit 0
    fi
    warn "calibre-debug did not create metadata.db — trying next method."
fi

# ---------------------------------------------------------------------------
# Method 3: Pure Python + sqlite3 (fallback — no Calibre installation needed)
# ---------------------------------------------------------------------------
# Creates the minimal schema expected by Calibre-Web so it can connect and
# start managing books. The schema mirrors the one produced by Calibre itself.

PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" > /dev/null 2>&1; then
        PYTHON="$candidate"
        break
    fi
done

if [ -n "$PYTHON" ]; then
    info "Using $PYTHON to create a minimal Calibre library database..."
    LIBRARY_PATH="$LIBRARY_PATH" "$PYTHON" - << 'PYEOF'
import os
import sqlite3

library_path = os.environ["LIBRARY_PATH"]
db_path = os.path.join(library_path, "metadata.db")

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# --- Core schema (subset used by Calibre-Web) ----------------------------

cur.executescript("""
PRAGMA user_version = 25;

CREATE TABLE IF NOT EXISTS books (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    title       TEXT     NOT NULL DEFAULT 'Unknown',
    sort        TEXT,
    timestamp   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pubdate     TIMESTAMP DEFAULT '0101-01-01 00:00:00+00:00',
    series_index REAL    NOT NULL DEFAULT 1.0,
    author_sort TEXT,
    isbn        TEXT     DEFAULT '',
    lccn        TEXT     DEFAULT '',
    path        TEXT     NOT NULL DEFAULT '',
    flags       INTEGER  NOT NULL DEFAULT 1,
    uuid        TEXT,
    has_cover   BOOL     DEFAULT 0,
    last_modified TIMESTAMP NOT NULL DEFAULT '2000-01-01 00:00:00+00:00'
);

CREATE TABLE IF NOT EXISTS authors (
    id     INTEGER PRIMARY KEY,
    name   TEXT    NOT NULL COLLATE NOCASE,
    sort   TEXT,
    link   TEXT    NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS books_authors_link (
    id     INTEGER PRIMARY KEY,
    book   INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    author INTEGER NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
    UNIQUE(book, author)
);

CREATE TABLE IF NOT EXISTS tags (
    id   INTEGER PRIMARY KEY,
    name TEXT    NOT NULL COLLATE NOCASE,
    UNIQUE(name)
);

CREATE TABLE IF NOT EXISTS books_tags_link (
    id   INTEGER PRIMARY KEY,
    book INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    tag  INTEGER NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    UNIQUE(book, tag)
);

CREATE TABLE IF NOT EXISTS publishers (
    id   INTEGER PRIMARY KEY,
    name TEXT    NOT NULL COLLATE NOCASE,
    sort TEXT,
    UNIQUE(name)
);

CREATE TABLE IF NOT EXISTS books_publishers_link (
    id        INTEGER PRIMARY KEY,
    book      INTEGER NOT NULL REFERENCES books(id)      ON DELETE CASCADE,
    publisher INTEGER NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    UNIQUE(book)
);

CREATE TABLE IF NOT EXISTS series (
    id   INTEGER PRIMARY KEY,
    name TEXT    NOT NULL COLLATE NOCASE,
    sort TEXT,
    UNIQUE(name)
);

CREATE TABLE IF NOT EXISTS books_series_link (
    id     INTEGER PRIMARY KEY,
    book   INTEGER NOT NULL REFERENCES books(id)   ON DELETE CASCADE,
    series INTEGER NOT NULL REFERENCES series(id)  ON DELETE CASCADE,
    UNIQUE(book)
);

CREATE TABLE IF NOT EXISTS ratings (
    id     INTEGER PRIMARY KEY,
    rating INTEGER CHECK(rating > -1 AND rating < 11),
    UNIQUE(rating)
);

CREATE TABLE IF NOT EXISTS books_ratings_link (
    id     INTEGER PRIMARY KEY,
    book   INTEGER NOT NULL REFERENCES books(id)   ON DELETE CASCADE,
    rating INTEGER NOT NULL REFERENCES ratings(id) ON DELETE CASCADE,
    UNIQUE(book)
);

CREATE TABLE IF NOT EXISTS languages (
    id   INTEGER PRIMARY KEY,
    lang_code TEXT NOT NULL COLLATE NOCASE,
    UNIQUE(lang_code)
);

CREATE TABLE IF NOT EXISTS books_languages_link (
    id         INTEGER PRIMARY KEY,
    book       INTEGER NOT NULL REFERENCES books(id)     ON DELETE CASCADE,
    lang_code  INTEGER NOT NULL REFERENCES languages(id) ON DELETE CASCADE,
    item_order INTEGER NOT NULL DEFAULT 0,
    UNIQUE(book)
);

CREATE TABLE IF NOT EXISTS identifiers (
    id   INTEGER PRIMARY KEY,
    book INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    type TEXT    NOT NULL DEFAULT 'isbn' COLLATE NOCASE,
    val  TEXT    NOT NULL COLLATE NOCASE,
    UNIQUE(book, type)
);

CREATE TABLE IF NOT EXISTS comments (
    id   INTEGER PRIMARY KEY,
    book INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    text TEXT    NOT NULL DEFAULT '',
    UNIQUE(book)
);

CREATE TABLE IF NOT EXISTS data (
    id     INTEGER PRIMARY KEY,
    book   INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    format TEXT    NOT NULL COLLATE NOCASE,
    uncompressed_size INTEGER NOT NULL,
    name   TEXT    NOT NULL,
    UNIQUE(book, format)
);

CREATE TABLE IF NOT EXISTS custom_columns (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    label        TEXT    NOT NULL,
    name         TEXT    NOT NULL,
    datatype     TEXT    NOT NULL,
    mark_links   BOOL    DEFAULT 0,
    editable     BOOL    DEFAULT 1,
    display      TEXT    NOT NULL DEFAULT '{}',
    is_multiple  BOOL    DEFAULT 0,
    normalized   BOOL    NOT NULL,
    UNIQUE(label)
);

CREATE TABLE IF NOT EXISTS preferences (
    id  INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT    NOT NULL,
    val TEXT    NOT NULL,
    UNIQUE(key)
);

CREATE TABLE IF NOT EXISTS library_id (
    id  INTEGER PRIMARY KEY,
    uuid TEXT NOT NULL,
    UNIQUE(uuid)
);

-- Required indexes
CREATE INDEX IF NOT EXISTS books_idx          ON books(sort COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS authors_idx        ON authors(sort COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS books_authors_link_aidx ON books_authors_link(author);
CREATE INDEX IF NOT EXISTS books_authors_link_bidx ON books_authors_link(book);
CREATE INDEX IF NOT EXISTS books_tags_link_tidx    ON books_tags_link(tag);
CREATE INDEX IF NOT EXISTS books_tags_link_bidx    ON books_tags_link(book);
CREATE INDEX IF NOT EXISTS data_idx           ON data(book);
""")

# Seed library_id with a stable UUID
import uuid as _uuid
try:
    cur.execute("INSERT OR IGNORE INTO library_id(id, uuid) VALUES (1, ?)",
                (_uuid.uuid4().hex,))
except Exception:
    pass

conn.commit()
conn.close()

print("metadata.db created at:", db_path)
PYEOF

    if [ -f "$LIBRARY_PATH/metadata.db" ]; then
        chmod 644 "$LIBRARY_PATH/metadata.db"
        ok "Library initialized successfully with Python sqlite3."
        exit 0
    fi
    warn "Python sqlite3 did not create metadata.db."
fi

# ---------------------------------------------------------------------------
# No suitable tool found
# ---------------------------------------------------------------------------

error "Could not initialize the Calibre library."
error "None of the following were found: calibredb, calibre-debug, python3, python."
error ""
error "Options:"
error "  1. Install Calibre on your server (check your seedbox control panel)."
error "  2. Create a library on your local PC using Calibre desktop, then"
error "     upload metadata.db to '$LIBRARY_PATH' via SFTP/file manager."
error "  3. Install Python 3 and re-run this script."
exit 1
