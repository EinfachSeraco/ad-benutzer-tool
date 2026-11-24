# .SYNOPSIS
# AD-Benutzer anhand einer Vorlage anlegen (mit grafischer Oberflaeche).
#
# .DESCRIPTION
# - Domain Controller abfragen und auswaehlen
# - Vorlage-Benutzer suchen und auswaehlen
# - Neuen Benutzer mit Vorname/Nachname anlegen, UPN wird automatisch erzeugt
#   (Praefix optional manuell festlegbar, Suffix aus dem AD auswaehlbar)
# - Gruppenmitgliedschaften (Berechtigungen) der Vorlage werden uebernommen
# - Optional: Attribute wie Abteilung, Firma, Buero, Manager usw. uebernehmen
#
# .NOTES
# Voraussetzung: RSAT / ActiveDirectory-PowerShell-Modul
# Ausfuehren mit einem Konto, das Benutzer anlegen und Gruppen aendern darf.
# Die Datei ist reines ASCII (Umlaute ueber Zeichencodes), die Kodierung ist daher egal.

#Requires -Version 5.1

# Umlaute als Zeichencodes, damit die Datei reines ASCII bleibt
$Uae = [char]0x00E4; $Uoe = [char]0x00F6; $Uue = [char]0x00FC; $Usz = [char]0x00DF

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------------------
# Voraussetzungen pruefen
# ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Das PowerShell-Modul 'ActiveDirectory' wurde nicht gefunden.`r`nBitte RSAT (AD DS-Tools) installieren.",
        "Fehler", 'OK', 'Error') | Out-Null
    return
}
Import-Module ActiveDirectory -ErrorAction Stop

# ---------------------------------------------------------------------------
# Globale Variablen
# ---------------------------------------------------------------------------
$script:Template  = $null       # ausgewaehlter Vorlage-Benutzer
$script:GroupDNs  = @()         # DNs der Gruppen in der CheckedListBox (gleiche Reihenfolge)

# Attribute, die optional von der Vorlage uebernommen werden
$script:CopyAttributes = @(
    'Department','Company','Office','Title','Description','Manager',
    'StreetAddress','City','PostalCode','State','Country','HomePage',
    'ScriptPath','HomeDrive','HomeDirectory','ProfilePath'
)

# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------
function Convert-ToAscii {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }

    # Deutsche Umlaute ersetzen
    $t = $Text.Trim()
    $t = $t -creplace [char]0x00E4, 'ae'   # ae
    $t = $t -creplace [char]0x00F6, 'oe'   # oe
    $t = $t -creplace [char]0x00FC, 'ue'   # ue
    $t = $t -creplace [char]0x00C4, 'Ae'   # Ae
    $t = $t -creplace [char]0x00D6, 'Oe'   # Oe
    $t = $t -creplace [char]0x00DC, 'Ue'   # Ue
    $t = $t -creplace [char]0x00DF, 'ss'   # sz

    # Restliche Akzente entfernen (z.B. e mit Akzent -> e, c mit Cedille -> c)
    $norm = $t.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $norm.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($c)
        }
    }
    $t = $sb.ToString()

    # Nur erlaubte Zeichen behalten, Leerzeichen entfernen
    $t = $t -replace '[^A-Za-z0-9\.\-_]', ''
    return $t.ToLower()
}

function Get-UpnPrefix {
    param([string]$First, [string]$Last, [string]$Format)
    $v  = Convert-ToAscii $First
    $n  = Convert-ToAscii $Last
    $vi = if ($v) { $v.Substring(0,1) } else { '' }
    $ni = if ($n) { $n.Substring(0,1) } else { '' }

    switch ($Format) {
        'vorname.nachname' { $p = "$v.$n" }
        'v.nachname'       { $p = "$vi.$n" }
        'vnachname'        { $p = "$vi$n" }
        'vornamenachname'  { $p = "$v$n" }
        'nachname.vorname' { $p = "$n.$v" }
        'nachnamev'        { $p = "$n$vi" }
        'vorname.n'        { $p = "$v.$ni" }
        default            { $p = "$v.$n" }
    }
    $p = $p -replace '\.{2,}', '.'
    return $p.Trim('.')
}

