# Load Windows Forms and Drawing assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the script folder (assumes CSV files are in the same folder as the script)
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Define file paths
$orgMetadataFile    = Join-Path $ScriptRoot "data-organisation-metadata.csv"
$dataStandardsFile  = Join-Path $ScriptRoot "data-source-standards.csv"
$siteMetadataFile   = Join-Path $ScriptRoot "site-metadata.csv"
$homeUsersFile      = Join-Path $ScriptRoot "home-users.csv"

# Import CSVs (if they exist)
if (Test-Path $orgMetadataFile) {
    $orgMetadata = Import-Csv $orgMetadataFile
} else {
    [System.Windows.Forms.MessageBox]::Show("data-organisation-metadata.csv not found!")
}

if (Test-Path $dataStandardsFile) {
    $dataStandards = Import-Csv $dataStandardsFile
} else {
    [System.Windows.Forms.MessageBox]::Show("data-source-standards.csv not found!")
}

if (Test-Path $siteMetadataFile) {
    $siteMetadata = Import-Csv $siteMetadataFile
} else {
    [System.Windows.Forms.MessageBox]::Show("site-metadata.csv not found!")
}

if (Test-Path $homeUsersFile) {
    # Since home-users.csv has no headers, we treat each line as an email.
    $homeUsers = Get-Content $homeUsersFile
} else {
    [System.Windows.Forms.MessageBox]::Show("home-users.csv not found!")
}

### Fuzzy Matching Function for Home Folders ###
function Test-FuzzyMatch {
    param (
        [string]$Email,
        [string]$FolderName
    )
    # Get the local part (before the @)
    $localPart = $Email.Split("@")[0]
    # Remove trailing numbers e.g. john.smith123 -> john.smith
    $localPart = $localPart -replace "\d+$", ""
    # Split into first and last name (assumes "first.last")
    $parts = $localPart.Split(".")
    if ($parts.Count -lt 2) { return $false }
    $firstName = $parts[0].Trim().ToLower()
    $lastName  = $parts[1].Trim().ToLower()
    $firstInitial = $firstName.Substring(0,1)
    $lastInitial  = $lastName.Substring(0,1)
    # Normalize folder name
    $folder = $FolderName.Trim().ToLower()

    # Pattern definitions
    $patterns = @(
        "$firstInitial.$lastName",   # Pattern 1: firstInitial.lastName
        "$firstName.$lastName",      # Pattern 2: firstName.lastName
        "$firstInitial$lastName",    # Pattern 3: firstInitiallastName
        # Pattern 4: firstInitial + 1-4 arbitrary characters + lastName (regex)
        "^$firstInitial.{1,4}$lastName$",
        "$lastName$firstInitial",    # Pattern 5: lastNamefirstInitial
        "$firstName$lastName",       # Pattern 6: firstNamelastName
        "$lastName$firstName",       # Pattern 7: lastNamefirstName
        "$firstName$lastInitial"     # Pattern 8: firstNamelastInitial
    )

    # Check for direct string equality for non-regex patterns
    foreach ($p in $patterns[0..2] + $patterns[4..7]) {
        if ($folder -eq $p) { return $true }
    }
    # Check regex for pattern 4
    if ($folder -match $patterns[3]) { return $true }

    return $false
}

### Helper Functions for File and Folder Browsing ###
function Browse-File {
    param(
        [string]$Title = "Select a File",
        [string]$Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    )
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }
    return ""
}

function Browse-Folder {
    param(
        [string]$Description = "Select a Folder"
    )
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = $Description
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $folderDialog.SelectedPath
    }
    return ""
}

### Build the GUI ###
$form = New-Object System.Windows.Forms.Form
$form.Text = "Data Migration & Home Mapping Tool"
$form.Size = New-Object System.Drawing.Size(1000,700)
$form.StartPosition = "CenterScreen"

# Create a TabControl for the two main sections and dock it to fill the form
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = [System.Windows.Forms.DockStyle]::Fill

