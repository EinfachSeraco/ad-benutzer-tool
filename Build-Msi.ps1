# Erstellt aus AD-Benutzer-Kopieren.exe ein MSI-Paket (mit WiX Toolset v5).
#
# Voraussetzungen:
#   - AD-Benutzer-Kopieren.exe wurde mit Build-Exe.ps1 erstellt
#   - .NET SDK 6 oder neuer (fuer das WiX-Kommandozeilenwerkzeug "wix")
#     https://dotnet.microsoft.com/download
#
# Aufruf:
#   powershell.exe -ExecutionPolicy Bypass -File .\Build-Msi.ps1
#
# Ergebnis: AD-Benutzer-Tool-<Version>.msi im selben Ordner.
#
# Installation des MSI (z. B. per GPO, Intune oder manuell):
#   msiexec /i AD-Benutzer-Tool-<Version>.msi /qn
#   msiexec /i AD-Benutzer-Tool-<Version>.msi /qn DESKTOPSHORTCUT=1

param(
    [string]$Version            # leer = aus $AppVersion in AD-Benutzer-Kopieren.ps1
)

$ErrorActionPreference = 'Stop'

$WixVersion = '5.0.2'
$src = Join-Path $PSScriptRoot 'AD-Benutzer-Kopieren.ps1'
$exe = Join-Path $PSScriptRoot 'AD-Benutzer-Kopieren.exe'
$wxs = Join-Path $PSScriptRoot 'installer\AD-Benutzer-Tool.wxs'

if (-not (Test-Path $exe)) { throw "EXE nicht gefunden: $exe - bitte zuerst Build-Exe.ps1 ausfuehren." }
if (-not (Test-Path $wxs)) { throw "WiX-Quelldatei nicht gefunden: $wxs" }

# --- Version bestimmen (MSI: drei Stellen) ---
if (-not $Version) {
    $m = Select-String -Path $src -Pattern '^\$AppVersion\s*=\s*''([0-9.]+)''' | Select-Object -First 1
    $Version = if ($m) { $m.Matches[0].Groups[1].Value } else { '1.0.0' }
}
$parts = @($Version -split '\.')
while ($parts.Count -lt 3) { $parts += '0' }
$Version = ($parts[0..2]) -join '.'
Write-Host "Version: $Version" -ForegroundColor Cyan

# --- WiX bereitstellen ---
$toolsDir = Join-Path $env:USERPROFILE '.dotnet\tools'
if (($env:PATH -split ';') -notcontains $toolsDir) { $env:PATH += ";$toolsDir" }

if (-not (Get-Command wix -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw '.NET SDK nicht gefunden. Bitte installieren: https://dotnet.microsoft.com/download'
    }
    Write-Host "WiX $WixVersion wird installiert ..." -ForegroundColor Cyan
    dotnet tool install --global wix --version $WixVersion
    if ($LASTEXITCODE -ne 0) { throw 'WiX konnte nicht installiert werden.' }
}

# --- MSI bauen ---
$out = Join-Path $PSScriptRoot "AD-Benutzer-Tool-$Version.msi"
Write-Host "Erzeuge $out ..." -ForegroundColor Cyan
wix build $wxs -arch x64 -d "Version=$Version" -d "ExePath=$exe" -o $out
if ($LASTEXITCODE -ne 0) { throw 'wix build ist fehlgeschlagen.' }

Write-Host "Fertig: $out" -ForegroundColor Green