function Get-SamFromPrefix {
    param([string]$Prefix)
    $s = $Prefix
    if ($s.Length -gt 20) { $s = $s.Substring(0,20) }   # sAMAccountName max. 20 Zeichen
    return $s.TrimEnd('.')
}

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','OK','WARN','FEHLER')][string]$Level = 'INFO')
    $line = "[{0}] {1,-6} {2}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    $txtLog.AppendText($line)
}

function Get-SelectedDC {
    return $cmbDC.Text.Trim()
}

function Escape-Filter {
    param([string]$Value)
    return $Value -replace "'", "''"
}

# ---------------------------------------------------------------------------
# Formular aufbauen
# ---------------------------------------------------------------------------
$fontBold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$form = New-Object System.Windows.Forms.Form
$form.Text            = 'AD-Benutzer anhand Vorlage anlegen'
$form.ClientSize      = New-Object System.Drawing.Size(990, 755)
$form.StartPosition   = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox     = $false
$form.Font            = New-Object System.Drawing.Font('Segoe UI', 9)

function New-Label($text, $x, $y, $w = 130, $h = 20) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    return $l
}
function New-TextBox($x, $y, $w) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, 23)
    return $t
}
function New-Button($text, $x, $y, $w = 100, $h = 26) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    return $b
}

# --- 1. Domain Controller ----------------------------------------------------
$grpDC = New-Object System.Windows.Forms.GroupBox
$grpDC.Text = '1. Domain Controller'
$grpDC.Location = New-Object System.Drawing.Point(10, 10)
$grpDC.Size = New-Object System.Drawing.Size(470, 90)

$cmbDC = New-Object System.Windows.Forms.ComboBox
$cmbDC.Location = New-Object System.Drawing.Point(130, 23)
$cmbDC.Size = New-Object System.Drawing.Size(230, 23)
$cmbDC.DropDownStyle = 'DropDown'    # Auswahl oder manuelle Eingabe

$btnDCLoad = New-Button 'Aktualisieren' 370 22 90
$lblDomain = New-Label "Dom${Uae}ne: -" 10 57 450

$grpDC.Controls.AddRange(@((New-Label 'Domain Controller:' 10 26 120), $cmbDC, $btnDCLoad, $lblDomain))

# --- 2. Vorlage-Benutzer ---------------------------------------------------
$grpSearch = New-Object System.Windows.Forms.GroupBox
$grpSearch.Text = '2. Vorlage-Benutzer suchen'
$grpSearch.Location = New-Object System.Drawing.Point(10, 110)
$grpSearch.Size = New-Object System.Drawing.Size(470, 300)

$txtSearch = New-TextBox 10 25 340
$btnSearch = New-Button 'Suchen' 360 23 100

$lvUsers = New-Object System.Windows.Forms.ListView
$lvUsers.Location = New-Object System.Drawing.Point(10, 57)
$lvUsers.Size = New-Object System.Drawing.Size(450, 185)
$lvUsers.View = 'Details'
$lvUsers.FullRowSelect = $true
$lvUsers.MultiSelect = $false
$lvUsers.HideSelection = $false
[void]$lvUsers.Columns.Add('Name', 135)
[void]$lvUsers.Columns.Add('Anmeldename', 95)
[void]$lvUsers.Columns.Add('UPN', 165)
[void]$lvUsers.Columns.Add('Aktiv', 45)

$lblTpl = New-Label 'Vorlage: -' 10 248 450 45
$grpSearch.Controls.AddRange(@($txtSearch, $btnSearch, $lvUsers, $lblTpl))

