"""Trusted, fixed-layout installer. Prepares before stop; retains old release/data.

Runs as a transient systemd service, so a lost SSH/Actions connection cannot kill
the switch halfway through. Result journals make a repeated deployment ID safe.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import time
from package_release import GODOT, ROOTS, validate_identity

APP = Path("/opt/miecz-dawida")
SERVICE = "miecz-dawida.service"
USER = "miecz-dawida"


def extract_checked(package, destination, sha256, tag, commit):
    validate_identity(tag, commit)
    if not re.fullmatch(r"[a-f0-9]{64}", sha256) or hashlib.sha256(Path(package).read_bytes()).hexdigest() != sha256:
        raise ValueError("Package checksum mismatch")
    with tarfile.open(package, "r:gz") as archive:
        files = archive.getmembers()
        names = set()
        for member in files:
            name = PurePosixPath(member.name)
            if (not member.isfile() or name.is_absolute() or ".." in name.parts or
                member.name in names or str(name) != member.name or
                not name.parts or name.parts[0] not in (*ROOTS, "panel-release.json")):
                raise ValueError("Unsafe game package entry")
            names.add(member.name)
        if len(files) > 100000 or sum(member.size for member in files) > 4 * 1024**3:
            raise ValueError("Package exceeds extraction limits")
        manifest = json.load(archive.extractfile("panel-release.json"))
        if (manifest.get("schema") != 1 or manifest.get("tag") != tag or
            manifest.get("commit") != commit or manifest.get("godot") != GODOT or
            not re.fullmatch(r"[0-9A-Za-z.+_-]{1,60}", manifest.get("gameVersion", ""))):
            raise ValueError("Release identity or Godot runtime mismatch")
        if not {"project.godot", "main.tscn", "scripts/core/c.gd", "scripts/autoload/net.gd"}.issubset(names):
            raise ValueError("Incomplete game package")
        destination.mkdir(mode=0o755)
        for member in files:
            target = destination / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(member) as source, target.open("xb") as output:
                shutil.copyfileobj(source, output)
            target.chmod(0o644)
    return manifest


def atomic_link(target, link):
    temporary = link.with_name(link.name + ".switch")
    if temporary.is_symlink():
        temporary.unlink()
    temporary.symlink_to(target, target_is_directory=True)
    temporary.replace(link)


class Installer:
    def __init__(self, app=APP, run=subprocess.run):
        self.app, self.run = Path(app), run

    def command(self, *args, timeout=120):
        return self.run(list(args), check=True, capture_output=True, text=True, timeout=timeout, cwd="/").stdout.strip()

    def port(self):
        # Read just PORT; never source an environment file as shell code.
        text = Path("/etc/miecz-dawida.env").read_text()
        found = re.search(r"(?m)^PORT=([0-9]+)\s*$", text)
        port = int(found[1]) if found else 7777
        if not 1 <= port <= 65535:
            raise ValueError("Invalid server port")
        return port

    def health(self, target, expected_version=None, attempts=10):
        for attempt in range(attempts):
            try:
                self.command("/usr/bin/systemctl", "is-active", "--quiet", SERVICE)
                pid = self.command("/usr/bin/systemctl", "show", SERVICE, "--property=MainPID", "--value")
                if not pid.isdigit() or int(pid) <= 1 or Path(f"/proc/{pid}/cwd").resolve() != target.resolve():
                    raise RuntimeError("Service is not running the selected release")
                args = ["/usr/sbin/runuser", "-u", USER, "--", str(self.app / "bin/godot"),
                        "--headless", "--path", str(self.app / "panel-probe"), "--script", "res://health_probe.gd",
                        "--", f"--port={self.port()}"]
                if expected_version:
                    args.append("--version=" + expected_version)
                output = self.command(*args, timeout=12)
                line = next(line for line in output.splitlines() if line.startswith("PANEL_HEALTH="))
                return json.loads(line.split("=", 1)[1])
            except (subprocess.SubprocessError, RuntimeError, StopIteration, ValueError, OSError):
                if attempt + 1 == attempts:
                    raise RuntimeError("Game did not pass the ENet/version health check")
                time.sleep(2)

    def switch(self, target, deployment_id, version):
        live = self.app / "game"
        previous = live.resolve()
        if not live.exists():
            raise RuntimeError("Existing game installation is required")
        # The old install used a real directory; migrate once, without deleting it.
        self.command("/usr/bin/systemctl", "stop", SERVICE)
        try:
            if not live.is_symlink():
                previous = self.app / "releases" / ("legacy-" + deployment_id)
                live.rename(previous)
            atomic_link(target, live)
            self.command("/usr/bin/systemctl", "start", SERVICE)
            return self.health(target, version)
        except Exception as failure:
            self.command("/usr/bin/systemctl", "stop", SERVICE)
            if live.is_symlink() or not live.exists():
                atomic_link(previous, live)
            self.command("/usr/bin/systemctl", "start", SERVICE)
            try:
                self.health(previous, attempts=5)
            except Exception:
                raise RuntimeError("New release failed; previous release restored but its health needs attention") from failure
            raise RuntimeError("New release failed; previous release restored and verified") from failure

    def install(self, package, digest, tag, commit, deployment_id):
        actual_runtime = self.command(str(self.app / "bin/godot"), "--version")
        if not actual_runtime.startswith(GODOT + "."):
            raise RuntimeError("Installed Godot runtime does not match this package")
        # Probe code always comes from the trusted workflow, never from the package.
        probe = self.app / "panel-probe"
        probe.mkdir(exist_ok=True)
        shutil.copyfile(Path(__file__).with_name("health_probe.gd"), probe / "health_probe.gd")
        (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Panel health probe"\n')
        releases = self.app / "releases"
        releases.mkdir(exist_ok=True)
        target = releases / deployment_id
        manifest = extract_checked(package, target, digest, tag, commit)
        self.command("/usr/bin/chown", "-R", USER + ":" + USER, str(target))
        # Import only as the service account. User data stays under its existing HOME.
        self.command("/usr/sbin/runuser", "-u", USER, "--", "/usr/bin/env", "HOME=/var/lib/miecz-dawida",
                     str(self.app / "bin/godot"), "--headless", "--path", str(target), "--import", timeout=900)
        # Freeze release sources after the service has generated its import cache.
        self.command("/usr/bin/chown", "-R", "root:root", str(target))
        info = self.switch(target, deployment_id, manifest["gameVersion"])
        return {"tag": tag, "commit": commit, "gameVersion": manifest["gameVersion"],
                "checkedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "map": str(info.get("map", "")), "mode": str(info.get("mode", ""))}


def main():
    import fcntl  # Linux only; package/extraction tests also run on Windows.
    parser = argparse.ArgumentParser()
    for name in ("package", "sha256", "tag", "commit", "deployment-id"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    validate_identity(args.tag, args.commit)
    if os.geteuid() != 0 or not re.fullmatch(r"[a-f0-9-]{36}", args.deployment_id):
        raise ValueError("Root and a panel deployment UUID are required")
    result_file = Path(args.package).resolve().parent / "result.json"
    with open("/root/miecz-deploy.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        started = result_file.with_name("started.json")
        if result_file.exists():
            print(result_file.read_text())
            return
        if started.exists():
            raise RuntimeError("Interrupted installation needs inspection; refusing to repeat side effects")
        started.write_text(json.dumps({"commit": args.commit, "tag": args.tag}))
        try:
            verified = Installer().install(args.package, args.sha256, args.tag, args.commit, args.deployment_id)
            result = {"status": "succeeded", "result": "Wgrano wybrana wersje; restart i test ENet zakonczone sukcesem.", "verified": verified}
        except Exception as error:
            result = {"status": "failed", "result": str(error)[:1800]}
        temporary = result_file.with_suffix(".tmp")
        temporary.write_text(json.dumps(result))
        temporary.replace(result_file)
        print(json.dumps(result))


if __name__ == "__main__":
    main()