# Tab 1: File Inputs & Migration Section
$tabPage1 = New-Object System.Windows.Forms.TabPage
$tabPage1.Text = "Migration Setup"

# GroupBox for File Inputs (without Home Users CSV now)
$fileGroup = New-Object System.Windows.Forms.GroupBox
$fileGroup.Text = "Input Files"
# Resize group box to fit three CSV inputs
$fileGroup.Size = New-Object System.Drawing.Size(920, 120)
$fileGroup.Location = New-Object System.Drawing.Point(10,10)
$fileGroup.Anchor = [System.Windows.Forms.AnchorStyles]"Top,Left,Right"

# Global Variables (data-organisation-metadata.csv)
$labelOrg = New-Object System.Windows.Forms.Label
$labelOrg.Location = New-Object System.Drawing.Point(10,25)
$labelOrg.Size = New-Object System.Drawing.Size(180,20)
$labelOrg.Text = "Global Variables CSV:"
$txtOrg = New-Object System.Windows.Forms.TextBox
$txtOrg.Location = New-Object System.Drawing.Point(200,22)
$txtOrg.Size = New-Object System.Drawing.Size(600,20)
if (Test-Path $orgMetadataFile) {
    $txtOrg.Text = $orgMetadataFile
} else {
    $txtOrg.Text = ""
}
$btnOrg = New-Object System.Windows.Forms.Button
$btnOrg.Location = New-Object System.Drawing.Point(810,20)
$btnOrg.Size = New-Object System.Drawing.Size(80,22)
$btnOrg.Text = "Browse"
$btnOrg.Add_Click({
    $selected = Browse-File -Title "Select Global Variables CSV"
    if ($selected -ne "") {
        $txtOrg.Text = $selected
        $orgMetadata = Import-Csv $selected
    }
})

# Data Standards Mapping (data-source-standards.csv)
$labelStandards = New-Object System.Windows.Forms.Label
$labelStandards.Location = New-Object System.Drawing.Point(10,55)
$labelStandards.Size = New-Object System.Drawing.Size(180,20)
$labelStandards.Text = "Data Standards Mapping CSV:"
$txtStandards = New-Object System.Windows.Forms.TextBox
$txtStandards.Location = New-Object System.Drawing.Point(200,52)
$txtStandards.Size = New-Object System.Drawing.Size(600,20)
if (Test-Path $dataStandardsFile) {
    $txtStandards.Text = $dataStandardsFile
} else {
    $txtStandards.Text = ""
}
$btnStandards = New-Object System.Windows.Forms.Button
$btnStandards.Location = New-Object System.Drawing.Point(810,50)
$btnStandards.Size = New-Object System.Drawing.Size(80,22)
$btnStandards.Text = "Browse"
$btnStandards.Add_Click({
    $selected = Browse-File -Title "Select Data Standards Mapping CSV"
    if ($selected -ne "") {
        $txtStandards.Text = $selected
        $dataStandards = Import-Csv $selected
    }
})

# Site Metadata (site-metadata.csv)
$labelSite = New-Object System.Windows.Forms.Label
$labelSite.Location = New-Object System.Drawing.Point(10,85)
$labelSite.Size = New-Object System.Drawing.Size(180,20)
$labelSite.Text = "Site Metadata CSV:"
$txtSite = New-Object System.Windows.Forms.TextBox
$txtSite.Location = New-Object System.Drawing.Point(200,82)
$txtSite.Size = New-Object System.Drawing.Size(600,20)
if (Test-Path $siteMetadataFile) {
    $txtSite.Text = $siteMetadataFile
} else {
    $txtSite.Text = ""
}
$btnSite = New-Object System.Windows.Forms.Button
$btnSite.Location = New-Object System.Drawing.Point(810,80)
$btnSite.Size = New-Object System.Drawing.Size(80,22)
$btnSite.Text = "Browse"
$btnSite.Add_Click({
    $selected = Browse-File -Title "Select Site Metadata CSV"
    if ($selected -ne "") {
        $txtSite.Text = $selected
        $siteMetadata = Import-Csv $selected
        # Repopulate the dropdown below
        $comboSite.Items.Clear()
        foreach ($site in $siteMetadata) {
            $comboSite.Items.Add($site.'Site-Name')
        }
    }
})

