param(
    [string]$Version = '0.1.3-typed-ftext-dev'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $repoRoot 'build'
$stageRoot = Join-Path $buildRoot "OblivionRenamer-$Version"
$packageRoot = Join-Path $stageRoot 'ue4ss\Mods'
$source = Join-Path $repoRoot 'src\OblivionRenamer'
$output = Join-Path $buildRoot "OblivionRenamer-$Version.zip"

$resolvedRepoRoot = [IO.Path]::GetFullPath($repoRoot)
$resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot)
$resolvedStageRoot = [IO.Path]::GetFullPath($stageRoot)
if (-not $resolvedBuildRoot.StartsWith($resolvedRepoRoot, [StringComparison]::OrdinalIgnoreCase) -or
    -not $resolvedStageRoot.StartsWith($resolvedBuildRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to clean a staging path outside this repository build folder.'
}

if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
if (Test-Path -LiteralPath $output) {
    Remove-Item -LiteralPath $output -Force
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $packageRoot 'OblivionRenamer') -Recurse
Compress-Archive -LiteralPath (Join-Path $stageRoot 'ue4ss') -DestinationPath $output
Write-Host "Created $output"
