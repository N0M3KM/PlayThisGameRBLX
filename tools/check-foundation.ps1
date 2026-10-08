param([string]$RojoPath = 'rojo', [switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$ptgRoot = Split-Path $PSScriptRoot -Parent
Push-Location $ptgRoot
try {
  $ptgBin = Join-Path $PSScriptRoot 'toolchain/bin'
  & (Join-Path $PSScriptRoot 'setup-require-paths.ps1')
  $ptgShells = @(Get-ChildItem -LiteralPath 'src/server/Services' -Filter 'Stub.luau' -Recurse | ForEach-Object { @{ path = $_.FullName; content = [System.IO.File]::ReadAllText($_.FullName) } })
  if (@($ptgShells | Where-Object { $_.content.Contains('return function(): ServiceStub.Stub') }).Count -gt 0) {
    throw 'Service shells must expose their typed domain interface before M1'
  }
  $ptgSource = @('src/shared/Contracts','src/shared/Config','src/shared/Framework','src/shared/Registry','src/shared/Util','src/server/Infrastructure','src/server/Services','src/server/Boot','src/server/init.server.luau','src/client/init.client.luau','src/client/Controllers','assets/Maps','tests/fixtures','tests/unit','tools/test-unit.luau','tools/studio')
  & "$ptgBin/stylua.exe" --check @ptgSource
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  if (-not $SkipTests) {
    & "$ptgBin/lune.exe" run tools/test-unit.luau
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  # Engine catalog entry points, lifecycle and persistence runtime adapters are checked below.
  & "$ptgBin/luau-lsp.exe" analyze --platform=standard --ignore='src/shared/Config/Maps/init.luau' --ignore='src/shared/Config/Scenarios/init.luau' --ignore='src/server/Infrastructure/ServiceLifecycle.luau' --ignore='src/server/Infrastructure/Adapters/**' src/shared src/server/Infrastructure tests/fixtures tests/unit tools/test-unit.luau
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & "$ptgBin/selene.exe" @ptgSource
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $RojoPath build foundation.project.json -o "$ptgBin/foundation.rbxlx"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $RojoPath sourcemap foundation.project.json --output "$ptgBin/foundation-sourcemap.json"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & "$ptgBin/luau-lsp.exe" analyze --platform=roblox --definitions="$ptgBin/roblox.d.luau" --sourcemap="$ptgBin/foundation-sourcemap.json" --ignore='Packages/**' --ignore='ServerPackages/**' @ptgSource
  exit $LASTEXITCODE
} catch {
  Write-Error $_ -ErrorAction Continue
  exit 1
} finally { Pop-Location }