# --- 4. Gruppen ------------------------------------------------------------
$grpGroups = New-Object System.Windows.Forms.GroupBox
$grpGroups.Text = "4. Gruppenmitgliedschaften der Vorlage (werden ${Uue}bernommen)"
$grpGroups.Location = New-Object System.Drawing.Point(10, 420)
$grpGroups.Size = New-Object System.Drawing.Size(470, 325)

$clbGroups = New-Object System.Windows.Forms.CheckedListBox
$clbGroups.Location = New-Object System.Drawing.Point(10, 25)
$clbGroups.Size = New-Object System.Drawing.Size(450, 250)
$clbGroups.CheckOnClick = $true

$btnAll  = New-Button 'Alle' 10 287 100
$btnNone = New-Button 'Keine' 120 287 100
$lblGrpCount = New-Label '' 235 291 225
$grpGroups.Controls.AddRange(@($clbGroups, $btnAll, $btnNone, $lblGrpCount))

# --- 3. Neuer Benutzer -----------------------------------------------------
$grpNew = New-Object System.Windows.Forms.GroupBox
$grpNew.Text = '3. Neuer Benutzer'
$grpNew.Location = New-Object System.Drawing.Point(495, 10)
$grpNew.Size = New-Object System.Drawing.Size(485, 490)

$y0 = 25; $dy = 32
function RowY($i) { return $y0 + $i * $dy }

$txtFirst = New-TextBox 145 (RowY 0) 325
$txtLast  = New-TextBox 145 (RowY 1) 325

$cmbFormat = New-Object System.Windows.Forms.ComboBox
$cmbFormat.Location = New-Object System.Drawing.Point(145, (RowY 2))
$cmbFormat.Size = New-Object System.Drawing.Size(325, 23)
$cmbFormat.DropDownStyle = 'DropDownList'
[void]$cmbFormat.Items.AddRange(@('vorname.nachname','v.nachname','vnachname','vornamenachname','nachname.vorname','nachnamev','vorname.n'))
$cmbFormat.SelectedIndex = 0

$chkManualUpn = New-Object System.Windows.Forms.CheckBox
$chkManualUpn.Text = "UPN-Pr${Uae}fix (vor dem @) manuell festlegen"
$chkManualUpn.Location = New-Object System.Drawing.Point(145, (RowY 3))
$chkManualUpn.Size = New-Object System.Drawing.Size(325, 22)

$txtUpnPrefix = New-TextBox 145 (RowY 4) 150
$txtUpnPrefix.ReadOnly = $true
$lblAt = New-Label '@' 298 ((RowY 4) + 3) 18
$cmbSuffix = New-Object System.Windows.Forms.ComboBox
$cmbSuffix.Location = New-Object System.Drawing.Point(318, (RowY 4))
$cmbSuffix.Size = New-Object System.Drawing.Size(152, 23)
$cmbSuffix.DropDownStyle = 'DropDownList'

$txtSam     = New-TextBox 145 (RowY 5) 325
$txtSam.MaxLength = 20
$txtDisplay = New-TextBox 145 (RowY 6) 325
$txtOU      = New-TextBox 145 (RowY 7) 325

$txtPw1 = New-TextBox 145 (RowY 8) 325;  $txtPw1.UseSystemPasswordChar = $true
$txtPw2 = New-TextBox 145 (RowY 9) 325;  $txtPw2.UseSystemPasswordChar = $true

$chkChangePw = New-Object System.Windows.Forms.CheckBox
$chkChangePw.Text = "Kennwort bei n${Uae}chster Anmeldung ${Uae}ndern"
$chkChangePw.Location = New-Object System.Drawing.Point(145, (RowY 10))
$chkChangePw.Size = New-Object System.Drawing.Size(325, 22)
$chkChangePw.Checked = $true

$chkEnabled = New-Object System.Windows.Forms.CheckBox
$chkEnabled.Text = 'Konto aktivieren'
$chkEnabled.Location = New-Object System.Drawing.Point(145, ((RowY 10) + 24))
$chkEnabled.Size = New-Object System.Drawing.Size(325, 22)
$chkEnabled.Checked = $true

