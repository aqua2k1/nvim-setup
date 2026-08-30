#!/usr/bin/env python3
"""Install and verify the systemd service used by the Neovim translator.

Run this script as the account that should own the llama-server process. It
uses sudo only for writes below /etc and for systemctl mutations, so binary
lookup and home-directory discovery use the service user's environment.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pwd
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

SERVICE_NAME = "llama-server.service"
UNIT_PATH = Path("/etc/systemd/system") / SERVICE_NAME
DROPIN_DIR = UNIT_PATH.with_name(f"{SERVICE_NAME}.d")
SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATE_PATH = SCRIPT_DIR / "systemd" / "llama-server.service.in"
MODEL_FILENAME = "Hy-MT2-1.8B-Q4_K_M.gguf"
MODEL_SHA256 = "dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699"
HEALTH_URL = "http://127.0.0.1:9999/health"
MANAGED_MARKER = "# Managed by nvim-setup/scripts/llama-translate-service.py"
LEGACY_MARKERS = (
    "Description=llama-server (Hy-MT2 translation)",
    "Hy-MT2-1.8B-Q4_K_M.gguf",
    "--port 9999 --host 127.0.0.1",
    "--sleep-idle-seconds 600",
)


class ServiceError(RuntimeError):
    """An actionable service synchronization failure."""


@dataclass(frozen=True)
class Installation:
    user: str
    home: Path
    binary: Path
    model: Path


@dataclass(frozen=True)
class UnitSnapshot:
    content: str | None
    fragment_path: str
    enabled_state: str
    active: bool


def run(
    argv: list[str],
    *,
    check: bool = True,
    capture_output: bool = False,
    dry_run: bool = False,
) -> subprocess.CompletedProcess[str]:
    print(f"+ {shlex.join(argv)}")
    if dry_run:
        return subprocess.CompletedProcess(argv, 0, "", "")
    return subprocess.run(
        argv,
        check=check,
        capture_output=capture_output,
        text=True,
    )


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def discover_installation() -> Installation:
    if os.geteuid() == 0:
        raise ServiceError(
            "run this script as the service user, without sudo; "
            "it invokes sudo only when required"
        )

    account = pwd.getpwuid(os.getuid())
    home = Path(account.pw_dir)
    expected_home = Path("/home") / account.pw_name
    if home != expected_home:
        raise ServiceError(
            f"expected {account.pw_name}'s home to be {expected_home}, got {home}"
        )

    try:
        result = subprocess.run(
            ["which", "llama-server"],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise ServiceError("the 'which' command is required") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() if exc.stderr else "not present in PATH"
        raise ServiceError(
            "llama-server was not found; install it with the machine's package "
            f"manager and ensure it is in PATH ({detail})"
        ) from exc

    candidates = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not candidates:
        raise ServiceError("'which llama-server' returned no executable path")

    binary = Path(candidates[0])
    if not binary.is_absolute():
        raise ServiceError(f"'which llama-server' returned a non-absolute path: {binary}")
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ServiceError(f"llama-server is not an executable regular file: {binary}")

    model = home / "models" / MODEL_FILENAME
    if not model.is_file() or not os.access(model, os.R_OK):
        raise ServiceError(f"translation model is missing or unreadable: {model}")
    actual_hash = file_sha256(model)
    if actual_hash != MODEL_SHA256:
        raise ServiceError(
            f"translation model checksum mismatch: {model}\n"
            f"expected {MODEL_SHA256}, got {actual_hash}"
        )

    if not TEMPLATE_PATH.is_file():
        raise ServiceError(f"service template is missing: {TEMPLATE_PATH}")

    return Installation(account.pw_name, home, binary, model)


def systemd_escape(value: str) -> str:
    if "\n" in value or "\r" in value:
        raise ServiceError("systemd values may not contain newlines")
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%")


def render_unit(installation: Installation) -> str:
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.-]*", installation.user):
        raise ServiceError(f"unsupported service username: {installation.user!r}")

    content = TEMPLATE_PATH.read_text(encoding="utf-8")
    replacements = {
        "@USER@": installation.user,
        "@LLAMA_SERVER@": systemd_escape(str(installation.binary)),
        "@MODEL@": systemd_escape(str(installation.model)),
    }
    for placeholder, value in replacements.items():
        content = content.replace(placeholder, value)
    if re.search(r"@[A-Z_]+@", content):
        raise ServiceError("unresolved placeholder in rendered systemd unit")
    return content


def read_existing_unit() -> str | None:
    try:
        return UNIT_PATH.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    except PermissionError:
        result = run(["sudo", "cat", str(UNIT_PATH)], capture_output=True)
        return result.stdout


def known_unit(content: str) -> bool:
    return MANAGED_MARKER in content or all(marker in content for marker in LEGACY_MARKERS)


def systemctl_properties(*names: str) -> dict[str, str]:
    argv = ["systemctl", "show", "--no-pager"]
    argv.extend(f"--property={name}" for name in names)
    argv.append(SERVICE_NAME)
    result = subprocess.run(argv, check=False, capture_output=True, text=True)
    properties: dict[str, str] = {}
    for line in result.stdout.splitlines():
        key, separator, value = line.partition("=")
        if separator:
            properties[key] = value
    return properties


def unit_active() -> bool:
    result = subprocess.run(
        ["systemctl", "is-active", "--quiet", SERVICE_NAME],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def unit_enabled_state() -> str:
    result = subprocess.run(
        ["systemctl", "is-enabled", SERVICE_NAME],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.strip().splitlines()[0] if result.stdout.strip() else "not-found"


def effective_dropins() -> list[str]:
    properties = systemctl_properties("DropInPaths")
    paths = properties.get("DropInPaths", "").split()
    if DROPIN_DIR.is_dir():
        paths.extend(str(path) for path in sorted(DROPIN_DIR.glob("*.conf")))
    return sorted(set(paths))


def capture_snapshot() -> UnitSnapshot:
    properties = systemctl_properties("FragmentPath")
    return UnitSnapshot(
        content=read_existing_unit(),
        fragment_path=properties.get("FragmentPath", ""),
        enabled_state=unit_enabled_state(),
        active=unit_active(),
    )


def health_once(timeout: float = 2.0) -> tuple[bool, str]:
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(HEALTH_URL, timeout=timeout) as response:
            if response.status != 200:
                return False, f"HTTP {response.status}"
            payload = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, OSError, ValueError, UnicodeError) as exc:
        return False, str(exc)

    if not isinstance(payload, dict) or payload.get("status") != "ok":
        return False, "health response did not contain status=ok"
    return True, "ok"


def wait_for_health(timeout: float) -> tuple[bool, str]:
    deadline = time.monotonic() + timeout
    last_error = "not checked"
    while True:
        healthy, last_error = health_once()
        if healthy:
            return True, "ok"
        if time.monotonic() >= deadline:
            return False, last_error
        time.sleep(1)


def install_unit(content: str, *, dry_run: bool) -> None:
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        prefix="llama-server.service.",
        delete=False,
    ) as source:
        source.write(content)
        source_path = Path(source.name)

    staged_path = UNIT_PATH.with_name(f".{UNIT_PATH.name}.{os.getpid()}.tmp")
    try:
        run(
            [
                "sudo",
                "install",
                "-o",
                "root",
                "-g",
                "root",
                "-m",
                "0644",
                str(source_path),
                str(staged_path),
            ],
            dry_run=dry_run,
        )
        run(["sudo", "mv", "-f", str(staged_path), str(UNIT_PATH)], dry_run=dry_run)
    finally:
        source_path.unlink(missing_ok=True)
        if not dry_run:
            subprocess.run(
                ["sudo", "rm", "-f", str(staged_path)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )


def remove_unit() -> None:
    run(["sudo", "rm", "-f", str(UNIT_PATH)])


def restore_enablement(state: str) -> None:
    if state == "enabled":
        run(["sudo", "systemctl", "enable", SERVICE_NAME])
    elif state == "enabled-runtime":
        run(["sudo", "systemctl", "enable", "--runtime", SERVICE_NAME])
    elif state == "masked":
        run(["sudo", "systemctl", "mask", SERVICE_NAME])
    elif state == "masked-runtime":
        run(["sudo", "systemctl", "mask", "--runtime", SERVICE_NAME])
    else:
        run(["sudo", "systemctl", "disable", SERVICE_NAME], check=False)


def restore_previous(snapshot: UnitSnapshot) -> None:
    print("service validation failed; restoring the previous unit", file=sys.stderr)
    run(["sudo", "systemctl", "stop", SERVICE_NAME], check=False)
    if snapshot.content is None:
        remove_unit()
    else:
        install_unit(snapshot.content, dry_run=False)
    run(["sudo", "systemctl", "daemon-reload"])
    restore_enablement(snapshot.enabled_state)
    if snapshot.active:
        run(["sudo", "systemctl", "start", SERVICE_NAME])


def verify_effective_service(installation: Installation) -> None:
    properties = systemctl_properties(
        "FragmentPath",
        "DropInPaths",
        "Restart",
        "RestartUSec",
        "User",
        "ExecStart",
        "MainPID",
    )
    errors: list[str] = []
    if properties.get("FragmentPath") != str(UNIT_PATH):
        errors.append(f"unexpected fragment: {properties.get('FragmentPath') or 'none'}")
    if properties.get("DropInPaths"):
        errors.append(f"unexpected drop-ins: {properties['DropInPaths']}")
    if properties.get("Restart") != "always":
        errors.append(f"Restart={properties.get('Restart') or 'unknown'}")
    if properties.get("RestartUSec") not in {"1min", "60s"}:
        errors.append(f"RestartSec={properties.get('RestartUSec') or 'unknown'}")
    if properties.get("User") != installation.user:
        errors.append(f"User={properties.get('User') or 'unknown'}")
    exec_start = properties.get("ExecStart", "")
    for required in (str(installation.binary), str(installation.model), "--port 9999"):
        if required not in exec_start:
            errors.append(f"ExecStart is missing {required}")
    if unit_enabled_state() != "enabled":
        errors.append(f"unit state is {unit_enabled_state()}, not enabled")
    if not unit_active():
        errors.append("unit is not active")
    try:
        main_pid = int(properties.get("MainPID", "0"))
    except ValueError:
        main_pid = 0
    if main_pid <= 0:
        errors.append("unit has no main process")
    if errors:
        raise ServiceError("effective service validation failed: " + "; ".join(errors))


def validate_existing_service(snapshot: UnitSnapshot, *, force: bool) -> None:
    dropins = effective_dropins()
    if dropins:
        raise ServiceError(
            "refusing to synchronize a unit with drop-ins; remove or merge them first:\n"
            + "\n".join(dropins)
        )
    if snapshot.content is not None and not known_unit(snapshot.content) and not force:
        raise ServiceError(
            f"refusing to replace an unrecognized {UNIT_PATH}; inspect it and rerun with --force"
        )
    if (
        snapshot.content is None
        and snapshot.fragment_path
        and snapshot.fragment_path != str(UNIT_PATH)
        and not force
    ):
        raise ServiceError(
            f"{SERVICE_NAME} is supplied by {snapshot.fragment_path}; "
            "refusing to shadow it without --force"
        )
    healthy, _ = health_once()
    if healthy and not snapshot.active:
        raise ServiceError(
            f"{HEALTH_URL} is served while {SERVICE_NAME} is inactive; "
            "stop the unmanaged process before synchronizing"
        )


def install(args: argparse.Namespace) -> int:
    installation = discover_installation()
    rendered = render_unit(installation)
    snapshot = capture_snapshot()
    validate_existing_service(snapshot, force=args.force)
    changed = snapshot.content != rendered

    print(f"user:   {installation.user}")
    print(f"binary: {installation.binary}")
    print(f"model:  {installation.model}")
    print(f"unit:   {UNIT_PATH} ({'update' if changed else 'unchanged'})")

    if args.dry_run:
        if changed:
            install_unit(rendered, dry_run=True)
            run(["sudo", "systemctl", "daemon-reload"], dry_run=True)
        run(["sudo", "systemctl", "enable", SERVICE_NAME], dry_run=True)
        action = "restart" if changed else "start-if-inactive-or-unhealthy"
        print(f"dry-run service action: {action}")
        return 0

    mutated = False
    try:
        if changed:
            install_unit(rendered, dry_run=False)
            mutated = True
            run(["sudo", "systemctl", "daemon-reload"])

        mutated = True
        run(["sudo", "systemctl", "enable", SERVICE_NAME])
        active = unit_active()
        healthy, _ = health_once()
        if changed:
            run(["sudo", "systemctl", "restart", SERVICE_NAME])
        elif not active:
            run(["sudo", "systemctl", "start", SERVICE_NAME])
        elif not healthy:
            print("service is active but unhealthy; restarting it")
            run(["sudo", "systemctl", "restart", SERVICE_NAME])

        healthy, detail = wait_for_health(args.health_timeout)
        if not healthy:
            raise ServiceError(
                f"{SERVICE_NAME} did not become healthy within "
                f"{args.health_timeout:g}s: {detail}"
            )
        verify_effective_service(installation)
    except (ServiceError, subprocess.CalledProcessError) as exc:
        if mutated:
            try:
                restore_previous(snapshot)
            except (ServiceError, subprocess.CalledProcessError) as rollback_error:
                raise ServiceError(f"{exc}; rollback failed: {rollback_error}") from exc
        raise

    print(f"{SERVICE_NAME} is enabled, active, and healthy")
    return 0


def check() -> int:
    installation = discover_installation()
    expected = render_unit(installation)
    actual = read_existing_unit()
    properties = systemctl_properties(
        "FragmentPath", "DropInPaths", "Restart", "RestartUSec", "User"
    )
    checks = {
        "unit-current": actual == expected,
        "fragment-current": properties.get("FragmentPath") == str(UNIT_PATH),
        "no-drop-ins": not effective_dropins(),
        "restart-always": properties.get("Restart") == "always",
        "restart-60s": properties.get("RestartUSec") in {"1min", "60s"},
        "service-user": properties.get("User") == installation.user,
        "enabled": unit_enabled_state() == "enabled",
        "active": unit_active(),
        "healthy": health_once()[0],
    }
    for name, passed in checks.items():
        print(f"{name}: {'ok' if passed else 'failed'}")
    return 0 if all(checks.values()) else 1


def status() -> int:
    result = subprocess.run(
        ["systemctl", "status", "--no-pager", "--full", SERVICE_NAME],
        check=False,
    )
    healthy, detail = health_once()
    print(f"health: {'ok' if healthy else detail}")
    return 0 if result.returncode == 0 and healthy else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    install_parser = subparsers.add_parser("install", help="install and enable the service")
    install_parser.add_argument("--dry-run", action="store_true")
    install_parser.add_argument("--force", action="store_true")
    install_parser.add_argument("--health-timeout", type=float, default=75.0)

    subparsers.add_parser("check", help="verify unit content and runtime state")
    subparsers.add_parser("status", help="show systemd and HTTP status")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "install":
            return install(args)
        if args.command == "check":
            return check()
        return status()
    except subprocess.CalledProcessError as exc:
        print(f"error: command failed with exit code {exc.returncode}: {shlex.join(exc.cmd)}", file=sys.stderr)
        return 1
    except ServiceError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
