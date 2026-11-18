#!/usr/bin/env python3
"""Export an explicit allowlist of product source, never the working directory."""
import argparse
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIRECTORIES = (".github", "cmd", "native", "scripts", "docs")
ROOT_FILES = (".gitignore", "LICENSE", "README.md", "RELEASE_NOTES.md", "CONTRIBUTING.md", "SECURITY.md", "UPSTREAM.md", "go.mod", "install.sh", "install.ps1")
BLOCKED_NAMES = {"auth.json", "config.json", ".env", ".DS_Store"}
BLOCKED_PARTS = {".git", ".build", "node_modules", "__pycache__", "profiles", "desktop", "retired-launchers"}
SECRET_PATTERNS = [re.compile(rb"gh[pousr]_[A-Za-z0-9]{30,}"), re.compile(rb"github_pat_[A-Za-z0-9_]{30,}"),
                   re.compile(rb"sk-[A-Za-z0-9_-]{24,}"), re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")]


def source_files():
    files = [ROOT / name for name in ROOT_FILES if (ROOT / name).is_file()]
    for name in DIRECTORIES:
        files.extend(path for path in (ROOT / name).rglob("*") if path.is_file())
    result = []
    for path in sorted(files):
        rel = path.relative_to(ROOT)
        if path.is_symlink() or any(part in BLOCKED_PARTS for part in rel.parts):
            continue
        if path.name == ".DS_Store":
            continue
        if path.name in BLOCKED_NAMES or path.name.endswith((".pyc", ".db", ".sqlite", ".log", ".pem", ".key")):
            raise SystemExit(f"Blocked local-data file: {rel}")
        if rel == Path("cmd/multi-codex-app/assets/macos/MultiCodexHelper"):
            continue
        content = path.read_bytes()
        if any(pattern.search(content) for pattern in SECRET_PATTERNS):
            raise SystemExit(f"Potential credential in source: {rel}")
        private_home = str(Path.home()).encode()
        if private_home != b"/" and private_home in content:
            raise SystemExit(f"Local home path in source: {rel}")
        result.append((path, rel))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--zip", dest="archive", type=Path)
    args = parser.parse_args()
    files = source_files()
    if args.directory:
        dest = args.directory.resolve()
        if dest == ROOT or ROOT.is_relative_to(dest):
            raise SystemExit("Destination must not contain the project root")
        if dest.exists() and any(dest.iterdir()):
            raise SystemExit("Destination must be empty; existing repositories are never overwritten")
        dest.mkdir(parents=True, exist_ok=True)
        for path, rel in files:
            target = dest / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    if args.archive:
        args.archive.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.archive, "w", zipfile.ZIP_DEFLATED) as archive:
            for path, rel in files:
                archive.write(path, Path("multicodex-macos") / rel)
    print(f"Public source validated: {len(files)} files; no account data or local home paths.")


if __name__ == "__main__":
    main()
