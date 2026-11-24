# AD-Benutzer-Tool

**English** | [Deutsch](README.de.md)

A Windows PowerShell tool with a graphical interface (Windows Forms) that creates new Active Directory users based on an existing template user. It copies the template's group memberships (permissions) and, optionally, its organisational attributes. It builds the UPN from first and last name.

> The user interface is in German. This documentation is available in English and German.

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Using the tool](#using-the-tool)
- [How the UPN is built](#how-the-upn-is-built)
- [What is copied from the template](#what-is-copied-from-the-template)
- [Installation options](#installation-options)
- [Building it yourself](#building-it-yourself)
- [Automatic build and releases (GitHub Actions)](#automatic-build-and-releases-github-actions)
- [Repository layout](#repository-layout)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)

---

## Features

- **Domain controller selection.** All DCs of the domain are listed. The current logon server is preselected, and you can also type a DC name.
- **Template search.** Search by name, logon name, UPN, first name or last name (up to 200 results).
- **New user from first and last name:**
  - The UPN prefix (the part before `@`) is generated automatically, in one of 7 formats.
  - German umlauts and accents are converted (`ä → ae`, `ß → ss`, `é → e`).
  - The UPN prefix can be set manually.
  - The UPN suffix (the part after `@`) is loaded from AD and can be selected: domain, forest UPN suffixes and other domains in the forest.
  - The sAMAccountName is derived from the UPN prefix (max. 20 characters) and can be edited.
- **E-mail address.** By default the e-mail is the same as the UPN. You can also enter your own address or leave it empty.
- **Password generator.** Creates a 16-character random password with upper and lower case letters, digits and special characters. Easily confused characters are left out. The password can be shown and copied to the clipboard.
- **Groups.** The template's groups are shown with check boxes. All are selected by default, and you can deselect any of them.
- **Attributes (optional).** Copies department, company, office, manager, address, logon script, home folder and profile path.
- **Safety checks before creation.** The tool checks whether the logon name, UPN, e-mail or the name in the target OU already exist. It then shows a summary that you must confirm.
- **Log window.** Shows every step and error.

## Requirements

| Requirement | Details |
|---|---|
| Operating system | Windows 10/11 or Windows Server 2016+ |
| PowerShell | Windows PowerShell 5.1 (built into Windows) |
| AD module | RSAT: *Active Directory Domain Services and Lightweight Directory Services Tools* |
| Permissions | An account that can create users in the target OU and change group membership |

Install RSAT on Windows 10/11 (as administrator):

```powershell
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

On Windows Server:

```powershell
Install-WindowsFeature RSAT-AD-PowerShell
```

## Quick start

1. Open **Releases** on the right side of the GitHub page and download the latest version:
   - `AD-Benutzer-Tool-x.y.z.msi`: installer (recommended)
   - `AD-Benutzer-Kopieren.exe`: runs without installation
   - `AD-Benutzer-Tool-x.y.z.zip`: EXE, script and documentation
2. Install the MSI, or start the EXE directly.
3. Start **"AD-Benutzer anlegen"** from the Start menu.

Alternatively, run the script directly without building anything:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD-Benutzer-Kopieren.ps1
```

## Using the tool

The window has four areas.

| # | Area (German UI label) | What to do |
|---|---|---|
| 1 | **Domain Controller** | Select a DC, or type a name and press Enter. The domain, site and UPN suffixes are loaded. |
| 2 | **Vorlage-Benutzer suchen** (template search) | Enter a search term, click **Suchen**, then click the template user in the list. |
| 3 | **Neuer Benutzer** (new user) | Enter first name (*Vorname*) and last name (*Nachname*). Choose a UPN format, or tick *UPN-Präfix manuell festlegen* to type the prefix yourself. Choose the UPN suffix. Check the e-mail, set a password (*Generieren* creates one), and check the target OU (*Ziel-OU*, taken from the template). |
| 4 | **Gruppenmitgliedschaften** (group memberships) | Deselect groups the new user should not get. |

Click **Benutzer anlegen** (create user), check the summary and confirm. The log on the right shows the result.

Options in area 3:

| Option (German label) | Meaning |
|---|---|
| *Kennwort bei nächster Anmeldung ändern* | User must change the password at next logon |
| *Konto aktivieren* | Account is enabled immediately |
| *Attribute übernehmen* | Copy attributes from the template (see below) |
| *= UPN* (next to e-mail) | E-mail address follows the UPN automatically |
| *Kennwort anzeigen* | Show the password in clear text |

## How the UPN is built

Example: first name **Jörg**, last name **Müller-Weiß**

| Format | Result |
|---|---|
| `vorname.nachname` | `joerg.mueller-weiss` |
| `v.nachname` | `j.mueller-weiss` |
| `vnachname` | `jmueller-weiss` |
| `vornamenachname` | `joergmueller-weiss` |
| `nachname.vorname` | `mueller-weiss.joerg` |
| `nachnamev` | `mueller-weissj` |
| `vorname.n` | `joerg.m` |

Rules:
- Everything is converted to lower case.
- `ä ö ü ß` become `ae oe ue ss`. Other accents are removed.
- Spaces and any character other than `a-z 0-9 . - _` are removed.
- The sAMAccountName is the UPN prefix, cut to 20 characters.

## What is copied from the template

**Always:**
- Target OU: the template's OU is suggested and can be changed.
- Group memberships: the groups you selected in area 4.

**With "Attribute übernehmen":**

`Department`, `Company`, `Office`, `Title`, `Description`, `Manager`, `StreetAddress`, `City`, `PostalCode`, `State`, `Country`, `HomePage`, `ScriptPath`, `HomeDrive`, `HomeDirectory`, `ProfilePath`

In `HomeDirectory` and `ProfilePath`, the template's logon name is replaced with the new logon name.

**Not copied:**
- The primary group. AD sets it automatically, usually to *Domain Users*.
- The home folder on the file server is only entered in AD. The folder itself is **not** created.
- Exchange or Microsoft 365 mailbox, licences and phone numbers.

## Installation options

### MSI (recommended, also for GPO or Intune)

```powershell
# interactive
msiexec /i AD-Benutzer-Tool-1.1.0.msi

# silent
msiexec /i AD-Benutzer-Tool-1.1.0.msi /qn

# silent, with desktop shortcut
msiexec /i AD-Benutzer-Tool-1.1.0.msi /qn DESKTOPSHORTCUT=1

# uninstall
msiexec /x AD-Benutzer-Tool-1.1.0.msi /qn
```

- Installs to `C:\Program Files\AD-Benutzer-Tool`.
- Creates a Start menu shortcut for all users.
- Installing a newer MSI replaces the old version automatically (major upgrade).

### Install.ps1 (without MSI)

Place `Install.ps1` next to `AD-Benutzer-Kopieren.exe`:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Desktop
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Uninstall
```

The script asks for administrator rights, copies the EXE to `C:\Program Files\AD-Benutzer-Kopieren` and creates shortcuts. It also adds an entry to *Programs and Features*.

> Use **either** the MSI **or** Install.ps1, not both.

## Building it yourself

Clone the repository:

```powershell
git clone https://github.com/EinfachSeraco/ad-benutzer-tool.git
cd ad-benutzer-tool
```

**EXE.** Requires internet access the first time, to load PS2EXE into `_modules\`:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Build-Exe.ps1
powershell.exe -ExecutionPolicy Bypass -File .\Build-Exe.ps1 -IconFile .\icon.ico
```

**MSI.** Requires the EXE and the [.NET SDK](https://dotnet.microsoft.com/download). WiX v5 is installed automatically as a dotnet tool:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Build-Msi.ps1
```

The version number comes from `$AppVersion` at the top of `AD-Benutzer-Kopieren.ps1`.

## Automatic build and releases (GitHub Actions)

The workflow `.github/workflows/build.yml` runs on Windows for every push and pull request. It:
1. Checks all `.ps1` files for syntax errors.
2. Builds the EXE (PS2EXE) and the MSI (WiX).
3. Uploads EXE, MSI and ZIP as a build artifact. You find it under **Actions → run → Artifacts**.

**Creating a release:**

1. Increase `$AppVersion` in `AD-Benutzer-Kopieren.ps1`, for example to `'1.2.0'`.
2. Add an entry to `CHANGELOG.md`.
3. Commit and push to `main`.
4. Create the release in **one** of these ways:
   - **In the browser, no Git needed:** open **Actions → Build → Run workflow**, choose branch `main`, tick **release**, and click **Run workflow**. The tag `v<AppVersion>` is created automatically.
   - **With Git:**
     ```powershell
     git tag v1.2.0
     git push origin v1.2.0
     ```
     The tag must match `$AppVersion`, otherwise the build fails.

After a few minutes the release with EXE, MSI and ZIP appears under **Releases**. If a release with that version already exists, the build stops with an error. Increase `$AppVersion` first.

## Repository layout

```
AD-Benutzer-Kopieren.ps1        main program (GUI)
Build-Exe.ps1                   builds the EXE with PS2EXE
Build-Msi.ps1                   builds the MSI with WiX v5
Install.ps1                     simple installer/uninstaller without MSI
installer/AD-Benutzer-Tool.wxs  WiX source for the MSI
.github/workflows/build.yml     CI build and releases
README.md / README.de.md        documentation (EN / DE)
CHANGELOG.md                    version history
```

## Troubleshooting

| Problem | Cause and solution |
|---|---|
| `The term 'mit' is not recognized ...` or strange characters at the start of the file | The script content was pasted into the console, or the file encoding was changed. Run the **file** with `-File`. All scripts are plain ASCII. |
| *Module 'ActiveDirectory' not found* | Install RSAT (see [Requirements](#requirements)). |
| Script is blocked or *not digitally signed* | Run with `-ExecutionPolicy Bypass`, or unblock the files: `Get-ChildItem *.ps1 \| Unblock-File`. Before extracting a downloaded ZIP, open its properties and tick **Unblock**. |
| `Access denied` while installing PS2EXE | Usually Defender or another antivirus. Check *Windows Security → Protection history*. Add an exclusion for the build folder, or ask your IT. |
| EXE is reported by antivirus | Known false positive with PS2EXE. Sign the EXE with a code-signing certificate, or add an exclusion. |
| Adding a group fails | Groups from another domain or forest cannot always be changed through the selected DC. The log shows the affected group. |
| *Password does not meet the requirements* | The domain password policy was not met. Use **Generieren** or choose a longer password. |

## Security notes

- The tool works with the rights of the **signed-in user**. It does not store or contain any passwords.
- Passwords are only kept in memory. When you use **Kopieren**, the password stays in the clipboard. Clear the clipboard afterwards.
- The EXE only wraps the script, so the source code can be read. Never put secrets into the script.
- Keep this repository **private** if it contains internal details such as OU names.
