param(
    [string]$Version = "",
    [string]$Ahk2ExePath = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe",
    [string]$BaseExePath = "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $repoRoot "dist"
$versionRoot = if ([string]::IsNullOrWhiteSpace($Version)) {
    Join-Path $distRoot "release"
} else {
    Join-Path $distRoot $Version
}
$releaseRoot = if ([string]::IsNullOrWhiteSpace($Version)) {
    Join-Path $distRoot "release\GoodByCopilot"
} else {
    Join-Path $distRoot (Join-Path $Version "GoodByCopilot")
}
$bundleName = if ([string]::IsNullOrWhiteSpace($Version)) {
    "GoodByCopilot-release.zip"
} else {
    "GoodByCopilot-$Version.zip"
}
$bundlePath = Join-Path $distRoot $bundleName

if (Test-Path -LiteralPath $versionRoot) {
    Remove-Item -LiteralPath $versionRoot -Recurse -Force
}

if (-not (Test-Path -LiteralPath $Ahk2ExePath)) {
    throw "Ahk2Exe not found: $Ahk2ExePath"
}
if (-not (Test-Path -LiteralPath $BaseExePath)) {
    throw "AutoHotkey base executable not found: $BaseExePath"
}

New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null

Remove-Item -LiteralPath (Join-Path $repoRoot "GoodByCopilot.exe") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $repoRoot "CoreGBC.exe") -Force -ErrorAction SilentlyContinue

& $Ahk2ExePath /in (Join-Path $repoRoot "GoodByCopilot.ahk") /out (Join-Path $repoRoot "GoodByCopilot.exe") /base $BaseExePath
& $Ahk2ExePath /in (Join-Path $repoRoot "Core\CoreGBC.ahk") /out (Join-Path $repoRoot "CoreGBC.exe") /base $BaseExePath

foreach ($path in @((Join-Path $repoRoot "GoodByCopilot.exe"), (Join-Path $repoRoot "CoreGBC.exe"))) {
    $deadline = (Get-Date).AddSeconds(10)
    while (-not (Test-Path -LiteralPath $path)) {
        if ((Get-Date) -gt $deadline) {
            throw "Timed out waiting for build artifact: $path"
        }
        Start-Sleep -Milliseconds 200
    }
}

Copy-Item -LiteralPath (Join-Path $repoRoot "GoodByCopilot.exe") -Destination (Join-Path $releaseRoot "GoodByCopilot.exe") -Force
New-Item -ItemType Directory -Force -Path (Join-Path $releaseRoot "Core") | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot "CoreGBC.exe") -Destination (Join-Path $releaseRoot "Core\CoreGBC.exe") -Force
$resourceDirs = @(
    @{ Source = (Join-Path $repoRoot "Core\default"); Destination = (Join-Path $releaseRoot "Core\default") },
    @{ Source = (Join-Path $repoRoot "Core\LangPackage"); Destination = (Join-Path $releaseRoot "Core\LangPackage") }
)

foreach ($dir in $resourceDirs) {
    if (-not (Test-Path -LiteralPath $dir.Source)) {
        throw "Missing release resource directory: $($dir.Source)"
    }
    New-Item -ItemType Directory -Force -Path $dir.Destination | Out-Null
    Get-ChildItem -LiteralPath $dir.Source -File | Copy-Item -Destination $dir.Destination -Force
}

if (Test-Path -LiteralPath $bundlePath) {
    Remove-Item -LiteralPath $bundlePath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($bundlePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $rootName = Split-Path -Leaf $releaseRoot
    $basePath = (Split-Path -Parent $releaseRoot).TrimEnd('\')

    foreach ($file in Get-ChildItem -LiteralPath $releaseRoot -Recurse -File) {
        $relative = $file.FullName.Substring($basePath.Length + 1)
        $entryName = $relative -replace '\\', '/'
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName) | Out-Null
    }
} finally {
    $zip.Dispose()
}

Write-Host "Created release bundle:"
Write-Host $bundlePath
