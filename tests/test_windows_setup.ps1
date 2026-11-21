param([string]$TestRoot, [string]$TestPython)
$ErrorActionPreference = 'Stop'
$TestRoot = [IO.Path]::GetFullPath($TestRoot)
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts\setup-and-play.ps1') -LibraryOnly
New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
$script:passed = 0

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action } catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw }
        return
    }
    throw "Expected failure matching: $Pattern"
}
function Test-Case {
    param([string]$Name, [scriptblock]$Action)
    & $Action
    $script:passed++
    Write-Host "PASS: $Name"
}
function New-GameFixture {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path, (Join-Path $Path 'desktop'), (Join-Path $Path 'images') -Force | Out-Null
    foreach ($file in @('MATHRONAUTS.py', 'desktop\launcher.py', 'images\space.png')) {
        [IO.File]::WriteAllText((Join-Path $Path $file), 'fixture')
    }
    [IO.File]::WriteAllText((Join-Path $Path 'requirements-desktop.txt'), 'pgzero==1.2.1')
}

Test-Case 'PowerShell 5.1 source and embedded script parse' {
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'scripts\setup-and-play.ps1'), [ref]$null, [ref]$parseErrors) | Out-Null
    Assert-That ($parseErrors.Count -eq 0) ($parseErrors | Out-String)
    $launcher = [IO.File]::ReadAllText((Join-Path $repo 'Play-MATHRONAUTS.cmd'))
    $parts = $launcher -split '(?m)^# POWERSHELL_BOOTSTRAP\r?$', 2
    Assert-That ($parts.Count -eq 2) 'Missing embedded script marker.'
    [scriptblock]::Create($parts[1]) | Out-Null
}

Test-Case 'Existing Python 3.12 is reused and missing paths are skipped' {
    $found = Get-Python312 @((Join-Path $TestRoot 'does-not-exist.exe'), $TestPython)
    Assert-That ([bool]$found) 'Existing Python 3.12 was not detected.'
}

Test-Case 'Non-HTTPS downloads are rejected' {
    Assert-Throws { Receive-Download 'http://example.invalid/file' (Join-Path $TestRoot 'bad.exe') } 'HTTPS'
}

Test-Case 'Modified Python installer is never executed' {
    $fake = Join-Path $TestRoot 'tampered.exe'
    [IO.File]::WriteAllText($fake, 'not Python')
    Assert-Throws { Assert-PythonInstaller $fake } 'verification failed'
}

Test-Case 'Game alongside launcher works in a path containing spaces' {
    $local = Join-Path $TestRoot 'game folder with spaces'
    New-GameFixture $local
    function Receive-Download { throw 'Unexpected download' }
    $selected = Get-GameFolder (Join-Path $TestRoot 'unused') (Join-Path $local 'Play-MATHRONAUTS.cmd')
    Assert-That ($selected -eq $local) 'Local game was not selected.'
}

Test-Case 'Standalone launcher reuses cached game without a download' {
    $root = Join-Path $TestRoot 'cached'
    New-GameFixture (Join-Path $root 'app')
    function Receive-Download { throw 'Unexpected download' }
    $selected = Get-GameFolder $root (Join-Path $TestRoot 'standalone\Play-MATHRONAUTS.cmd')
    Assert-That ($selected -eq (Join-Path $root 'app')) 'Cached game was not selected.'
}

Test-Case 'Standalone first run extracts the downloaded game' {
    $root = Join-Path $TestRoot 'new install'
    $source = Join-Path $TestRoot 'archive content\MATHRONAUTS-main'
    New-GameFixture $source
    $fixtureZip = Join-Path $TestRoot 'fixture.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($source, $fixtureZip, [IO.Compression.CompressionLevel]::Optimal, $true)
    New-Item -ItemType Directory -Path (Join-Path $root 'downloads') -Force | Out-Null
    function Receive-Download {
        param($Uri, $Destination)
        Assert-That ($Uri -eq $script:GameUrl) 'Wrong game URL.'
        Copy-Item -LiteralPath $fixtureZip -Destination $Destination
    }
    $selected = Get-GameFolder $root (Join-Path $TestRoot 'standalone\Play-MATHRONAUTS.cmd')
    Assert-That (Test-GameFolder $selected) 'Downloaded game is incomplete.'
}

Test-Case 'Incomplete cached game is preserved with a clear error' {
    $root = Join-Path $TestRoot 'incomplete'
    New-Item -ItemType Directory -Path (Join-Path $root 'app') -Force | Out-Null
    $keep = Join-Path $root 'app\keep.txt'
    [IO.File]::WriteAllText($keep, 'preserve')
    Assert-Throws { Get-GameFolder $root (Join-Path $TestRoot 'standalone\Play-MATHRONAUTS.cmd') } 'incomplete'
    Assert-That (Test-Path -LiteralPath $keep) 'Existing file was removed.'
}

