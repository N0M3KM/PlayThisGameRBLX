$ErrorActionPreference = 'Stop'
$ptgToolRoot = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Path $ptgToolRoot -Force | Out-Null
$ptgTools = @(
  @{ Repo = 'JohnnyMorganz/StyLua'; Tag = 'v2.5.2'; Asset = 'stylua-windows-x86_64.zip' },
  @{ Repo = 'Kampfkarren/selene'; Tag = '0.31.0'; Asset = 'selene-0.31.0-windows.zip' },
  @{ Repo = 'JohnnyMorganz/luau-lsp'; Tag = '1.70.1'; Asset = 'luau-lsp-win64.zip' },
  @{ Repo = 'lune-org/lune'; Tag = 'v0.10.5'; Asset = 'lune-0.10.5-windows-x86_64.zip' }
)
foreach ($ptgTool in $ptgTools) {
  $ptgRelease = Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $ptgTool.Repo + '/releases/tags/' + $ptgTool.Tag)
  $ptgAsset = @($ptgRelease.assets | Where-Object { $_.name -eq $ptgTool.Asset })
  if ($ptgAsset.Count -ne 1) { throw ('Missing official asset: ' + $ptgTool.Asset) }
  $ptgArchive = Join-Path $ptgToolRoot $ptgTool.Asset
  Invoke-WebRequest -Uri $ptgAsset[0].browser_download_url -OutFile $ptgArchive -UseBasicParsing
  if ($ptgAsset[0].digest -and $ptgAsset[0].digest.StartsWith('sha256:')) {
    $ptgHash = (Get-FileHash -LiteralPath $ptgArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ('sha256:' + $ptgHash -ne $ptgAsset[0].digest) { throw 'Release digest mismatch' }
  }
  Expand-Archive -LiteralPath $ptgArchive -DestinationPath $ptgToolRoot -Force
  Write-Output ('Installed ' + $ptgTool.Repo + ' ' + $ptgTool.Tag)
}
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau' -OutFile (Join-Path $ptgToolRoot 'roblox.d.luau') -UseBasicParsing
Push-Location $ptgToolRoot
try {
  & './lune.exe' setup
  if ($LASTEXITCODE -ne 0) { throw 'Lune definition setup failed' }
} finally { Pop-Location }
$ptgDefinitionSource = Join-Path $env:USERPROFILE '.lune/.typedefs/0.10.5'
$ptgDefinitionTarget = Join-Path $ptgToolRoot 'lune-types'
New-Item -ItemType Directory -Path $ptgDefinitionTarget -Force | Out-Null
Get-ChildItem -LiteralPath $ptgDefinitionSource | Copy-Item -Destination $ptgDefinitionTarget -Recurse -Force
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'setup-require-paths.ps1')
