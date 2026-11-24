# Копирует аддоны из репозитория в папку AddOns клиента WoW Forever.
# Запуск: powershell -File tools\sync.ps1 [-Addon BagBroker]
param(
    [string]$Addon = "BagBroker",
    [string]$Game = "C:\Games\World of Warcraft\_forever_\Interface\AddOns"
)
$src = Join-Path $PSScriptRoot "..\$Addon"
$dst = Join-Path $Game $Addon
robocopy $src $dst /MIR /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }
Write-Host "$Addon -> $dst"
