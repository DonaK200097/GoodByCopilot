param(
    [string]$OutputRoot = "dist",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $repoRoot $OutputRoot
$versionRoot = if ([string]::IsNullOrWhiteSpace($Version)) {
    Join-Path $releaseRoot "release"
} else {
    Join-Path $releaseRoot $Version
}
$bundlePath = Join-Path $releaseRoot "GoodByCopilot-release.zip"

New-Item -ItemType Directory -Force -Path $versionRoot | Out-Null

$requiredFiles = @(
    "GoodByCopilot.exe",
    "CoreGBC.exe"
)

foreach ($file in $requiredFiles) {
    $source = Join-Path $repoRoot $file
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing build artifact: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $versionRoot $file) -Force
}

$resourceDirs = @(
    @{ Source = (Join-Path $repoRoot "Core\default"); Destination = (Join-Path $versionRoot "Core\default") },
    @{ Source = (Join-Path $repoRoot "Core\LangPackage"); Destination = (Join-Path $versionRoot "Core\LangPackage") }
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

Compress-Archive -Path (Join-Path $versionRoot "*") -DestinationPath $bundlePath -Force

Write-Host "Release package created:"
Write-Host $bundlePath
