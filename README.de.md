# AD-Benutzer-Tool

[English](README.md) | **Deutsch**

Ein Windows-PowerShell-Werkzeug mit grafischer Oberfläche (Windows Forms). Es legt neue Active-Directory-Benutzer anhand eines vorhandenen Vorlage-Benutzers an. Dabei übernimmt es die Gruppenmitgliedschaften (Berechtigungen) der Vorlage und auf Wunsch ihre organisatorischen Attribute. Den UPN erzeugt es aus Vor- und Nachname.

---

## Inhalt

- [Funktionen](#funktionen)
- [Voraussetzungen](#voraussetzungen)
- [Schnellstart](#schnellstart)
- [Bedienung](#bedienung)
- [So wird der UPN gebildet](#so-wird-der-upn-gebildet)
- [Was von der Vorlage übernommen wird](#was-von-der-vorlage-übernommen-wird)
- [Installationsmöglichkeiten](#installationsmöglichkeiten)
- [Selbst bauen](#selbst-bauen)
- [Automatischer Build und Releases (GitHub Actions)](#automatischer-build-und-releases-github-actions)
- [Aufbau des Repositorys](#aufbau-des-repositorys)
- [Fehlerbehebung](#fehlerbehebung)
- [Sicherheitshinweise](#sicherheitshinweise)

---

## Funktionen

- **Auswahl des Domain Controllers.** Alle DCs der Domäne werden aufgelistet. Der aktuelle Anmeldeserver ist vorausgewählt, ein DC-Name kann auch eingetippt werden.
- **Suche nach dem Vorlage-Benutzer.** Gesucht wird nach Name, Anmeldename, UPN, Vorname oder Nachname (bis zu 200 Treffer).
- **Neuer Benutzer aus Vor- und Nachname:**
  - Das UPN-Präfix (der Teil vor dem `@`) wird automatisch erzeugt, in einem von 7 Formaten.
  - Umlaute und Akzente werden umgewandelt (`ä → ae`, `ß → ss`, `é → e`).
  - Das UPN-Präfix kann manuell festgelegt werden.
  - Das UPN-Suffix (der Teil nach dem `@`) wird aus dem AD geladen und ist auswählbar: Domäne, UPN-Suffixe der Gesamtstruktur und weitere Domänen.
  - Der Anmeldename (sAMAccountName) wird aus dem UPN-Präfix gebildet (max. 20 Zeichen) und ist änderbar.
- **E-Mail-Adresse.** Standardmäßig ist sie gleich dem UPN. Sie kann aber frei eingegeben oder leer gelassen werden.
- **Kennwort-Generator.** Erzeugt ein 16-stelliges Zufallskennwort mit Groß- und Kleinbuchstaben, Ziffern und Sonderzeichen. Leicht verwechselbare Zeichen werden weggelassen. Das Kennwort kann angezeigt und in die Zwischenablage kopiert werden.
- **Gruppen.** Die Gruppen der Vorlage erscheinen mit Häkchen. Alle sind vorausgewählt, einzelne lassen sich abwählen.
- **Attribute (optional).** Übernimmt Abteilung, Firma, Büro, Manager, Adresse, Anmeldeskript, Basisordner und Profilpfad.
- **Sicherheitsprüfungen vor dem Anlegen.** Das Tool prüft, ob Anmeldename, UPN, E-Mail-Adresse oder der Name in der Ziel-OU schon vorhanden sind. Danach zeigt es eine Zusammenfassung, die bestätigt werden muss.
- **Protokollfenster.** Zeigt alle Schritte und Fehler an.

## Voraussetzungen

| Voraussetzung | Details |
|---|---|
| Betriebssystem | Windows 10/11 oder Windows Server 2016+ |
| PowerShell | Windows PowerShell 5.1 (in Windows enthalten) |
| AD-Modul | RSAT: *Active Directory Domain Services and Lightweight Directory Services Tools* |
| Berechtigungen | Ein Konto, das in der Ziel-OU Benutzer anlegen und Gruppenmitgliedschaften ändern darf |

RSAT unter Windows 10/11 installieren (als Administrator):

```powershell
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

Unter Windows Server:

```powershell
Install-WindowsFeature RSAT-AD-PowerShell
```

## Schnellstart

1. Öffne auf der GitHub-Seite rechts **Releases** und lade die neueste Version herunter:
   - `AD-Benutzer-Tool-x.y.z.msi`: Installationspaket (empfohlen)
   - `AD-Benutzer-Kopieren.exe`: läuft ohne Installation
   - `AD-Benutzer-Tool-x.y.z.zip`: EXE, Skript und Dokumentation
2. Installiere das MSI oder starte die EXE direkt.
3. Starte **„AD-Benutzer anlegen“** aus dem Startmenü.

Alternativ kannst du das Skript ohne Build direkt starten:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD-Benutzer-Kopieren.ps1
```

## Bedienung

Das Fenster hat vier Bereiche.

| # | Bereich | Vorgehen |
|---|---|---|
| 1 | **Domain Controller** | DC auswählen oder Namen eintippen und Enter drücken. Domäne, Standort und UPN-Suffixe werden geladen. |
| 2 | **Vorlage-Benutzer suchen** | Suchbegriff eingeben, **Suchen** klicken, dann den Vorlage-Benutzer in der Liste anklicken. |
| 3 | **Neuer Benutzer** | Vorname und Nachname eingeben. UPN-Format wählen, oder *UPN-Präfix manuell festlegen* ankreuzen und das Präfix selbst eingeben. UPN-Suffix wählen. E-Mail prüfen, Kennwort setzen (**Generieren** erzeugt eines) und die Ziel-OU prüfen (sie wird von der Vorlage übernommen). |
| 4 | **Gruppenmitgliedschaften** | Gruppen abwählen, die der neue Benutzer nicht bekommen soll. |

Klicke dann auf **Benutzer anlegen**, prüfe die Zusammenfassung und bestätige. Das Ergebnis steht im Protokoll rechts.

Optionen im Bereich 3:

| Option | Bedeutung |
|---|---|
| *Kennwort bei nächster Anmeldung ändern* | Der Benutzer muss das Kennwort bei der ersten Anmeldung ändern |
| *Konto aktivieren* | Das Konto ist sofort aktiv |
| *Attribute übernehmen* | Attribute von der Vorlage kopieren (siehe unten) |
| *= UPN* (neben E-Mail) | Die E-Mail-Adresse folgt automatisch dem UPN |
| *Kennwort anzeigen* | Das Kennwort wird im Klartext angezeigt |

## So wird der UPN gebildet

Beispiel: Vorname **Jörg**, Nachname **Müller-Weiß**

| Format | Ergebnis |
|---|---|
| `vorname.nachname` | `joerg.mueller-weiss` |
| `v.nachname` | `j.mueller-weiss` |
| `vnachname` | `jmueller-weiss` |
| `vornamenachname` | `joergmueller-weiss` |
| `nachname.vorname` | `mueller-weiss.joerg` |
| `nachnamev` | `mueller-weissj` |
| `vorname.n` | `joerg.m` |

Regeln:
- Alles wird in Kleinbuchstaben umgewandelt.
- `ä ö ü ß` werden zu `ae oe ue ss`, andere Akzente werden entfernt.
- Leerzeichen und alle Zeichen außer `a-z 0-9 . - _` werden entfernt.
- Der Anmeldename (sAMAccountName) ist das UPN-Präfix, gekürzt auf 20 Zeichen.

## Was von der Vorlage übernommen wird

**Immer:**
- Ziel-OU: Die OU der Vorlage wird vorgeschlagen und ist änderbar.
- Gruppenmitgliedschaften: die im Bereich 4 ausgewählten Gruppen.

**Mit „Attribute übernehmen“:**

`Department` (Abteilung), `Company` (Firma), `Office` (Büro), `Title` (Position), `Description` (Beschreibung), `Manager`, `StreetAddress`, `City`, `PostalCode`, `State`, `Country`, `HomePage`, `ScriptPath` (Anmeldeskript), `HomeDrive`, `HomeDirectory` (Basisordner), `ProfilePath` (Profilpfad)

In `HomeDirectory` und `ProfilePath` wird der Anmeldename der Vorlage durch den neuen Anmeldenamen ersetzt.

**Nicht übernommen:**
- Die Primärgruppe. Sie setzt das AD automatisch, meist auf *Domänen-Benutzer*.
- Der Basisordner auf dem Dateiserver wird nur im AD eingetragen, der Ordner selbst wird **nicht** angelegt.
- Exchange- oder Microsoft-365-Postfach, Lizenzen und Telefonnummern.

## Installationsmöglichkeiten

### MSI (empfohlen, auch für GPO oder Intune)

```powershell
# interaktiv
msiexec /i AD-Benutzer-Tool-1.1.0.msi

# still (ohne Rückfragen)
msiexec /i AD-Benutzer-Tool-1.1.0.msi /qn

# still, mit Desktop-Verknüpfung
msiexec /i AD-Benutzer-Tool-1.1.0.msi /qn DESKTOPSHORTCUT=1

# deinstallieren
msiexec /x AD-Benutzer-Tool-1.1.0.msi /qn
```

- Installiert nach `C:\Program Files\AD-Benutzer-Tool`.
- Legt eine Startmenü-Verknüpfung für alle Benutzer an.
- Eine neuere MSI-Version ersetzt die alte automatisch (Major Upgrade).

### Install.ps1 (ohne MSI)

Lege `Install.ps1` neben `AD-Benutzer-Kopieren.exe`:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Desktop
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Uninstall
```

Das Skript fragt nach Administratorrechten, kopiert die EXE nach `C:\Program Files\AD-Benutzer-Kopieren` und legt Verknüpfungen an. Außerdem trägt es das Programm unter *Programme und Features* ein.

> Verwende **entweder** das MSI **oder** Install.ps1, nicht beides.

## Selbst bauen

Repository klonen:

```powershell
git clone https://github.com/EinfachSeraco/ad-benutzer-tool.git
cd ad-benutzer-tool
```

**EXE.** Beim ersten Mal wird Internet benötigt, um PS2EXE nach `_modules\` zu laden:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Build-Exe.ps1
powershell.exe -ExecutionPolicy Bypass -File .\Build-Exe.ps1 -IconFile .\symbol.ico
```

**MSI.** Benötigt die EXE und das [.NET SDK](https://dotnet.microsoft.com/download). WiX v5 wird automatisch als dotnet-Tool installiert:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Build-Msi.ps1
```

Die Versionsnummer kommt aus `$AppVersion` am Anfang von `AD-Benutzer-Kopieren.ps1`.

## Automatischer Build und Releases (GitHub Actions)

Der Workflow `.github/workflows/build.yml` läuft bei jedem Push und Pull Request auf Windows. Er:
1. Prüft alle `.ps1`-Dateien auf Syntaxfehler.
2. Baut die EXE (PS2EXE) und das MSI (WiX).
3. Lädt EXE, MSI und ZIP als Build-Artefakt hoch. Du findest es unter **Actions → Lauf → Artifacts**.

**Ein Release erstellen:**

1. Erhöhe `$AppVersion` in `AD-Benutzer-Kopieren.ps1`, zum Beispiel auf `'1.2.0'`.
2. Trage die Änderungen in `CHANGELOG.md` ein.
3. Committe, dann erstelle und pushe ein passendes Tag:

```powershell
git tag v1.2.0
git push origin v1.2.0
```

Der Workflow erstellt dann ein GitHub-Release mit EXE, MSI und ZIP. Das Tag muss zu `$AppVersion` passen, sonst bricht der Build ab.

## Aufbau des Repositorys

```
AD-Benutzer-Kopieren.ps1        Hauptprogramm (Oberfläche)
Build-Exe.ps1                   erstellt die EXE mit PS2EXE
Build-Msi.ps1                   erstellt das MSI mit WiX v5
Install.ps1                     einfacher Installer/Deinstaller ohne MSI
installer/AD-Benutzer-Tool.wxs  WiX-Quelldatei für das MSI
.github/workflows/build.yml     automatischer Build und Releases
README.md / README.de.md        Dokumentation (EN / DE)
CHANGELOG.md                    Versionshistorie
```

## Fehlerbehebung

| Problem | Ursache und Lösung |
|---|---|
| `Die Benennung "mit" wurde nicht ... erkannt` oder seltsame Zeichen am Dateianfang | Der Skriptinhalt wurde in die Konsole eingefügt, oder die Kodierung der Datei wurde verändert. Führe die **Datei** mit `-File` aus. Alle Skripte sind reines ASCII. |
| *Modul 'ActiveDirectory' nicht gefunden* | RSAT installieren (siehe [Voraussetzungen](#voraussetzungen)). |
| Skript wird blockiert oder ist *nicht digital signiert* | Mit `-ExecutionPolicy Bypass` starten oder die Dateien entsperren: `Get-ChildItem *.ps1 \| Unblock-File`. Bei einer heruntergeladenen ZIP vor dem Entpacken unter *Eigenschaften* **Zulassen** ankreuzen. |
| `Zugriff verweigert` bei der Installation von PS2EXE | Meist Defender oder ein anderer Virenscanner. Prüfe *Windows-Sicherheit → Schutzverlauf*. Lege einen Ausschluss für den Build-Ordner an oder frag deine IT. |
| Die EXE wird vom Virenscanner gemeldet | Bekannter Fehlalarm bei PS2EXE. Signiere die EXE mit einem Code-Signing-Zertifikat oder lege einen Ausschluss an. |
| Eine Gruppe kann nicht hinzugefügt werden | Gruppen aus einer anderen Domäne oder Gesamtstruktur lassen sich nicht immer über den gewählten DC ändern. Das Protokoll nennt die betroffene Gruppe. |
| *Kennwort entspricht nicht den Anforderungen* | Die Kennwortrichtlinie der Domäne ist nicht erfüllt. Nutze **Generieren** oder wähle ein längeres Kennwort. |

## Sicherheitshinweise

- Das Tool arbeitet mit den Rechten des **angemeldeten Benutzers**. Es speichert keine Kennwörter und enthält auch keine.
- Kennwörter liegen nur im Arbeitsspeicher. Mit **Kopieren** landet das Kennwort in der Zwischenablage. Leere sie danach.
- Die EXE verpackt nur das Skript, der Quellcode lässt sich also auslesen. Trage niemals Geheimnisse ins Skript ein.
- Halte das Repository **privat**, wenn es interne Angaben wie OU-Namen enthält.