$chkCopyAttr = New-Object System.Windows.Forms.CheckBox
$chkCopyAttr.Text = "Attribute ${Uue}bernehmen (Abteilung, Firma, B${Uue}ro, Manager ...)"
$chkCopyAttr.Location = New-Object System.Drawing.Point(145, ((RowY 10) + 48))
$chkCopyAttr.Size = New-Object System.Drawing.Size(335, 22)
$chkCopyAttr.Checked = $true

$lblPreview = New-Label 'UPN: -' 10 ((RowY 10) + 80) 465 22
$lblPreview.Font = $fontBold

$grpNew.Controls.AddRange(@(
    (New-Label 'Vorname:'            10 ((RowY 0)+3)), $txtFirst,
    (New-Label 'Nachname:'           10 ((RowY 1)+3)), $txtLast,
    (New-Label 'UPN-Format:'         10 ((RowY 2)+3)), $cmbFormat,
    $chkManualUpn,
    (New-Label 'UPN:'                10 ((RowY 4)+3)), $txtUpnPrefix, $lblAt, $cmbSuffix,
    (New-Label 'Anmeldename (SAM):'  10 ((RowY 5)+3)), $txtSam,
    (New-Label 'Anzeigename:'        10 ((RowY 6)+3)), $txtDisplay,
    (New-Label 'Ziel-OU:'            10 ((RowY 7)+3)), $txtOU,
    (New-Label 'Kennwort:'           10 ((RowY 8)+3)), $txtPw1,
    (New-Label "Kennwort best${Uae}tigen:" 10 ((RowY 9)+3)), $txtPw2,
    $chkChangePw, $chkEnabled, $chkCopyAttr, $lblPreview
))

# --- Protokoll + Buttons ---------------------------------------------------
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(495, 510)
$txtLog.Size = New-Object System.Drawing.Size(485, 190)
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 8.5)

$btnCreate = New-Button 'Benutzer anlegen' 495 710 240 35
$btnCreate.Font = $fontBold
$btnClose  = New-Button "Schlie${Usz}en" 740 710 240 35

$form.Controls.AddRange(@($grpDC, $grpSearch, $grpGroups, $grpNew, $txtLog, $btnCreate, $btnClose))
$form.AcceptButton = $btnSearch

# ---------------------------------------------------------------------------
# Logik
# ---------------------------------------------------------------------------
function Update-Preview {
    $suffix = [string]$cmbSuffix.SelectedItem
    if ($txtUpnPrefix.Text -and $suffix) {
        $lblPreview.Text = "UPN: $($txtUpnPrefix.Text)@$suffix"
    } else {
        $lblPreview.Text = 'UPN: -'
    }
}

function Update-Generated {
    if (-not $chkManualUpn.Checked) {
        $txtUpnPrefix.Text = Get-UpnPrefix -First $txtFirst.Text -Last $txtLast.Text -Format ([string]$cmbFormat.SelectedItem)
    }
    $txtDisplay.Text = ("{0} {1}" -f $txtFirst.Text.Trim(), $txtLast.Text.Trim()).Trim()
    Update-Preview
}

function Reset-Template {
    $script:Template = $null
    $script:GroupDNs = @()
    $clbGroups.Items.Clear()
    $lblGrpCount.Text = ''
    $lblTpl.Text = 'Vorlage: -'
    $txtOU.Text = ''
}

