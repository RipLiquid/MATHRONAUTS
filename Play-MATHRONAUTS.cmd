@echo off
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
# Source for Play-MATHRONAUTS.cmd. Rebuild with scripts/build_launcher.py.
# Compatible with the Windows PowerShell 5.1 included in Windows 10/11.
[CmdletBinding()]
param(
    [string]$LauncherPath = (Join-Path $PSScriptRoot '..\Play-MATHRONAUTS.cmd'),
    [string]$InstallRoot = $env:MATHRONAUTS_HOME,
    [switch]$SmokeTest,
    [switch]$SetupOnly,
    [switch]$LibraryOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:PythonUrl = 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe'
# SHA-256 from the release's Python.org Sigstore bundle.
$script:PythonSha256 = '67b5635e80ea51072b87941312d00ec8927c4db9ba18938f7ad2d27b328b95fb'
$script:GameUrl = 'https://codeload.github.com/RipLiquid/MATHRONAUTS/zip/refs/heads/main'

function Invoke-Program {
    param([string]$FilePath, [string[]]$Arguments, [string]$Description)
    & $FilePath @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed (exit code $LASTEXITCODE). See the setup log for details."
    }
}

function Get-Python312 {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates | Select-Object -Unique) {
        if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        # Avoid the Microsoft Store execution alias, which can open a Store window.
        if ($candidate -match '\\Microsoft\\WindowsApps\\') { continue }
        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $found = & $candidate -I -c 'import sys, struct; print(sys.executable) if sys.version_info[:2] == (3, 12) and struct.calcsize(''P'') == 8 else sys.exit(1)' 2>$null
            if ($LASTEXITCODE -eq 0 -and $found) { return ([string]$found).Trim() }
        } finally { $ErrorActionPreference = $oldPreference }
    }
    return $null
}

function Get-PythonCandidates {
    param([string]$Root)
    Join-Path $Root 'python\python.exe'
    Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'
    foreach ($key in @(
        'HKCU:\Software\Python\PythonCore\3.12\InstallPath',
        'HKLM:\Software\Python\PythonCore\3.12\InstallPath'
    )) {
        if (Test-Path -LiteralPath $key) {
            $properties = Get-ItemProperty -LiteralPath $key
            if ($properties.PSObject.Properties['ExecutablePath']) { $properties.ExecutablePath }
        }
    }
    $command = Get-Command python.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { $command.Source }
}

function Receive-Download {
    param([string]$Uri, [string]$Destination)
    if (-not $Uri.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Downloads must use HTTPS.'
    }
    # Use TLS 1.2 on Windows PowerShell without weakening certificate validation.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Destination -TimeoutSec 120
    } catch {
        throw "Could not download $Uri. Check your internet connection and run the launcher again. $($_.Exception.Message)"
    } finally { $ProgressPreference = $oldProgress }
}

function Assert-PythonInstaller {
    param([string]$Path)
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $script:PythonSha256) {
        throw 'Python installer verification failed. The downloaded file will not be run.'
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Python Software Foundation') {
        throw 'The Python installer does not have a valid Python Software Foundation signature.'
    }
}

function Install-Python312 {
    param([string]$Root)
    $installer = Join-Path $Root 'downloads\python-3.12.10-amd64.exe'
    Write-Host '[2/5] Installing Python 3.12 for this Windows user...'
    Receive-Download $script:PythonUrl $installer
    Assert-PythonInstaller $installer
    $target = Join-Path $Root 'python'
    $arguments = @('/quiet', 'InstallAllUsers=0', 'Include_pip=1', 'Include_launcher=0',
        'Include_test=0', 'Include_doc=0', 'Include_tcltk=0', 'PrependPath=0',
        'AssociateFiles=0', 'Shortcuts=0', ('TargetDir="{0}"' -f $target))
    $process = Start-Process -FilePath $installer -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "Python installation failed (exit code $($process.ExitCode)). Try installing Python 3.12 from python.org, then run this file again."
    }
    $python = Get-Python312 @(Get-PythonCandidates $Root)
    if (-not $python) {
        throw 'Python installation did not become available. Restart Windows if the installer requested it, then try again.'
    }
    return $python
}