# Add file input controls to the groupbox (without Home Users CSV)
$fileGroup.Controls.AddRange(@($labelOrg, $txtOrg, $btnOrg, $labelStandards, $txtStandards, $btnStandards, $labelSite, $txtSite, $btnSite))

# Dropdown for Site selection (populated from site-metadata.csv)
$labelSiteSelect = New-Object System.Windows.Forms.Label
$labelSiteSelect.Location = New-Object System.Drawing.Point(10, 130)
$labelSiteSelect.Size = New-Object System.Drawing.Size(180,20)
$labelSiteSelect.Text = "Select Site:"
$comboSite = New-Object System.Windows.Forms.ComboBox
$comboSite.Location = New-Object System.Drawing.Point(200,127)
$comboSite.Size = New-Object System.Drawing.Size(300,20)
if ($siteMetadata) {
    foreach ($site in $siteMetadata) {
        $comboSite.Items.Add($site.'Site-Name')
    }
    if ($comboSite.Items.Count -gt 0) { $comboSite.SelectedIndex = 0 }
}

# GroupBox for Migration Processing
$migrationGroup = New-Object System.Windows.Forms.GroupBox
$migrationGroup.Text = "Source & Destination Automation"
$migrationGroup.Size = New-Object System.Drawing.Size(920, 300)
$migrationGroup.Location = New-Object System.Drawing.Point(10,160)
$migrationGroup.Anchor = [System.Windows.Forms.AnchorStyles]"Top,Bottom,Left,Right"

# DataGridView to display migration results
$migrationGrid = New-Object System.Windows.Forms.DataGridView
$migrationGrid.Location = New-Object System.Drawing.Point(10,20)
$migrationGrid.Size = New-Object System.Drawing.Size(900,220)
$migrationGrid.AutoSizeColumnsMode = 'Fill'
$migrationGrid.Anchor = [System.Windows.Forms.AnchorStyles]"Top,Bottom,Left,Right"
# Define columns: Site ID, Name, Source, Destination
$migrationGrid.Columns.Add("SiteID", "Site ID") | Out-Null
$migrationGrid.Columns.Add("Name", "Name") | Out-Null
$migrationGrid.Columns.Add("Source", "Source") | Out-Null
$migrationGrid.Columns.Add("Destination", "Destination") | Out-Null