function Load-DCs {
    $form.Cursor = 'WaitCursor'
    try {
        $cmbDC.Items.Clear()
        $dcs = Get-ADDomainController -Filter * -ErrorAction Stop | Sort-Object HostName
        foreach ($d in $dcs) { [void]$cmbDC.Items.Add($d.HostName) }
        Write-Log "$(@($dcs).Count) Domain Controller gefunden." 'OK'

        # Bevorzugt den aktuellen Anmeldeserver vorauswaehlen
        $logon = ($env:LOGONSERVER -replace '^\\\\', '')
        $idx = 0
        for ($i = 0; $i -lt $cmbDC.Items.Count; $i++) {
            if ($logon -and ([string]$cmbDC.Items[$i]).StartsWith("$logon.", 'OrdinalIgnoreCase')) { $idx = $i; break }
        }
        if ($cmbDC.Items.Count -gt 0) { $cmbDC.SelectedIndex = $idx }
    } catch {
        Write-Log "Domain Controller konnten nicht abgefragt werden: $($_.Exception.Message)" 'FEHLER'
    } finally {
        $form.Cursor = 'Default'
    }
}

function Connect-DC {
    $dc = Get-SelectedDC
    if (-not $dc) { return }
    $form.Cursor = 'WaitCursor'
    try {
        $domain = Get-ADDomain -Server $dc -ErrorAction Stop
        $forest = Get-ADForest -Server $dc -ErrorAction Stop
        $dcObj  = Get-ADDomainController -Identity $dc -Server $dc -ErrorAction SilentlyContinue

        $siteText = if ($dcObj) { " | Standort: $($dcObj.Site)" } else { '' }
        $lblDomain.Text = "Dom${Uae}ne: $($domain.DNSRoot) ($($domain.NetBIOSName))$siteText"

        # UPN-Suffixe: Domaene zuerst, dann Gesamtstruktur-Suffixe, dann uebrige Domaenen
        $suffixes = New-Object System.Collections.Generic.List[string]
        foreach ($s in (@($domain.DNSRoot) + @($forest.UPNSuffixes) + @($forest.Domains))) {
            if ($s -and -not ($suffixes -contains $s)) { $suffixes.Add($s) }
        }
        $cmbSuffix.Items.Clear()
        foreach ($s in $suffixes) { [void]$cmbSuffix.Items.Add($s) }
        if ($cmbSuffix.Items.Count -gt 0) { $cmbSuffix.SelectedIndex = 0 }

        $lvUsers.Items.Clear()
        Reset-Template
        Write-Log "Verbunden mit $dc - $($suffixes.Count) UPN-Suffix(e) geladen." 'OK'
    } catch {
        Write-Log "Verbindung zu '$dc' fehlgeschlagen: $($_.Exception.Message)" 'FEHLER'
    } finally {
        $form.Cursor = 'Default'
        Update-Preview
    }
}

function Search-Users {
    $dc = Get-SelectedDC
    $term = $txtSearch.Text.Trim()
    if (-not $dc)   { Write-Log "Bitte zuerst einen Domain Controller w${Uae}hlen." 'WARN'; return }
    if (-not $term) { Write-Log 'Bitte einen Suchbegriff eingeben.' 'WARN'; return }

    $form.Cursor = 'WaitCursor'
    try {
        $t = Escape-Filter $term
        $filter = "Name -like '*$t*' -or SamAccountName -like '*$t*' -or UserPrincipalName -like '*$t*' -or Surname -like '*$t*' -or GivenName -like '*$t*'"
        $users = Get-ADUser -Server $dc -Filter $filter -ResultSetSize 200 -ErrorAction Stop | Sort-Object Name

        $lvUsers.BeginUpdate()
        $lvUsers.Items.Clear()
        foreach ($u in $users) {
            $item = New-Object System.Windows.Forms.ListViewItem([string]$u.Name)
            [void]$item.SubItems.Add([string]$u.SamAccountName)
            [void]$item.SubItems.Add([string]$u.UserPrincipalName)
            [void]$item.SubItems.Add($(if ($u.Enabled) { 'Ja' } else { 'Nein' }))
            $item.Tag = $u.DistinguishedName
            [void]$lvUsers.Items.Add($item)
        }
        $lvUsers.EndUpdate()
        Write-Log "$(@($users).Count) Benutzer f${Uue}r '$term' gefunden." 'INFO'
    } catch {
        Write-Log "Suche fehlgeschlagen: $($_.Exception.Message)" 'FEHLER'
    } finally {
        $form.Cursor = 'Default'
    }
}

