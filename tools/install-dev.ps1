param(
    [Parameter(Mandatory = $true)]
    [string]$WinGDKPath
)

$ErrorActionPreference = 'Stop'
if (Get-Process -Name @(
    'OblivionRemastered-WinGDK-Shipping',
    'OblivionRemastered-Win64-Shipping'
) -ErrorAction SilentlyContinue) {
    throw 'Close Oblivion Remastered before installing a development build.'
}

$resolvedWinGDK = (Resolve-Path -LiteralPath $WinGDKPath).Path
$shippingExecutable = Get-ChildItem -LiteralPath $resolvedWinGDK -File -Filter 'OblivionRemastered-*-Shipping.exe'
if ($shippingExecutable.Count -ne 1) {
    throw "Expected one Oblivion Remastered shipping executable in: $resolvedWinGDK"
}

$modsRoot = Join-Path $resolvedWinGDK 'ue4ss\Mods'
if (-not (Test-Path -LiteralPath $modsRoot)) {
    throw "UE4SS Mods folder was not found: $modsRoot"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $PSScriptRoot 'validate.ps1'
& $validator

$source = Join-Path $repoRoot 'src\OblivionRenamer'
$destination = Join-Path $modsRoot 'OblivionRenamer'
$backupRoot = Join-Path $repoRoot 'artifacts\dev-backups'

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
if (Test-Path -LiteralPath $destination) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    Move-Item -LiteralPath $destination -Destination (Join-Path $backupRoot "OblivionRenamer-$timestamp")
}

Copy-Item -LiteralPath $source -Destination $destination -Recurse
Write-Host "Installed development build to $destination"