function Test-GameFolder {
    param([string]$Path)
    foreach ($relative in @('MATHRONAUTS.py', 'requirements-desktop.txt', 'desktop\launcher.py', 'images\space.png')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Path $relative) -PathType Leaf)) { return $false }
    }
    return $true
}

function Expand-GameArchive {
    param([string]$Archive, [string]$Destination)
    # Extract only desktop runtime files; mobile sources have much longer paths.
    $destinationRoot = [IO.Path]::GetFullPath($Destination) + [IO.Path]::DirectorySeparatorChar
    [IO.Directory]::CreateDirectory($Destination) | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            $entryName = $entry.FullName.Replace('\', '/')
            $relative = ($entryName -split '/', 2)
            if ($relative.Count -ne 2 -or $entryName.EndsWith('/')) { continue }
            $relative = $relative[1]
            if ($relative -notmatch '^(MATHRONAUTS\.py|U11-Final CPT\.py|requirements-desktop\.txt|desktop/.+|images/.+|fonts/.+|sounds/.+)$') { continue }
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $relative))
            if (-not $target.StartsWith($destinationRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'The downloaded game archive contains an invalid path.'
            }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
        }
    } finally { $zip.Dispose() }
}

function Get-GameFolder {
    param([string]$Root, [string]$Launcher)
    $alongside = Split-Path -Parent ([IO.Path]::GetFullPath($Launcher))
    if (Test-GameFolder $alongside) {
        Write-Host '[1/5] Using the game next to this launcher.'
        return $alongside
    }
    $cached = Join-Path $Root 'app'
    if (Test-GameFolder $cached) {
        Write-Host '[1/5] Using your downloaded game.'
        return $cached
    }
    if (Test-Path -LiteralPath $cached) {
        throw "The cached game at $cached is incomplete. Rename that folder to app-backup and run the launcher again. Your progress is in a separate folder."
    }
    Write-Host '[1/5] Downloading MATHRONAUTS from GitHub...'
    $token = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $archive = Join-Path $Root "downloads\g-$token.zip"
    $stage = Join-Path $Root "downloads\g-$token"
    Receive-Download $script:GameUrl $archive
    Expand-GameArchive $archive $stage
    if (-not (Test-GameFolder $stage)) { throw 'The game download was incomplete or had an unexpected structure. Run the launcher again.' }
    Move-Item -LiteralPath $stage -Destination $cached
    return $cached
}

function Get-RequirementsText {
    param([string]$GameFolder)
    $text = [IO.File]::ReadAllText((Join-Path $GameFolder 'requirements-desktop.txt'))
    # Also support game snapshots from before the Git-free requirements update.
    $text = $text.Replace(
        'git+https://github.com/QuirkyCort/pgzhelper.git@f822eb105e6a3e6ce3da3b266c5356d9f847be78',
        'https://github.com/QuirkyCort/pgzhelper/archive/f822eb105e6a3e6ce3da3b266c5356d9f847be78.zip')
    return $text.Replace("`r`n", "`n").Trim()
}

function Get-TextHash {
    param([string]$Text)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant()
    } finally { $algorithm.Dispose() }
}

function Test-Dependencies {
    param([string]$Python)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Python -I -c 'from importlib.metadata import version; import pgzero, pygame; from pgzhelper import Actor; assert version(''pygame'') == ''2.6.1''; assert version(''pgzero'') == ''1.2.1''; assert hasattr(Actor, ''move_forward'')' *> $null
        return ($LASTEXITCODE -eq 0)
    } finally { $ErrorActionPreference = $oldPreference }
}