function Select-Template {
    if ($lvUsers.SelectedItems.Count -eq 0) { return }
    $dc = Get-SelectedDC
    $dn = [string]$lvUsers.SelectedItems[0].Tag

    $form.Cursor = 'WaitCursor'
    try {
        $props = @('MemberOf','DisplayName','Enabled') + $script:CopyAttributes
        $u = Get-ADUser -Identity $dn -Server $dc -Properties $props -ErrorAction Stop
        $script:Template = $u

        $ou = $u.DistinguishedName -replace '^CN=.+?(?<!\\),', ''
        $txtOU.Text = $ou
        $lblTpl.Text = "Vorlage: $($u.Name) ($($u.SamAccountName))`r`nOU: $ou"

        # Gruppen laden (Primaergruppe, i.d.R. 'Domaenen-Benutzer', wird automatisch gesetzt)
        $groups = foreach ($g in @($u.MemberOf)) {
            try {
                $grp = Get-ADGroup -Identity $g -Server $dc -ErrorAction Stop
                [pscustomobject]@{ Name = $grp.Name; DN = $grp.DistinguishedName }
            } catch {
                # z.B. Gruppe aus anderer Domaene -> Namen aus DN ableiten
                [pscustomobject]@{ Name = (($g -split '(?<!\\),')[0] -replace '^CN=', ''); DN = $g }
            }
        }
        $groups = @($groups | Sort-Object Name)

        $clbGroups.BeginUpdate()
        $clbGroups.Items.Clear()
        $script:GroupDNs = @()
        foreach ($g in $groups) {
            [void]$clbGroups.Items.Add($g.Name, $true)
            $script:GroupDNs += $g.DN
        }
        $clbGroups.EndUpdate()
        $lblGrpCount.Text = "$($groups.Count) Gruppe(n)"
        Write-Log "Vorlage '$($u.SamAccountName)' geladen ($($groups.Count) Gruppen)." 'OK'
    } catch {
        Write-Log "Vorlage konnte nicht geladen werden: $($_.Exception.Message)" 'FEHLER'
    } finally {
        $form.Cursor = 'Default'
    }
}

