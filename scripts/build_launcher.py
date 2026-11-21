"""Build the standalone Windows launcher from its PowerShell source."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEADER = r'''@echo off
setlocal DisableDelayedExpansion
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules;%ProgramFiles%\WindowsPowerShell\Modules"
set "MATHRONAUTS_BOOTSTRAP=%~f0"
set "MATHRONAUTS_MODE=%~1"
if "%~1"=="--help" (
  echo Double-click to install and play MATHRONAUTS.
  echo Options: --setup-only or --smoke-test
  exit /b 0
)
if not "%~1"=="" if not "%~1"=="--setup-only" if not "%~1"=="--smoke-test" (
  echo Unknown option. Use --help for usage.
  exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$source = Get-Content -LiteralPath $env:MATHRONAUTS_BOOTSTRAP -Raw; $body = ($source -split '(?m)^# POWERSHELL_BOOTSTRAP\r?$', 2)[1]; & ([scriptblock]::Create($body)) -LauncherPath $env:MATHRONAUTS_BOOTSTRAP -SmokeTest:($env:MATHRONAUTS_MODE -eq '--smoke-test') -SetupOnly:($env:MATHRONAUTS_MODE -eq '--setup-only')"
set "MATHRONAUTS_EXIT=%ERRORLEVEL%"
if not "%MATHRONAUTS_EXIT%"=="0" if "%MATHRONAUTS_MODE%"=="" if not defined CI pause
exit /b %MATHRONAUTS_EXIT%
# POWERSHELL_BOOTSTRAP
'''


def build():
    source = (ROOT / 'scripts' / 'setup-and-play.ps1').read_text(encoding='utf-8')
    return (HEADER + source).replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    target = ROOT / 'Play-MATHRONAUTS.cmd'
    expected = build()
    if args.check:
        # Git source ZIPs use LF even when Windows checkouts use CRLF.
        if not target.exists() or target.read_bytes().replace(b'\r\n', b'\n') != expected.replace(b'\r\n', b'\n'):
            raise SystemExit('Rebuild Play-MATHRONAUTS.cmd: python scripts/build_launcher.py')
    else:
        target.write_bytes(expected)


if __name__ == '__main__':
    main()
