"""Bootstrap packaging plus Windows-only checks, with no real installer runs."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import pytest

ROOT = Path(__file__).resolve().parents[1]


def test_standalone_launcher_matches_source():
    spec = importlib.util.spec_from_file_location('build_launcher', ROOT / 'scripts/build_launcher.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    assert (ROOT / 'Play-MATHRONAUTS.cmd').read_bytes() == module.build()


def test_pinned_dependencies_do_not_require_git():
    requirements = (ROOT / 'requirements-desktop.txt').read_text()
    assert 'git+' not in requirements
    assert 'f822eb105e6a3e6ce3da3b266c5356d9f847be78.zip' in requirements


@pytest.mark.skipif(sys.platform != 'win32', reason='Windows PowerShell integration')
def test_windows_setup_paths_and_failure_handling():
    environment = os.environ.copy()
    # A PowerShell 7 parent can expose incompatible modules to Windows PowerShell.
    environment['PSModulePath'] = str(Path(os.environ['WINDIR']) / 'System32/WindowsPowerShell/v1.0/Modules')
    # Keep Windows PowerShell 5.1 fixtures below its legacy path-length limit.
    artifacts = ROOT / 'desktop-test-artifacts'
    artifacts.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='boot-', dir=artifacts) as temporary:
        assert Path(temporary).resolve().is_relative_to(ROOT.resolve())
        result = subprocess.run([
            shutil.which('powershell.exe'), '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', str(ROOT / 'tests/test_windows_setup.ps1'),
            '-TestRoot', temporary, '-TestPython', sys.executable
        ], cwd=ROOT, env=environment, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stdout + result.stderr
    assert '14 setup checks passed.' in result.stdout