# Button to run migration processing
$btnRunMigration = New-Object System.Windows.Forms.Button
$btnRunMigration.Location = New-Object System.Drawing.Point(10,250)
$btnRunMigration.Size = New-Object System.Drawing.Size(150,30)
$btnRunMigration.Text = "Run Migration"
$btnRunMigration.Add_Click({
    # Clear previous grid rows
    $migrationGrid.Rows.Clear()
    # Get selected site metadata row
    $selectedSiteName = $comboSite.SelectedItem
    $siteRow = $siteMetadata | Where-Object { $_.'Site-Name' -eq $selectedSiteName } | Select-Object -First 1
    if (-not $siteRow) {
        [System.Windows.Forms.MessageBox]::Show("Site not found in metadata.")
        return
    }
    # Use Legacy-Root and Legacy-Share for directory listing (simulate using UNC path)
    $legacyRoot = $siteRow.'Legacy-Root'
    $legacyShare = $siteRow.'Legacy-Share'
    $uncPath = Join-Path $legacyRoot $legacyShare

    # For demo purposes, simulate share listing with Get-ChildItem if accessible.
    try {
        $shareItems = Get-ChildItem -Path $uncPath -Directory -ErrorAction Stop
    }
    catch {
        # If error, simulate with dummy data
        $shareItems = @([pscustomobject]@{Name="home"; FullName="$uncPath\home"}, [pscustomobject]@{Name="share"; FullName="$uncPath\share"})
    }

    foreach ($item in $shareItems) {
        $match = $dataStandards | Where-Object { $item.FullName -like "*$($_.'Source-Path')" }
        if ($match) {
            $std = $match | Select-Object -First 1
            $destination = $std.'Destination-Path'
            $destination = $destination -replace "<storageAccount>", $orgMetadata[0].'Storage-Account'
            if ($std.'Data Type' -like "*Student Personal*") {
                $destination = $destination -replace "<studentcontainer>", $orgMetadata[0].'Student-Personal-Container'
            }
            elseif ($std.'Data Type' -like "*Staff Personal*") {
                $destination = $destination -replace "<staffpersonalshare>", $orgMetadata[0].'Staff-Personal-Share'
            }
            $destination = $destination -replace "<sitecode>", $siteRow.'Site-Code'
            $destination = $destination -replace "<sitename>", $siteRow.'Site-Name'
            $rowIndex = $migrationGrid.Rows.Add($siteRow.'Site-Code', "$($siteRow.'Site-Name') $($std.'Data Type') Data", $item.FullName, $destination)
            $migrationGrid.Rows[$rowIndex].Cells["Destination"].Style.ForeColor = 'Green'
        }
        else {
            $rowIndex = $migrationGrid.Rows.Add($siteRow.'Site-Code', "$($siteRow.'Site-Name') Unknown Data", $item.FullName, "Non standard share found")
            $migrationGrid.Rows[$rowIndex].Cells["Destination"].Style.ForeColor = 'Red'
        }
    }
})

# Button to save migration grid as CSV
$btnSaveMigration = New-Object System.Windows.Forms.Button
$btnSaveMigration.Location = New-Object System.Drawing.Point(170,250)
$btnSaveMigration.Size = New-Object System.Drawing.Size(180,30)
$btnSaveMigration.Text = "Save Migration Metadata CSV"
$btnSaveMigration.Add_Click({
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Title = "Save Migration CSV"
    $sfd.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $csvOut = @()
        foreach ($row in $migrationGrid.Rows) {
            if ($row.IsNewRow) { continue }
            $csvOut += [PSCustomObject]@{
                "Site ID"     = $row.Cells["SiteID"].Value
                "Name"        = $row.Cells["Name"].Value
                "Source"      = $row.Cells["Source"].Value
                "Destination" = $row.Cells["Destination"].Value
            }
        }
        $csvOut | Export-Csv -Path $sfd.FileName -NoTypeInformation
        [System.Windows.Forms.MessageBox]::Show("Migration CSV saved to $($sfd.FileName)")
    }
})

$migrationGroup.Controls.AddRange(@($migrationGrid, $btnRunMigration, $btnSaveMigration))

# Add controls to tab page 1
$tabPage1.Controls.AddRange(@($fileGroup, $labelSiteSelect, $comboSite, $migrationGroup))

# Tab 2: Home Mapping Section
$tabPage2 = New-Object System.Windows.Forms.TabPage
$tabPage2.Text = "Staff Home Mapping"

# GroupBox for Home Mapping
$homeMappingGroup = New-Object System.Windows.Forms.GroupBox
$homeMappingGroup.Text = "Staff Home Folder Mapping"
$homeMappingGroup.Size = New-Object System.Drawing.Size(920, 580)
$homeMappingGroup.Location = New-Object System.Drawing.Point(10,10)
$homeMappingGroup.Anchor = [System.Windows.Forms.AnchorStyles]"Top,Bottom,Left,Right"

