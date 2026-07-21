param(
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$versionFile = Join-Path $repoRoot 'VERSION'
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
}
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw "Invalid semantic version: $Version"
}

$buildRoot = Join-Path $repoRoot 'build'
$stageRoot = Join-Path $buildRoot "OblivionRenamer-$Version"
$packageRoot = Join-Path $stageRoot 'ue4ss\Mods'
$source = Join-Path $repoRoot 'src\OblivionRenamer'
$packageModRoot = Join-Path $packageRoot 'OblivionRenamer'
$output = Join-Path $buildRoot "OblivionRenamer-$Version.zip"
$checksumOutput = "$output.sha256"

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
if (Test-Path -LiteralPath $checksumOutput) {
    Remove-Item -LiteralPath $checksumOutput -Force
}

New-Item -ItemType Directory -Path (Join-Path $packageModRoot 'scripts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $packageModRoot 'undo') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $source 'enabled.txt') -Destination $packageModRoot
Copy-Item -LiteralPath (Join-Path $source 'scripts\main.lua') -Destination (Join-Path $packageModRoot 'scripts')
Copy-Item -LiteralPath (Join-Path $source 'undo\.gitkeep') -Destination (Join-Path $packageModRoot 'undo')

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($output, [IO.Compression.ZipArchiveMode]::Create)
try {
    $stagePrefix = $stageRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $packageFiles = @(Get-ChildItem -LiteralPath $stageRoot -Recurse -File | Sort-Object FullName)
    foreach ($file in $packageFiles) {
        $entryName = $file.FullName.Substring($stagePrefix.Length).Replace('\', '/')
        $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $inputStream = $file.OpenRead()
        $outputStream = $entry.Open()
        try {
            $inputStream.CopyTo($outputStream)
        } finally {
            $outputStream.Dispose()
            $inputStream.Dispose()
        }
    }
} finally {
    $archive.Dispose()
}

$archive = [IO.Compression.ZipFile]::OpenRead($output)
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
} finally {
    $archive.Dispose()
}

foreach ($requiredEntry in @(
    'ue4ss/Mods/OblivionRenamer/enabled.txt',
    'ue4ss/Mods/OblivionRenamer/scripts/main.lua',
    'ue4ss/Mods/OblivionRenamer/undo/.gitkeep'
)) {
    if ($entryNames -notcontains $requiredEntry) {
        throw "Package is missing required entry: $requiredEntry"
    }
}
if ($entryNames -match 'diagnostics|last-rename\.txt|\.log$') {
    throw 'Package contains a development diagnostic or generated runtime file.'
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumOutput -Value "$hash  $(Split-Path -Leaf $output)" -Encoding ascii
Write-Host "Created $output"
Write-Host "Created $checksumOutput"