function New-UserFromTemplate {
    $dc = Get-SelectedDC

    # --- Eingaben pruefen ---
    $errors = @()
    if (-not $dc)                                 { $errors += "Kein Domain Controller ausgew${Uae}hlt." }
    if (-not $script:Template)                    { $errors += "Kein Vorlage-Benutzer ausgew${Uae}hlt." }
    if (-not $txtFirst.Text.Trim())               { $errors += 'Vorname fehlt.' }
    if (-not $txtLast.Text.Trim())                { $errors += 'Nachname fehlt.' }
    if (-not $cmbSuffix.SelectedItem)             { $errors += "Kein UPN-Suffix ausgew${Uae}hlt." }
    $prefix = $txtUpnPrefix.Text.Trim()
    if ($prefix -notmatch '^[A-Za-z0-9_\-]+(\.[A-Za-z0-9_\-]+)*$') { $errors += "UPN-Pr${Uae}fix ist ung${Uue}ltig (erlaubt: a-z, 0-9, . - _)." }
    $sam = $txtSam.Text.Trim()
    if (-not $sam -or $sam -match '["/\\\[\]:;|=,+*?<>@\s]') { $errors += "Anmeldename (SAM) ist leer oder enth${Uae}lt ung${Uue}ltige Zeichen." }
    if (-not $txtDisplay.Text.Trim())             { $errors += 'Anzeigename fehlt.' }
    if (-not $txtOU.Text.Trim())                  { $errors += 'Ziel-OU fehlt.' }
    if (-not $txtPw1.Text)                        { $errors += 'Kennwort fehlt.' }
    if ($txtPw1.Text -ne $txtPw2.Text)            { $errors += "Kennw${Uoe}rter stimmen nicht ${Uue}berein." }

    if ($errors.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(($errors -join "`r`n"), "Eingaben pr${Uue}fen", 'OK', 'Warning') | Out-Null
        return
    }

    $upn     = "$prefix@$($cmbSuffix.SelectedItem)"
    $display = $txtDisplay.Text.Trim()
    $ou      = $txtOU.Text.Trim()
    $tpl     = $script:Template

    # --- Eindeutigkeit pruefen ---
    try {
        if (Get-ADUser -Server $dc -Filter "SamAccountName -eq '$(Escape-Filter $sam)'" -ErrorAction Stop) {
            [System.Windows.Forms.MessageBox]::Show("Der Anmeldename '$sam' existiert bereits.", 'Konflikt', 'OK', 'Warning') | Out-Null; return
        }
        if (Get-ADUser -Server $dc -Filter "UserPrincipalName -eq '$(Escape-Filter $upn)'" -ErrorAction Stop) {
            [System.Windows.Forms.MessageBox]::Show("Der UPN '$upn' existiert bereits.", 'Konflikt', 'OK', 'Warning') | Out-Null; return
        }
        if (Get-ADObject -Server $dc -SearchBase $ou -SearchScope OneLevel -Filter "Name -eq '$(Escape-Filter $display)'" -ErrorAction Stop) {
            [System.Windows.Forms.MessageBox]::Show("In der OU existiert bereits ein Objekt mit dem Namen '$display'.`r`nBitte Anzeigename anpassen.", 'Konflikt', 'OK', 'Warning') | Out-Null; return
        }
    } catch {
        Write-Log "Pr${Uue}fung fehlgeschlagen: $($_.Exception.Message)" 'FEHLER'; return
    }

    # --- Gewaehlte Gruppen ---
    $selGroups = @()
    foreach ($i in $clbGroups.CheckedIndices) { $selGroups += $script:GroupDNs[$i] }

    # --- Bestaetigung ---
    $attrText = if ($chkCopyAttr.Checked) { "werden ${Uue}bernommen" } else { 'nein' }
    $msg = @"
Folgender Benutzer wird angelegt:

Name:          $display
Vorname:       $($txtFirst.Text.Trim())
Nachname:      $($txtLast.Text.Trim())
UPN:           $upn
Anmeldename:   $sam
OU:            $ou
Vorlage:       $($tpl.SamAccountName)
Gruppen:       $($selGroups.Count)
Attribute:     $attrText
Domain Ctrl.:  $dc

Fortfahren?
"@
    if ([System.Windows.Forms.MessageBox]::Show($msg, "Best${Uae}tigen", 'YesNo', 'Question') -ne 'Yes') { return }

    $form.Cursor = 'WaitCursor'
    try {
        $params = @{
            Server                = $dc
            Name                  = $display
            DisplayName           = $display
            GivenName             = $txtFirst.Text.Trim()
            Surname               = $txtLast.Text.Trim()
            SamAccountName        = $sam
            UserPrincipalName     = $upn
            Path                  = $ou
            AccountPassword       = (ConvertTo-SecureString $txtPw1.Text -AsPlainText -Force)
            Enabled               = $chkEnabled.Checked
            ChangePasswordAtLogon = $chkChangePw.Checked
            PassThru              = $true
            ErrorAction           = 'Stop'
        }

        if ($chkCopyAttr.Checked) {
            $tplSam = [regex]::Escape($tpl.SamAccountName)
            foreach ($a in $script:CopyAttributes) {
                $val = $tpl.$a
                if ($null -eq $val -or [string]::IsNullOrWhiteSpace([string]$val)) { continue }
                if ($a -in 'HomeDirectory','ProfilePath') {
                    # Benutzername im Pfad der Vorlage durch neuen ersetzen
                    $val = [regex]::Replace([string]$val, $tplSam, $sam, 'IgnoreCase')
                }
                $params[$a] = $val
            }
        }

        $newUser = New-ADUser @params
        Write-Log "Benutzer '$sam' ($upn) angelegt." 'OK'
        if ($params.ContainsKey('HomeDirectory')) {
            Write-Log "Hinweis: Home-Verzeichnis '$($params.HomeDirectory)' wurde nur im AD eingetragen, nicht angelegt." 'WARN'
        }

        # --- Gruppen hinzufuegen ---
        $ok = 0; $fail = 0
        foreach ($g in $selGroups) {
            try {
                Add-ADGroupMember -Identity $g -Members $newUser -Server $dc -ErrorAction Stop
                $ok++
            } catch {
                $fail++
                Write-Log "Gruppe '$g': $($_.Exception.Message)" 'FEHLER'
            }
        }
        Write-Log "Gruppen: $ok erfolgreich, $fail fehlgeschlagen." $(if ($fail) { 'WARN' } else { 'OK' })

        [System.Windows.Forms.MessageBox]::Show(
            "Benutzer '$display' wurde angelegt.`r`nUPN: $upn`r`nGruppen: $ok von $($selGroups.Count) zugewiesen.",
            'Fertig', 'OK', 'Information') | Out-Null

        # Felder fuer naechsten Benutzer leeren (Vorlage bleibt erhalten)
        $txtFirst.Text = ''; $txtLast.Text = ''; $txtPw1.Text = ''; $txtPw2.Text = ''
        $chkManualUpn.Checked = $false
        $txtFirst.Focus()
    } catch {
        Write-Log "Anlegen fehlgeschlagen: $($_.Exception.Message)" 'FEHLER'
        [System.Windows.Forms.MessageBox]::Show("Fehler beim Anlegen:`r`n$($_.Exception.Message)", 'Fehler', 'OK', 'Error') | Out-Null
    } finally {
        $form.Cursor = 'Default'
    }
}