function Get-GamePython {
    param([string]$Root, [string]$Python, [string]$GameFolder)
    $requirements = Get-RequirementsText $GameFolder
    $hash = Get-TextHash $requirements
    $environment = Join-Path $Root ('envs\312-' + $hash.Substring(0, 12))
    $gamePython = Join-Path $environment 'Scripts\python.exe'
    $marker = Join-Path $environment 'requirements.ready'
    if (-not (Test-Path -LiteralPath $gamePython -PathType Leaf)) {
        Write-Host '[3/5] Creating a private game environment...'
        Invoke-Program $Python @('-I', '-m', 'venv', $environment) 'Creating the game environment'
    }
    if (-not (Get-Python312 @($gamePython))) {
        throw "The private environment at $environment is damaged. Rename it and run the launcher again."
    }
    $ready = (Test-Path -LiteralPath $marker) -and ([IO.File]::ReadAllText($marker).Trim() -eq $hash)
    if ($ready -and (Test-Dependencies $gamePython)) {
        Write-Host '[4/5] Game dependencies are already installed.'
        return $gamePython
    }
    Write-Host '[4/5] Installing pip and the pinned game dependencies...'
    Invoke-Program $gamePython @('-I', '-m', 'ensurepip', '--upgrade') 'Preparing pip'
    $requirementFile = Join-Path $environment 'requirements-install.txt'
    [IO.File]::WriteAllText($requirementFile, $requirements, (New-Object Text.UTF8Encoding($false)))
    Invoke-Program $gamePython @('-I', '-m', 'pip', 'install', '--disable-pip-version-check', '-r', $requirementFile) 'Installing game dependencies'
    if (-not (Test-Dependencies $gamePython)) { throw 'Game dependency validation failed. Check the log and run the launcher again.' }
    [IO.File]::WriteAllText($marker, $hash)
    return $gamePython
}

function Start-Mathronauts {
    param([string]$Root, [string]$Launcher, [switch]$RunSmoke, [switch]$OnlySetup)
    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
        throw 'This launcher supports 64-bit Intel/AMD Windows 10 and 11. See the README for other platforms.'
    }
    New-Item -ItemType Directory -Path $Root, (Join-Path $Root 'downloads'), (Join-Path $Root 'logs') -Force | Out-Null
    $log = Join-Path $Root ('logs\setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
    $transcript = $false
    $lock = $null
    try {
        Start-Transcript -LiteralPath $log -Append | Out-Null
        $transcript = $true
        Write-Host 'MATHRONAUTS - setup and play'
        Write-Host 'The first launch needs internet and may take a few minutes.'
        try {
            $lock = [IO.File]::Open((Join-Path $Root 'setup.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
        } catch { throw 'Another MATHRONAUTS setup is running. Wait for it to finish, then try again.' }
        $gameFolder = Get-GameFolder $Root $Launcher
        $python = Get-Python312 @(Get-PythonCandidates $Root)
        if (-not $python) { $python = Install-Python312 $Root }
        else { Write-Host '[2/5] Python 3.12 is already installed.' }
        $gamePython = Get-GamePython $Root $python $gameFolder
        $lock.Dispose()
        $lock = $null
        if ($OnlySetup) {
            Write-Host '[5/5] Setup complete. Double-click the launcher to play.'
            return
        }
        $gameArguments = @((Join-Path $gameFolder 'MATHRONAUTS.py'))
        if ($RunSmoke) {
            $gameArguments += @('--smoke-test', (Join-Path $Root 'smoke-test'), '--data-dir', (Join-Path $Root 'smoke-progress'))
        } else {
            $gameArguments += @('--data-dir', (Join-Path $Root 'progress'))
        }
        Write-Host '[5/5] Starting MATHRONAUTS...'
        Push-Location -LiteralPath $gameFolder
        try { Invoke-Program $gamePython $gameArguments 'Running MATHRONAUTS' }
        finally { Pop-Location }
    } catch {
        Write-Host ''
        Write-Host ('Setup could not finish: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host "Log: $log"
        throw
    } finally {
        if ($lock) { $lock.Dispose() }
        if ($transcript) { Stop-Transcript | Out-Null }
    }
}

if (-not $LibraryOnly) {
    if (-not $InstallRoot) { $InstallRoot = Join-Path $env:LOCALAPPDATA 'MATHRONAUTS' }
    try {
        Start-Mathronauts -Root ([IO.Path]::GetFullPath($InstallRoot)) -Launcher $LauncherPath -RunSmoke:$SmokeTest -OnlySetup:$SetupOnly
    } catch { exit 1 }
}