Test-Case 'Old Git dependency is translated to the same pinned archive' {
    $root = Join-Path $TestRoot 'old requirements'
    New-GameFixture $root
    [IO.File]::WriteAllText((Join-Path $root 'requirements-desktop.txt'), "pgzhelper @ git+https://github.com/QuirkyCort/pgzhelper.git@f822eb105e6a3e6ce3da3b266c5356d9f847be78`r`n")
    $normalized = Get-RequirementsText $root
    Assert-That ($normalized -notmatch 'git\+') 'Git is still required.'
    Assert-That ($normalized -match '/archive/f822eb105e6a3e6ce3da3b266c5356d9f847be78.zip$') 'Pinned helper revision changed.'
}

Test-Case 'Python install verifies the file before silent per-user execution' {
    $events = New-Object 'Collections.Generic.List[string]'
    function Receive-Download { param($Uri, $Destination); $events.Add('download') }
    function Assert-PythonInstaller { param($Path); $events.Add('verify') }
    function Get-PythonCandidates { param($Root); 'fake-python.exe' }
    function Get-Python312 { param($Candidates); 'fake-python.exe' }
    function Start-Process {
        param($FilePath, $ArgumentList, $WindowStyle, [switch]$Wait, [switch]$PassThru)
        $events.Add('execute')
        Assert-That ($ArgumentList -contains 'InstallAllUsers=0') 'Installer requests machine-wide install.'
        Assert-That ($ArgumentList -contains 'Include_pip=1') 'pip is missing.'
        Assert-That ($ArgumentList -contains 'PrependPath=0') 'Installer changes PATH.'
        Assert-That ($ArgumentList -contains 'Include_launcher=0') 'Installer requests global launcher.'
        Assert-That ($WindowStyle -eq 'Hidden') 'Installer helper is not hidden.'
        [pscustomobject]@{ ExitCode = 0 }
    }
    Install-Python312 $TestRoot | Out-Null
    Assert-That (($events -join ',') -eq 'download,verify,execute') 'Verification order is wrong.'
}

Test-Case 'Failed installer verification stops before execution' {
    function Receive-Download { param($Uri, $Destination) }
    function Assert-PythonInstaller { throw 'verification failed' }
    function Start-Process { throw 'Installer must not execute' }
    Assert-Throws { Install-Python312 $TestRoot } 'verification failed'
}

Test-Case 'Dependency setup creates private environment and marks success' {
    $root = Join-Path $TestRoot 'fresh environment'
    $game = Join-Path $TestRoot 'game folder with spaces'
    $calls = New-Object 'Collections.Generic.List[string]'
    function Get-Python312 { param($Candidates); 'fake-python.exe' }
    function Test-Dependencies { param($Python); $true }
    function Invoke-Program {
        param($FilePath, $Arguments, $Description)
        $calls.Add(($Arguments -join ' '))
        if ($Arguments -contains 'venv') {
            $scriptDir = Join-Path $Arguments[-1] 'Scripts'
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $scriptDir 'python.exe'), 'fake')
        }
    }
    $selected = Get-GamePython $root 'fake-system-python.exe' $game
    Assert-That ($calls.Count -eq 3) 'Expected venv, ensurepip, and pip.'
    Assert-That ($selected.StartsWith($root)) 'Environment is not private.'
    Assert-That (Test-Path -LiteralPath (Join-Path (Split-Path (Split-Path $selected)) 'requirements.ready')) 'Ready marker missing.'
}

Test-Case 'Repeat launch with valid dependencies does not contact pip' {
    $root = Join-Path $TestRoot 'fresh environment'
    $game = Join-Path $TestRoot 'game folder with spaces'
    function Get-Python312 { param($Candidates); 'fake-python.exe' }
    function Test-Dependencies { param($Python); $true }
    function Invoke-Program { throw 'Unexpected pip or venv execution' }
    Get-GamePython $root 'fake-system-python.exe' $game | Out-Null
}

Test-Case 'A failed dependency install is not marked ready' {
    $root = Join-Path $TestRoot 'failed environment'
    $game = Join-Path $TestRoot 'game folder with spaces'
    function Get-Python312 { param($Candidates); 'fake-python.exe' }
    function Invoke-Program {
        param($FilePath, $Arguments, $Description)
        if ($Arguments -contains 'venv') {
            $scriptDir = Join-Path $Arguments[-1] 'Scripts'
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $scriptDir 'python.exe'), 'fake')
        }
        if ($Arguments -contains 'pip') { throw 'pip installation failed' }
    }
    Assert-Throws { Get-GamePython $root 'fake-python.exe' $game } 'pip installation failed'
    Assert-That (@(Get-ChildItem -LiteralPath $root -Recurse -Filter requirements.ready).Count -eq 0) 'Failed installation was marked ready.'
}

Write-Host "$script:passed setup checks passed."
