# Installiert (oder deinstalliert) AD-Benutzer-Kopieren.exe.
#
# Installieren (im Ordner mit der EXE):
#   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
#   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Desktop     # zusaetzlich Desktop-Verknuepfung
#
# Deinstallieren: ueber "Einstellungen > Apps" bzw. "Programme und Features"
# oder:
#   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Uninstall
#
# Was passiert:
#   - EXE nach C:\Program Files\AD-Benutzer-Kopieren kopieren
#   - Startmenue-Verknuepfung fuer alle Benutzer (optional auch auf dem Desktop)
#   - Eintrag unter "Programme und Features" mit Deinstallation

param(
    [switch]$Desktop,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$appName     = 'AD-Benutzer-Kopieren'
$displayName = 'AD-Benutzer anhand Vorlage anlegen'
$exeName     = 'AD-Benutzer-Kopieren.exe'
$version     = '1.0.0'
$installDir  = Join-Path $env:ProgramFiles $appName
$startMenu   = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\$displayName.lnk"
$desktopLnk  = Join-Path $env:PUBLIC "Desktop\$displayName.lnk"
$uninstKey   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$appName"

# --- Als Administrator neu starten, falls noetig ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Desktop)   { $argList += '-Desktop' }
    if ($Uninstall) { $argList += '-Uninstall' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    return
}

function New-Shortcut([string]$Path, [string]$Target) {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($Path)
    $lnk.TargetPath       = $Target
    $lnk.WorkingDirectory = Split-Path $Target
    $lnk.IconLocation     = "$Target,0"
    $lnk.Description      = $displayName
    $lnk.Save()
}

try {
    if ($Uninstall) {
        # ------------------------- Deinstallation -------------------------
        Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($exeName)) -ErrorAction SilentlyContinue | Stop-Process -Force
        foreach ($p in $startMenu, $desktopLnk) { if (Test-Path $p) { Remove-Item $p -Force } }
        if (Test-Path $uninstKey) { Remove-Item $uninstKey -Recurse -Force }

        if (Test-Path $installDir) {
            # Ordner verzoegert loeschen, da dieses Skript evtl. selbst darin liegt
            Start-Process -FilePath 'cmd.exe' -WindowStyle Hidden `
                -ArgumentList "/c timeout /t 2 /nobreak >nul & rmdir /s /q `"$installDir`""
        }
        Write-Host "$displayName wurde deinstalliert." -ForegroundColor Green
    }
    else {
        # ------------------------- Installation ---------------------------
        $srcExe = Join-Path $PSScriptRoot $exeName
        if (-not (Test-Path $srcExe)) {
            throw "$exeName wurde nicht gefunden in $PSScriptRoot. Bitte zuerst Build-Exe.ps1 ausfuehren."
        }
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            Write-Warning 'Das ActiveDirectory-Modul (RSAT) ist auf diesem Rechner nicht installiert. Das Programm startet sonst nicht.'
        }

        Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($exeName)) -ErrorAction SilentlyContinue | Stop-Process -Force
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        Copy-Item $srcExe -Destination $installDir -Force
        Copy-Item $PSCommandPath -Destination (Join-Path $installDir 'Install.ps1') -Force

        $targetExe = Join-Path $installDir $exeName
        New-Shortcut -Path $startMenu -Target $targetExe
        if ($Desktop) { New-Shortcut -Path $desktopLnk -Target $targetExe }

        # Eintrag in "Programme und Features"
        New-Item -Path $uninstKey -Force | Out-Null
        $uninstallCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installDir\Install.ps1`" -Uninstall"
        $values = @{
            DisplayName     = $displayName
            DisplayVersion  = $version
            Publisher       = 'IT'
            InstallLocation = $installDir
            DisplayIcon     = $targetExe
            UninstallString = $uninstallCmd
        }
        foreach ($k in $values.Keys) { Set-ItemProperty -Path $uninstKey -Name $k -Value $values[$k] }
        Set-ItemProperty -Path $uninstKey -Name NoModify -Value 1 -Type DWord
        Set-ItemProperty -Path $uninstKey -Name NoRepair -Value 1 -Type DWord
        $sizeKB = [int]((Get-Item $targetExe).Length / 1KB)
        Set-ItemProperty -Path $uninstKey -Name EstimatedSize -Value $sizeKB -Type DWord

        Write-Host "$displayName wurde installiert nach $installDir" -ForegroundColor Green
        Write-Host 'Startmenue-Verknuepfung wurde erstellt.' -ForegroundColor Green
        if ($Desktop) { Write-Host 'Desktop-Verknuepfung wurde erstellt.' -ForegroundColor Green }
    }
}
catch {
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''
Read-Host 'Zum Schliessen Enter druecken'
