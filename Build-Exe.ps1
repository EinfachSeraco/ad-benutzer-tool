# Erstellt aus AD-Benutzer-Kopieren.ps1 eine EXE-Datei (mit dem Modul PS2EXE).
#
# Aufruf (im Ordner, in dem auch AD-Benutzer-Kopieren.ps1 liegt):
#   powershell.exe -ExecutionPolicy Bypass -File .\Build-Exe.ps1
#   powershell.exe -ExecutionPolicy Bypass -File .\Build-Exe.ps1 -IconFile .\symbol.ico
#
# PS2EXE wird NICHT nach "Dokumente" installiert, sondern in den Unterordner
# _modules neben diesem Skript geladen.
#
# Ergebnis: AD-Benutzer-Kopieren.exe im selben Ordner.

param(
    [string]$IconFile,
    [string]$Version = '1.0.0.0'
)

$ErrorActionPreference = 'Stop'

$src     = Join-Path $PSScriptRoot 'AD-Benutzer-Kopieren.ps1'
$out     = Join-Path $PSScriptRoot 'AD-Benutzer-Kopieren.exe'
$modRoot = Join-Path $PSScriptRoot '_modules'

if (-not (Test-Path $src)) { throw "Skript nicht gefunden: $src" }

# --- PS2EXE in den lokalen Ordner _modules laden (einmalig) ---
$psd1 = Get-ChildItem -Path (Join-Path $modRoot 'ps2exe') -Filter 'ps2exe.psd1' -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
if (-not $psd1) {
    Write-Host 'PS2EXE wird aus der PowerShell Gallery geladen ...' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $modRoot -Force | Out-Null
    Save-Module -Name ps2exe -Path $modRoot -Repository PSGallery -Force
    $psd1 = Get-ChildItem -Path (Join-Path $modRoot 'ps2exe') -Filter 'ps2exe.psd1' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
    if (-not $psd1) { throw "PS2EXE konnte nicht nach $modRoot geladen werden (evtl. vom Virenscanner blockiert)." }
}
Import-Module $psd1.FullName -Force

if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    throw 'Der Befehl Invoke-ps2exe ist nicht verfuegbar. Wahrscheinlich hat der Virenscanner Dateien von PS2EXE entfernt.'
}

# --- EXE erzeugen ---
$params = @{
    inputFile   = $src
    outputFile  = $out
    noConsole   = $true      # kein schwarzes Konsolenfenster
    STA         = $true      # noetig fuer Windows Forms
    title       = 'AD-Benutzer anhand Vorlage anlegen'
    description = 'Legt AD-Benutzer anhand eines Vorlage-Benutzers an'
    product     = 'AD-Benutzer-Kopieren'
    version     = $Version
}
if ($IconFile) {
    if (-not (Test-Path $IconFile)) { throw "Symboldatei nicht gefunden: $IconFile" }
    $params.iconFile = (Resolve-Path $IconFile).Path
}

Write-Host "Erzeuge $out ..." -ForegroundColor Cyan
Invoke-ps2exe @params

if (Test-Path $out) {
    Write-Host "Fertig: $out" -ForegroundColor Green
} else {
    throw 'Die EXE wurde nicht erzeugt (evtl. vom Virenscanner blockiert).'
}
