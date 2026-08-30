#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "llama-translate-service.py"
SPEC = importlib.util.spec_from_file_location("llama_translate_service", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class RenderUnitTests(unittest.TestCase):
    def test_renders_required_service_policy_and_paths(self) -> None:
        installation = MODULE.Installation(
            user="alice",
            home=Path("/home/alice"),
            binary=Path("/usr/bin/llama-server"),
            model=Path("/home/alice/models/Hy-MT2-1.8B-Q4_K_M.gguf"),
        )

        unit = MODULE.render_unit(installation)

        self.assertIn("StartLimitIntervalSec=0", unit)
        self.assertNotIn("StartLimitBurst", unit)
        self.assertIn("Type=simple", unit)
        self.assertIn("Restart=always", unit)
        self.assertIn("RestartSec=60s", unit)
        self.assertIn("User=alice", unit)
        self.assertIn('ExecStart="/usr/bin/llama-server"', unit)
        self.assertIn('-m "/home/alice/models/Hy-MT2-1.8B-Q4_K_M.gguf"', unit)
        self.assertIn("WantedBy=multi-user.target", unit)
        self.assertNotRegex(unit, r"@[A-Z_]+@")

    def test_recognizes_only_managed_or_known_legacy_units(self) -> None:
        self.assertTrue(MODULE.known_unit(MODULE.MANAGED_MARKER))
        self.assertTrue(MODULE.known_unit("\n".join(MODULE.LEGACY_MARKERS)))
        self.assertFalse(MODULE.known_unit(MODULE.LEGACY_MARKERS[0]))
        self.assertFalse(MODULE.known_unit("Description=unrelated server"))

    def test_escapes_systemd_special_characters(self) -> None:
        self.assertEqual(MODULE.systemd_escape('/tmp/a%/b"c'), '/tmp/a%%/b\\"c')


class SynchronizationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.installation = MODULE.Installation(
            user="alice",
            home=Path("/home/alice"),
            binary=Path("/usr/bin/llama-server"),
            model=Path("/home/alice/models/Hy-MT2-1.8B-Q4_K_M.gguf"),
        )

    def test_rejects_healthy_endpoint_when_unit_is_inactive(self) -> None:
        snapshot = MODULE.UnitSnapshot(None, "", "not-found", False)
        with (
            mock.patch.object(MODULE, "effective_dropins", return_value=[]),
            mock.patch.object(MODULE, "health_once", return_value=(True, "ok")),
            self.assertRaisesRegex(MODULE.ServiceError, "unmanaged process"),
        ):
            MODULE.validate_existing_service(snapshot, force=False)

    def test_rejects_vendor_unit_without_force(self) -> None:
        snapshot = MODULE.UnitSnapshot(
            None, "/usr/lib/systemd/system/llama-server.service", "disabled", False
        )
        with (
            mock.patch.object(MODULE, "effective_dropins", return_value=[]),
            mock.patch.object(MODULE, "health_once", return_value=(False, "offline")),
            self.assertRaisesRegex(MODULE.ServiceError, "refusing to shadow"),
        ):
            MODULE.validate_existing_service(snapshot, force=False)

    def test_unchanged_healthy_install_does_not_restart(self) -> None:
        rendered = "rendered unit"
        snapshot = MODULE.UnitSnapshot(rendered, str(MODULE.UNIT_PATH), "enabled", True)
        args = argparse.Namespace(dry_run=False, force=False, health_timeout=1.0)
        with mock.patch.object(MODULE, "discover_installation", return_value=self.installation), \
                mock.patch.object(MODULE, "render_unit", return_value=rendered), \
                mock.patch.object(MODULE, "capture_snapshot", return_value=snapshot), \
                mock.patch.object(MODULE, "validate_existing_service"), \
                mock.patch.object(MODULE, "unit_active", return_value=True), \
                mock.patch.object(MODULE, "health_once", return_value=(True, "ok")), \
                mock.patch.object(MODULE, "wait_for_health", return_value=(True, "ok")), \
                mock.patch.object(MODULE, "verify_effective_service"), \
                mock.patch.object(MODULE, "install_unit") as install_unit, \
                mock.patch.object(MODULE, "run") as run:
            self.assertEqual(MODULE.install(args), 0)
        install_unit.assert_not_called()
        run.assert_called_once_with(["sudo", "systemctl", "enable", MODULE.SERVICE_NAME])

    def test_daemon_reload_failure_rolls_back_replaced_unit(self) -> None:
        snapshot = MODULE.UnitSnapshot("old unit", str(MODULE.UNIT_PATH), "enabled", True)
        args = argparse.Namespace(dry_run=False, force=False, health_timeout=1.0)
        failure = subprocess.CalledProcessError(1, ["systemctl", "daemon-reload"])
        with (
            mock.patch.object(MODULE, "discover_installation", return_value=self.installation),
            mock.patch.object(MODULE, "render_unit", return_value="new unit"),
            mock.patch.object(MODULE, "capture_snapshot", return_value=snapshot),
            mock.patch.object(MODULE, "validate_existing_service"),
            mock.patch.object(MODULE, "install_unit"),
            mock.patch.object(MODULE, "run", side_effect=failure),
            mock.patch.object(MODULE, "restore_previous") as restore,
            self.assertRaises(subprocess.CalledProcessError),
        ):
            MODULE.install(args)
        restore.assert_called_once_with(snapshot)


if __name__ == "__main__":
    unittest.main()
