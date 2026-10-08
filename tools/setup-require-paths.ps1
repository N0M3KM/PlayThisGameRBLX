$ErrorActionPreference = 'Stop'
$ptgRoot = Split-Path $PSScriptRoot -Parent
$ptgBin = Join-Path $PSScriptRoot 'toolchain/bin'
$ptgMirror = Join-Path $ptgBin 'datamodel'

# Roblox resolves @game through the DataModel. Headless tools resolve the same
# paths through generated junctions, keeping one source copy for both runtimes.
$ptgMappings = @(
  @{ Relative = 'ReplicatedStorage/Shared'; Source = 'src/shared' },
  @{ Relative = 'ServerScriptService/Server'; Source = 'src/server' }
)
foreach ($ptgMapping in $ptgMappings) {
  $ptgTarget = (Resolve-Path -LiteralPath (Join-Path $ptgRoot $ptgMapping.Source)).Path
  $ptgLink = Join-Path $ptgMirror $ptgMapping.Relative
  New-Item -ItemType Directory -Path (Split-Path $ptgLink -Parent) -Force | Out-Null
  if (Test-Path -LiteralPath $ptgLink) {
    $ptgExisting = Get-Item -LiteralPath $ptgLink -Force
    if ($ptgExisting.LinkType -ne 'Junction' -or @($ptgExisting.Target).Count -ne 1 -or
        [System.IO.Path]::GetFullPath($ptgExisting.Target[0]) -ne [System.IO.Path]::GetFullPath($ptgTarget)) {
      throw "Require mirror path is already owned by different content: $ptgLink"
    }
  } else {
    New-Item -ItemType Junction -Path $ptgLink -Target $ptgTarget | Out-Null
  }
}

# Lune setup writes a nearer config in bin. Include both aliases there so a
# module reached through the mirror can still resolve @game and @lune.
$ptgGeneratedConfig = @{
  aliases = @{ game = './datamodel/'; lune = './lune-types/' }
} | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText((Join-Path $ptgBin '.luaurc'), $ptgGeneratedConfig)
