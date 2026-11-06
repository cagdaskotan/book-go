[CmdletBinding()]
param(
  [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'

$connections = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
foreach ($connection in $connections) {
  if (-not $connection.OwningProcess) { continue }

  $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
  if (-not $process) { continue }

  Write-Host "Port $Port kullanimda. Mevcut surec kapatiliyor: $($process.ProcessName) (PID $($process.Id))"
  Stop-Process -Id $process.Id -Force
}

Start-Sleep -Milliseconds 500

Write-Host "Go backend baslatiliyor: http://localhost:$Port"
& go run cmd/bookapp/main.go