# Home Users CSV input controls (moved here)
$labelHomeUsers = New-Object System.Windows.Forms.Label
$labelHomeUsers.Location = New-Object System.Drawing.Point(10,20)
$labelHomeUsers.Size = New-Object System.Drawing.Size(180,20)
$labelHomeUsers.Text = "Home Users CSV:"
$txtHomeUsers = New-Object System.Windows.Forms.TextBox
$txtHomeUsers.Location = New-Object System.Drawing.Point(200,20)
$txtHomeUsers.Size = New-Object System.Drawing.Size(600,20)
if (Test-Path $homeUsersFile) {
    $txtHomeUsers.Text = $homeUsersFile
} else {
    $txtHomeUsers.Text = ""
}
$btnHomeUsers = New-Object System.Windows.Forms.Button
$btnHomeUsers.Location = New-Object System.Drawing.Point(810,20)
$btnHomeUsers.Size = New-Object System.Drawing.Size(80,22)
$btnHomeUsers.Text = "Browse"
$btnHomeUsers.Add_Click({
    $selected = Browse-File -Title "Select Home Users CSV"
    if ($selected -ne "") {
        $txtHomeUsers.Text = $selected
        $homeUsers = Get-Content $selected
    }
})

# Home Folder Path input controls
$labelHomePath = New-Object System.Windows.Forms.Label
$labelHomePath.Location = New-Object System.Drawing.Point(10,60)
$labelHomePath.Size = New-Object System.Drawing.Size(180,20)
$labelHomePath.Text = "Home Folder Path:"
$txtHomePath = New-Object System.Windows.Forms.TextBox
$txtHomePath.Location = New-Object System.Drawing.Point(200,60)
$txtHomePath.Size = New-Object System.Drawing.Size(600,20)
if ($siteMetadata -and $comboSite.SelectedItem) {
    $siteRow = $siteMetadata | Where-Object { $_.'Site-Name' -eq $comboSite.SelectedItem } | Select-Object -First 1
    if ($siteRow) {
        $txtHomePath.Text = Join-Path $siteRow.'Legacy-Root' $siteRow.'Legacy-Share'
    }
}
$btnBrowseHome = New-Object System.Windows.Forms.Button
$btnBrowseHome.Location = New-Object System.Drawing.Point(810,60)
$btnBrowseHome.Size = New-Object System.Drawing.Size(80,22)
$btnBrowseHome.Text = "Browse"
$btnBrowseHome.Add_Click({
    $selectedFolder = Browse-Folder -Description "Select Home Folder Path"
    if ($selectedFolder -ne "") { $txtHomePath.Text = $selectedFolder }
})

# Checkbox to include file count and size
$chkFileSize = New-Object System.Windows.Forms.CheckBox
$chkFileSize.Location = New-Object System.Drawing.Point(200,90)
$chkFileSize.Size = New-Object System.Drawing.Size(300,20)
$chkFileSize.Text = "Include File Count and Folder Size"
$chkFileSize.Checked = $true

# DataGridView for home mapping results
$homeMappingGrid = New-Object System.Windows.Forms.DataGridView
$homeMappingGrid.Location = New-Object System.Drawing.Point(10,130)
$homeMappingGrid.Size = New-Object System.Drawing.Size(900,350)
$homeMappingGrid.AutoSizeColumnsMode = 'Fill'
$homeMappingGrid.Anchor = [System.Windows.Forms.AnchorStyles]"Top,Bottom,Left,Right"
$homeMappingGrid.Columns.Add("Establishment", "Establishment") | Out-Null
$homeMappingGrid.Columns.Add("UserEmail", "User Email") | Out-Null
$homeMappingGrid.Columns.Add("HomeDrive", "Home Drive") | Out-Null
$homeMappingGrid.Columns.Add("FileCount", "File Count") | Out-Null
$homeMappingGrid.Columns.Add("FolderSize", "Folder Size (MB)") | Out-Null
$homeMappingGrid.Columns.Add("OneDrive", "OneDrive") | Out-Null
$homeMappingGrid.Columns.Add("Errors", "Errors") | Out-Null

