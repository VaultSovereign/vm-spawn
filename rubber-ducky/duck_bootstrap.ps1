# duck_bootstrap.ps1 - VaultMesh bootstrap for Windows (prefers native PS)
param(
  [string]$RepoUrl = 'https://github.com/VaultSovereign/vm-spawn.git',
  [string]$ZipUrl  = 'https://github.com/VaultSovereign/vm-spawn/archive/refs/heads/main.zip'
)
$ErrorActionPreference = 'Stop'
try {
  $dst = Join-Path $env:USERPROFILE 'Downloads'
  if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
  Set-Location $dst

  if (-not (Test-Path '.\vm-spawn')) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
      git clone $RepoUrl
    } else {
      Write-Host 'git not found — downloading zip...'
      $zip = Join-Path $env:TEMP 'vm-spawn.zip'
      Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
      $tmpDir = Join-Path $dst 'vm-spawn-main'
      Expand-Archive -LiteralPath $zip -DestinationPath $dst -Force
      if (Test-Path $tmpDir) {
        Rename-Item -Path $tmpDir -NewName 'vm-spawn' -Force
      } elseif (-not (Test-Path (Join-Path $dst 'vm-spawn'))) {
        New-Item -ItemType Directory -Path (Join-Path $dst 'vm-spawn') | Out-Null
      }
      Remove-Item $zip -Force
    }
  } else {
    Write-Host 'vm-spawn already present'
  }

  Set-Location .\vm-spawn

  $psHealth = Join-Path (Join-Path (Get-Location) 'ops') 'bin\health-check.ps1'
  $bashHealth = Join-Path (Join-Path (Get-Location) 'ops') 'bin\health-check'

  if (Test-Path $psHealth) {
    Write-Host 'Running native PowerShell health-check...'
    & $psHealth
  } elseif (Test-Path $bashHealth) {
    Write-Host 'Running bash health-check...'
    if (Get-Command bash -ErrorAction SilentlyContinue) {
      bash $bashHealth
    } else {
      Write-Host 'bash not found; skipping health-check'
    }
  } else {
    Write-Host 'No health-check found'
  }

} catch {
  Write-Host 'bootstrap error:' $_.Exception.Message
  exit 2
}