# ---------------------------------------------------------------------------
# Ereignisse
# ---------------------------------------------------------------------------
$btnDCLoad.Add_Click({ Load-DCs })
$cmbDC.Add_SelectedIndexChanged({ Connect-DC })
$cmbDC.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { Connect-DC; $_.SuppressKeyPress = $true } })

$btnSearch.Add_Click({ Search-Users })
$lvUsers.Add_SelectedIndexChanged({ Select-Template })

$txtFirst.Add_TextChanged({ Update-Generated })
$txtLast.Add_TextChanged({ Update-Generated })
$cmbFormat.Add_SelectedIndexChanged({ Update-Generated })

$chkManualUpn.Add_CheckedChanged({
    $txtUpnPrefix.ReadOnly = -not $chkManualUpn.Checked
    if ($chkManualUpn.Checked) { $txtUpnPrefix.Focus() } else { Update-Generated }
})
$txtUpnPrefix.Add_TextChanged({
    $txtSam.Text = Get-SamFromPrefix $txtUpnPrefix.Text.Trim()
    Update-Preview
})
$cmbSuffix.Add_SelectedIndexChanged({ Update-Preview })

$btnAll.Add_Click({  for ($i = 0; $i -lt $clbGroups.Items.Count; $i++) { $clbGroups.SetItemChecked($i, $true) } })
$btnNone.Add_Click({ for ($i = 0; $i -lt $clbGroups.Items.Count; $i++) { $clbGroups.SetItemChecked($i, $false) } })

$btnCreate.Add_Click({ New-UserFromTemplate })
$btnClose.Add_Click({ $form.Close() })

$form.Add_Shown({
    Write-Log 'Lade Domain Controller ...'
    Load-DCs
    $txtSearch.Focus()
})

[void]$form.ShowDialog()
$form.Dispose()
