"""Package exact game sources for the existing pinned Linux Godot runtime.

This is run from the trusted workflow checkout, never from the selected release.
It does not export Windows/macOS or execute scripts from the selected revision.
"""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile

ROOTS = ("project.godot", "main.tscn", "scripts", "shaders", "assets")
GODOT = "4.7.2"


def validate_identity(tag, commit):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,119}", tag) or tag == "najnowsza":
        raise ValueError("A versioned release tag is required")
    if not re.fullmatch(r"[a-f0-9]{40}", commit):
        raise ValueError("A full commit SHA is required")


def package(source, output, tag, commit):
    validate_identity(tag, commit)
    source, output = Path(source), Path(output)
    version = re.search(r'const VERSION\s*:?=\s*"([0-9A-Za-z.+_-]{1,60})"',
                        (source / "scripts/core/c.gd").read_text(encoding="utf-8"))
    if not version:
        raise ValueError("Missing game version")
    if "AUTH_INFO" not in (source / "scripts/autoload/net.gd").read_text(encoding="utf-8"):
        raise ValueError("This revision cannot answer the deployment health check")
    manifest = {"schema": 1, "tag": tag, "commit": commit, "gameVersion": version[1], "godot": GODOT}
    files = []
    for name in ROOTS:
        root = source / name
        if not root.exists() or root.is_symlink():
            raise ValueError("Missing or symlinked game root: " + name)
        for item in ([root] if root.is_file() else sorted(root.rglob("*"))):
            if item.is_symlink():
                raise ValueError("Symlinks are not accepted in game packages")
            if item.is_file():
                files.append(item)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / "MieczDawida-server-linux.tar.gz"
    with archive.open("wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", filename="", mtime=0) as zipped:
        with tarfile.open(fileobj=zipped, mode="w") as tar:
            for item in files:
                data = item.read_bytes()
                info = tarfile.TarInfo(item.relative_to(source).as_posix())
                info.size, info.mode = len(data), 0o644
                tar.addfile(info, io.BytesIO(data))
            data = json.dumps(manifest, sort_keys=True).encode()
            info = tarfile.TarInfo("panel-release.json")
            info.size, info.mode = len(data), 0o644
            tar.addfile(info, io.BytesIO(data))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "server-SHA256SUMS.txt").write_text(f"{digest}  {archive.name}\n", encoding="ascii")
    (output / "server-release.json").write_text(json.dumps({**manifest, "sha256": digest}), encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ("source", "output", "tag", "commit"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    print(json.dumps(package(args.source, args.output, args.tag, args.commit)))