# Button to run home mapping
$btnRunHomeMapping = New-Object System.Windows.Forms.Button
$btnRunHomeMapping.Location = New-Object System.Drawing.Point(10,500)
$btnRunHomeMapping.Size = New-Object System.Drawing.Size(150,30)
$btnRunHomeMapping.Text = "Run Home Mapping"
$btnRunHomeMapping.Add_Click({
    $homeMappingGrid.Rows.Clear()
    $homePath = $txtHomePath.Text
    if (-not (Test-Path $homePath)) {
        [System.Windows.Forms.MessageBox]::Show("Home folder path '$homePath' does not exist.")
        return
    }
    $folders = Get-ChildItem -Path $homePath -Directory -ErrorAction SilentlyContinue
    foreach ($email in $homeUsers) {
        $matches = @()
        foreach ($folder in $folders) {
            if (Test-FuzzyMatch -Email $email -FolderName $folder.Name) {
                $matches += $folder
            }
        }
        $establishment = $comboSite.SelectedItem
        $fileCount = ""
        $folderSize = ""
        $oneDrive = ""
        $errorText = ""
        $homeDrive = ""
        if ($matches.Count -eq 1) {
            $homeDrive = $matches[0].FullName
            if ($chkFileSize.Checked) {
                try {
                    $allFiles = Get-ChildItem -Path $homeDrive -Recurse -File -ErrorAction SilentlyContinue
                    $fileCount = $allFiles.Count
                    $sizeBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
                    if ($sizeBytes) {
                        $folderSize = "{0:N2}" -f ($sizeBytes / 1MB)
                    } else {
                        $folderSize = "0"
                    }
                }
                catch {
                    $fileCount = "N/A"
                    $folderSize = "N/A"
                }
            }
        }
        elseif ($matches.Count -gt 1) {
            $errorText = "Duplicate home folder found"
        }
        else {
            $errorText = "No home folder found"
        }
        $homeMappingGrid.Rows.Add($establishment, $email, $homeDrive, $fileCount, $folderSize, $oneDrive, $errorText) | Out-Null
    }
})

# Button to save home mapping CSV
$btnSaveHomeMapping = New-Object System.Windows.Forms.Button
$btnSaveHomeMapping.Location = New-Object System.Drawing.Point(170,500)
$btnSaveHomeMapping.Size = New-Object System.Drawing.Size(180,30)
$btnSaveHomeMapping.Text = "Save Home Folders CSV"
$btnSaveHomeMapping.Add_Click({
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Title = "Save Home Mapping CSV"
    $sfd.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $csvOut = @()
        foreach ($row in $homeMappingGrid.Rows) {
            if ($row.IsNewRow) { continue }
            $csvOut += [PSCustomObject]@{
                "Establishment"    = $row.Cells["Establishment"].Value
                "User Email"       = $row.Cells["UserEmail"].Value
                "Home Drive"       = $row.Cells["HomeDrive"].Value
                "File Count"       = $row.Cells["FileCount"].Value
                "Folder Size (MB)" = $row.Cells["FolderSize"].Value
                "OneDrive"         = $row.Cells["OneDrive"].Value
                "Errors"           = $row.Cells["Errors"].Value
            }
        }
        $csvOut | Export-Csv -Path $sfd.FileName -NoTypeInformation
        [System.Windows.Forms.MessageBox]::Show("Home Mapping CSV saved to $($sfd.FileName)")
    }
})

$homeMappingGroup.Controls.AddRange(@($labelHomeUsers, $txtHomeUsers, $btnHomeUsers, $labelHomePath, $txtHomePath, $btnBrowseHome, $chkFileSize, $homeMappingGrid, $btnRunHomeMapping, $btnSaveHomeMapping))
$tabPage2.Controls.Add($homeMappingGroup)

$tabControl.TabPages.Add($tabPage1)
$tabControl.TabPages.Add($tabPage2)

$form.Controls.Add($tabControl)

[void] $form.ShowDialog()
