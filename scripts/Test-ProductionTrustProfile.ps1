param(
  [Parameter(Mandatory)]
  [string]$PublicKeyBlob,

  [Parameter(Mandatory)]
  [ValidatePattern('^[0-9a-f]{64}$')]
  [string]$PublicKeySha256,

  [string]$CMake = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $root 'cmake-build-production-profile-test'
$common = @(
  '-S', $root,
  '-A', 'x64',
  '-DPAWNIO_PRODUCTION_BUILD=ON',
  '-DPAWNIO_UNRESTRICTED=OFF',
  '-DPAWNIO_TRUST_UPSTREAM=OFF',
  "-DPAWNIO_CUSTOM_TRUST_KEY_BLOB=$PublicKeyBlob",
  "-DPAWNIO_CUSTOM_TRUST_KEY_SHA256=$PublicKeySha256",
  '-DPAWNIO_NAME=SofthePawnIO',
  '-DPAWNIO_NAME_FULL=SofthePawnIOProductionDriver',
  '-DPAWNIO_AUTHOR=Softhe'
)

function Invoke-ExpectedFailure {
  param([string]$Name, [string[]]$Arguments)

  & $CMake @Arguments *> (Join-Path $buildRoot "$Name.log")
  if ($LASTEXITCODE -eq 0) {
    throw "Expected failure did not occur: $Name"
  }
  Write-Host "PASS (rejected): $Name"
}

New-Item -ItemType Directory -Force $buildRoot | Out-Null

$releaseDir = Join-Path $buildRoot 'release'
& $CMake @common '-B' $releaseDir
if ($LASTEXITCODE -ne 0) { throw 'Production profile configuration failed' }
& $CMake --build $releaseDir --config Release --parallel
if ($LASTEXITCODE -ne 0) { throw 'Production Release build failed' }
Write-Host 'PASS: production Release build'

Invoke-ExpectedFailure 'debug-build' @('--build', $releaseDir, '--config', 'Debug', '--parallel')
Invoke-ExpectedFailure 'unrestricted' @($common + '-B' + (Join-Path $buildRoot 'unrestricted') + '-DPAWNIO_UNRESTRICTED=ON')
Invoke-ExpectedFailure 'upstream-trust' @($common + '-B' + (Join-Path $buildRoot 'upstream-trust') + '-DPAWNIO_TRUST_UPSTREAM=ON')
Invoke-ExpectedFailure 'missing-fingerprint' @($common + '-B' + (Join-Path $buildRoot 'missing-fingerprint') + '-DPAWNIO_CUSTOM_TRUST_KEY_SHA256=')
Invoke-ExpectedFailure 'wrong-fingerprint' @($common + '-B' + (Join-Path $buildRoot 'wrong-fingerprint') + '-DPAWNIO_CUSTOM_TRUST_KEY_SHA256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')

Write-Host 'All production trust-profile checks passed.'
