param(
    [string]$Version = "",
    [string]$Ahk2ExePath = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe",
    [string]$BaseExePath = "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$exeFiles = @(
    (Join-Path $repoRoot "GoodByCopilot.exe"),
    (Join-Path $repoRoot "CoreGBC.exe")
)

foreach ($file in $exeFiles) {
    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force
    }
}

& (Join-Path $PSScriptRoot "build-release-local.ps1") -Version $Version -Ahk2ExePath $Ahk2ExePath -BaseExePath $BaseExePath
