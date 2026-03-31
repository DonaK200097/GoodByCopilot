param(
    [string]$Version = "",
    [string]$Ahk2ExePath = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe",
    [string]$BaseExePath = "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $repoRoot "dist"
$releaseRoot = if ([string]::IsNullOrWhiteSpace($Version)) {
    Join-Path $distRoot "release"
} else {
    Join-Path $distRoot $Version
}
$bundleName = if ([string]::IsNullOrWhiteSpace($Version)) {
    "GoodByCopilot-release.zip"
} else {
    "GoodByCopilot-$Version.zip"
}
$bundlePath = Join-Path $distRoot $bundleName

if (-not (Test-Path -LiteralPath $Ahk2ExePath)) {
    throw "Ahk2Exe not found: $Ahk2ExePath"
}
if (-not (Test-Path -LiteralPath $BaseExePath)) {
    throw "AutoHotkey base executable not found: $BaseExePath"
}

$sources = @(
    @{ In = (Join-Path $repoRoot "GoodByCopilot.ahk"); Out = (Join-Path $repoRoot "GoodByCopilot.exe") },
    @{ In = (Join-Path $repoRoot "Core\CoreGBC.ahk"); Out = (Join-Path $repoRoot "CoreGBC.exe") }
)

foreach ($src in $sources) {
    & $Ahk2ExePath /in $src.In /out $src.Out /base $BaseExePath
    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed for $($src.In)"
    }
}

New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null

foreach ($file in @("GoodByCopilot.exe", "CoreGBC.exe")) {
    $source = Join-Path $repoRoot $file
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing build artifact: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $releaseRoot $file) -Force
}

$resourceDirs = @(
    @{ Source = (Join-Path $repoRoot "Core\default"); Destination = (Join-Path $releaseRoot "Core\default") },
    @{ Source = (Join-Path $repoRoot "Core\LangPackage"); Destination = (Join-Path $releaseRoot "Core\LangPackage") }
)

foreach ($dir in $resourceDirs) {
    if (-not (Test-Path -LiteralPath $dir.Source)) {
        throw "Missing release resource directory: $($dir.Source)"
    }
    New-Item -ItemType Directory -Force -Path $dir.Destination | Out-Null
    Copy-Item -LiteralPath (Join-Path $dir.Source "*") -Destination $dir.Destination -Force
}

if (Test-Path -LiteralPath $bundlePath) {
    Remove-Item -LiteralPath $bundlePath -Force
}

Compress-Archive -Path (Join-Path $releaseRoot "*") -DestinationPath $bundlePath -Force

Write-Host "Created release bundle:"
Write-Host $bundlePath
