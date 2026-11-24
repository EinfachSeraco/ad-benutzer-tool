# AD-Benutzer-Tool

PowerShell-Werkzeug mit grafischer Oberflaeche (Windows Forms), um neue Active-Directory-Benutzer anhand eines Vorlage-Benutzers anzulegen.

## Funktionen

- Domain Controller abfragen und auswaehlen
- Vorlage-Benutzer suchen und auswaehlen
- Neuen Benutzer aus Vorname und Nachname anlegen
  - UPN-Praefix wird automatisch erzeugt (verschiedene Formate, Umlaute werden umgewandelt)
  - UPN-Praefix optional manuell festlegbar
  - UPN-Suffix wird aus dem AD geladen und ist auswaehlbar
- Gruppenmitgliedschaften der Vorlage uebernehmen (einzeln abwaehlbar)
- Optional Attribute uebernehmen (Abteilung, Firma, Buero, Manager, Adresse, Anmeldeskript, Basisordner, Profilpfad)
- Pruefung auf vorhandenen Anmeldenamen, UPN und Namen in der OU

## Dateien

| Datei | Zweck |
|---|---|
| `AD-Benutzer-Kopieren.ps1` | Das eigentliche Programm |
| `Build-Exe.ps1` | Erstellt mit PS2EXE die Datei `AD-Benutzer-Kopieren.exe` |
| `Install.ps1` | Installiert die EXE nach `C:\Program Files`, legt Verknuepfungen und einen Eintrag in "Programme und Features" an |

## Voraussetzungen

- Windows PowerShell 5.1
- RSAT: ActiveDirectory-PowerShell-Modul
- Ein Konto, das Benutzer anlegen und Gruppen aendern darf

## Verwendung

Skript direkt starten:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD-Benutzer-Kopieren.ps1
```

EXE erstellen (laedt PS2EXE einmalig in den Ordner `_modules`):

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Build-Exe.ps1
```

Installieren (fragt nach Administratorrechten, `-Desktop` legt zusaetzlich eine Desktop-Verknuepfung an):

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Desktop
```

Deinstallieren ueber "Programme und Features" oder:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Uninstall
```

## Hinweise

- Alle Skripte sind reines ASCII, damit es keine Probleme mit der Datei-Kodierung gibt.
- Virenscanner (z. B. Defender) melden PS2EXE und damit erstellte EXE-Dateien manchmal faelschlich. Eine Signatur mit einem Code-Signing-Zertifikat hilft.
- Der Basisordner wird nur im AD eingetragen, nicht auf dem Dateiserver angelegt.
