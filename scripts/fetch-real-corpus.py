"""Download fixed official WIT sources as test data, never execute upstream code."""
import concurrent.futures
import hashlib
import io
import json
import pathlib
import sys
import urllib.request
import zipfile

PINS = [
    ("wasi-cli-v0.2.0", "WebAssembly/wasi-cli", "6ae82617096e83e6606047736e84ac397b788631", "5c5e4397e0586b9532454cdb94826e2a34b9873ebe8a42b60cf29f8c722cd28d"),
    ("wasi-cli-v0.2.1", "WebAssembly/wasi-cli", "0598519dac2e46db4f3671bcb90f284919ea6e0e", "070ae9ecd724fb836f3bc58294c526b8ff67d07f08b716cd8e5677e1dbae02be"),
    ("wasi-random-v0.2.0", "WebAssembly/wasi-random", "10ba8d44f22a1dd605c937f687013c90b5fec942", "26702a5bd31e198b5a735e3dc796cc9f4790e725f8386c88193456b42f35c1ad"),
    ("wasi-random-v0.2.1", "WebAssembly/wasi-random", "e896b4b1cae527474d4413cd38d1eb63341f127b", "8b40e911c3c284839e925e49d7da036885ed406dc472a6ee0d1db56ab842c409"),
]


def fetch(root, pin):
    label, repo, commit, expected = pin
    url = f"https://codeload.github.com/{repo}/zip/{commit}"
    req = urllib.request.Request(url, headers={"User-Agent": "WITProbe-verification"})
    with urllib.request.urlopen(req, timeout=90) as response:
        data = response.read(20 * 1024 * 1024 + 1)
    archive_hash = hashlib.sha256(data).hexdigest()
    if len(data) > 20 * 1024 * 1024 or archive_hash != expected:
        raise RuntimeError(f"Archive size/hash mismatch: {label}; nothing was extracted")
    (root / "work" / (label + ".zip")).write_bytes(data)
    destination = root / "corpus" / label
    destination.mkdir(parents=True, exist_ok=False)
    files = []
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for entry in archive.infolist():
            rel = pathlib.PurePosixPath(entry.filename)
            if rel.is_absolute() or ".." in rel.parts:
                raise RuntimeError("Unsafe archive path")
            rel = pathlib.Path(*rel.parts[1:])
            if entry.is_dir() or not rel.parts:
                continue
            target = destination / rel
            if not target.resolve().is_relative_to(destination.resolve()):
                raise RuntimeError("Archive path escapes destination")
            target.parent.mkdir(parents=True, exist_ok=True)
            content = archive.read(entry)
            target.write_bytes(content)
            files.append({"path": rel.as_posix(), "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()})
    return {"label": label, "repository": f"https://github.com/{repo}", "commit": commit,
            "url": url, "archive_sha256": archive_hash, "archive_bytes": len(data), "files": files}


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/fetch-real-corpus.py NEW_D_DIRECTORY")
    root = pathlib.Path(sys.argv[1]).resolve()
    if root.drive.upper() != "D:" or root.exists():
        raise SystemExit("Choose a new D: directory; existing evidence is preserved")
    (root / "work").mkdir(parents=True, exist_ok=False)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(lambda pin: fetch(root, pin), PINS))
    (root / "corpus-manifest.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    print(f"Fetched and verified {len(rows)} official source snapshots: {root / 'corpus'}")


if __name__ == "__main__":
    main()
