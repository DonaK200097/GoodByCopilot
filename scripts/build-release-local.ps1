param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $repoRoot "dist"
$releaseRoot = if ([string]::IsNullOrWhiteSpace($Version)) {
    Join-Path $distRoot "release"
} else {
    Join-Path $distRoot $Version
}
$bundlePath = Join-Path $distRoot ("GoodByCopilot-" + ($(if ($Version) { $Version } else { "release" })) + ".zip")

$requiredFiles = @(
    "GoodByCopilot.exe",
    "CoreGBC.exe"
)

New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null

foreach ($file in $requiredFiles) {
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
