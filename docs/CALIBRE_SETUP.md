# Calibre Library Setup for Seedbox Environments

This guide explains how to initialize a Calibre library on a shared seedbox
(such as [ultra.cc](https://ultra.cc)) so that **Calibre-Web** can connect to
it. No root or sudo access is required.

---

## Background

Calibre-Web needs a valid Calibre library — specifically a `metadata.db` SQLite
file — to function. If you point Calibre-Web at a folder that does not already
contain this file, it will reject the path with:

```
New db location is invalid, please enter valid path
```

The script in this repository automates the creation of that file.

---

## Quick Start

### 1. SSH into your seedbox

```bash
ssh usb364@<your-seedbox-hostname>
```

### 2. Create the library directory (if it doesn't exist)

```bash
mkdir -p /home/usb364/media/Books/eBooks
```

### 3. Run the initialization script

Copy `scripts/init-calibre-library.sh` to your seedbox (via SFTP or `wget`),
then run it:

```bash
bash init-calibre-library.sh /home/usb364/media/Books/eBooks
```

The script will:

1. Create the directory (if missing).
2. Try to use **calibredb** (Calibre's CLI) — the preferred method.
3. Fall back to **calibre-debug** Python bindings.
4. Fall back to creating a minimal `metadata.db` via **Python 3 + sqlite3**
   (no Calibre installation required).

### 4. Verify

```bash
ls -lh /home/usb364/media/Books/eBooks/metadata.db
```

You should see a file of at least a few kilobytes.

### 5. Configure Calibre-Web

1. Open Calibre-Web in your browser.
2. Enter the library path:
   ```
   /home/usb364/media/Books/eBooks
   ```
3. Click **Save**. Calibre-Web should now accept the path.

---

## ultra.cc Specific Steps

ultra.cc provides Calibre as an installable app that can initialize the
library for you without requiring SSH:

1. Log in to your **ultra.cc UCP** (User Control Panel).
2. Go to **Apps**.
3. Find **Calibre** and click **Install** / **Start**.
4. After Calibre starts, it will auto-create `metadata.db` in your library
   folder (usually configurable during install).
5. Restart **Calibre-Web** and point it at the same folder.

If Calibre is already installed but the database is missing, run the
initialization script via SSH (see Quick Start above).

---

## Manual Fallback: Create the Library on Your PC

If neither SSH nor the ultra.cc Calibre app is available:

1. **Download Calibre** for your OS from <https://calibre-ebook.com/download>.
2. Open Calibre → **Calibre Library** → **Switch/create library**.
3. Create a new, empty library in any local folder.
4. Upload **only** the `metadata.db` file to your seedbox via SFTP:
   - Local: `<local-library-folder>/metadata.db`
   - Remote: `/home/usb364/media/Books/eBooks/metadata.db`

---

## Permissions Reference

| Path                                         | Recommended permissions |
|----------------------------------------------|------------------------|
| `/home/usb364/media/Books/eBooks/`           | `755` (drwxr-xr-x)    |
| `/home/usb364/media/Books/eBooks/metadata.db`| `644` (-rw-r--r--)    |

The initialization script sets these permissions automatically.

To set them manually:

```bash
chmod 755 /home/usb364/media/Books/eBooks
chmod 644 /home/usb364/media/Books/eBooks/metadata.db
```

---

## Customising the Library Path

The library path is configurable — simply pass it as the first argument to the
script:

```bash
bash init-calibre-library.sh /home/usb364/media/Books/eBooks
```

Replace `/home/usb364/media/Books/eBooks` with whatever path you prefer. The
script will create the directory if it does not already exist.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `New db location is invalid` in Calibre-Web | `metadata.db` missing | Run the init script |
| `Permission denied` when LazyLibrarian creates folders | Path missing leading `/` | Prefix the path with `/`, e.g. `/home/usb364/…` instead of `home/usb364/…` |
| Script exits with *"None of the following were found"* | No Calibre or Python on the server | Install Python 3 or use the PC fallback above |
| `metadata.db` exists but Calibre-Web still rejects the path | File is empty or corrupt | Delete `metadata.db` and re-run the script |

---

## Related Services

- **Calibre**: <https://calibre-ebook.com/>
- **Calibre-Web**: <https://github.com/janeczku/calibre-web>
- **LazyLibrarian**: <https://lazylibrarian.gitlab.io/>
