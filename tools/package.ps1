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

function Get-Crc32 {
    param([byte[]]$Bytes)

    [uint32]$crc = [uint32]::MaxValue
    [uint32]$polynomial = [Convert]::ToUInt32('EDB88320', 16)
    foreach ($byte in $Bytes) {
        $crc = $crc -bxor [uint32]$byte
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) {
                $crc = [uint32](($crc -shr 1) -bxor $polynomial)
            } else {
                $crc = [uint32]($crc -shr 1)
            }
        }
    }
    return [uint32]($crc -bxor [uint32]::MaxValue)
}

$crcSelfTest = Get-Crc32 ([Text.Encoding]::ASCII.GetBytes('123456789'))
if ($crcSelfTest -ne [Convert]::ToUInt32('CBF43926', 16)) {
    throw 'CRC-32 implementation failed its self-test.'
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

# Write a minimal ZIP with stored entries. This avoids runtime-dependent zlib
# output while preserving broad compatibility with standard ZIP extractors.
$utf8 = [Text.UTF8Encoding]::new($false)
$zipStream = [IO.File]::Open($output, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
$writer = [IO.BinaryWriter]::new($zipStream, $utf8, $true)
$entries = @()
try {
    $stagePrefix = $stageRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $packageFiles = @(Get-ChildItem -LiteralPath $stageRoot -Recurse -File -Force | Sort-Object FullName)
    foreach ($file in $packageFiles) {
        $entryName = $file.FullName.Substring($stagePrefix.Length).Replace('\', '/')
        $nameBytes = $utf8.GetBytes($entryName)
        $content = [IO.File]::ReadAllBytes($file.FullName)
        $size = [uint32]$content.Length
        $crc = Get-Crc32 $content
        $offset = [uint32]$zipStream.Position

        $writer.Write([uint32]0x04034b50)
        $writer.Write([uint16]20)
        $writer.Write([uint16]0x0800)
        $writer.Write([uint16]0)
        $writer.Write([uint16]0)
        $writer.Write([uint16]33)
        $writer.Write([uint32]$crc)
        $writer.Write($size)
        $writer.Write($size)
        $writer.Write([uint16]$nameBytes.Length)
        $writer.Write([uint16]0)
        $writer.Write($nameBytes)
        $writer.Write($content)

        $entries += [pscustomobject]@{
            NameBytes = $nameBytes
            Crc = [uint32]$crc
            Size = $size
            Offset = $offset
        }
    }

    $centralDirectoryOffset = [uint32]$zipStream.Position
    foreach ($entry in $entries) {
        $writer.Write([uint32]0x02014b50)
        $writer.Write([uint16]20)
        $writer.Write([uint16]20)
        $writer.Write([uint16]0x0800)
        $writer.Write([uint16]0)
        $writer.Write([uint16]0)
        $writer.Write([uint16]33)
        $writer.Write([uint32]$entry.Crc)
        $writer.Write([uint32]$entry.Size)
        $writer.Write([uint32]$entry.Size)
        $writer.Write([uint16]$entry.NameBytes.Length)
        $writer.Write([uint16]0)
        $writer.Write([uint16]0)
        $writer.Write([uint16]0)
        $writer.Write([uint16]0)
        $writer.Write([uint32]0)
        $writer.Write([uint32]$entry.Offset)
        $writer.Write([byte[]]$entry.NameBytes)
    }
    $centralDirectorySize = [uint32]($zipStream.Position - $centralDirectoryOffset)

    $writer.Write([uint32]0x06054b50)
    $writer.Write([uint16]0)
    $writer.Write([uint16]0)
    $writer.Write([uint16]$entries.Count)
    $writer.Write([uint16]$entries.Count)
    $writer.Write($centralDirectorySize)
    $writer.Write($centralDirectoryOffset)
    $writer.Write([uint16]0)
} finally {
    $writer.Dispose()
    $zipStream.Dispose()
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($output)
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($entry in $archive.Entries) {
        if ($entry.Length -ne $entry.CompressedLength) {
            throw "Package entry is unexpectedly compressed: $($entry.FullName)"
        }
    }
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
[IO.File]::WriteAllText(
    $checksumOutput,
    "$hash  $(Split-Path -Leaf $output)`n",
    [Text.UTF8Encoding]::new($false)
)
Write-Host "Created $output"
Write-Host "Created $checksumOutput"
