# ------------------------------
# Global Variables (Edit as needed)
# ------------------------------
$GlobalStorageAccount       = "teststorageaccount"
$GlobalSASToken             = "testsastoken"
$GlobalStudentContainer     = "studentcontainer"
$GlobalStaffPersonalShare   = "staffpersonalshare"

# CSV file paths (Edit as needed)
$DataStandardsCSV = "Data-Standards.csv"
$SiteMetadataCSV  = "Site-Metadata.csv"

# ------------------------------
# Load required .NET assemblies
# ------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------
# Helper Functions
# ------------------------------
function Load-CSVFile($filePath) {
    try {
        return Import-Csv -Path $filePath
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to load CSV: $filePath", "Error", `
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $null
    }
}

function ReplaceTokens($template, $siteMetadata) {
    if ($null -eq $template) { return "" }
    $result = $template
    $result = $result.Replace("<storageAccount>", $GlobalStorageAccount)
    $result = $result.Replace("<studentcontainer>", $GlobalStudentContainer)
    $result = $result.Replace("<staffpersonalshare>", $GlobalStaffPersonalShare)
    $result = $result.Replace("<SASToken>", $GlobalSASToken)
    $result = $result.Replace("<sitecode>", $siteMetadata.'Site-Code')
    $result = $result.Replace("<sitename>", $siteMetadata.'Site-Name')
    return $result
}

# ------------------------------
# Build the GUI
# ------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Data Migration Tool"
$form.Size = New-Object System.Drawing.Size(800,600)
$form.StartPosition = "CenterScreen"

# Top panel for buttons
$pnlTop = New-Object System.Windows.Forms.Panel
$pnlTop.Dock = 'Top'
$pnlTop.Height = 80
$form.Controls.Add($pnlTop)

$lblSiteSelect = New-Object System.Windows.Forms.Label
$lblSiteSelect.Location = New-Object System.Drawing.Point(10,10)
$lblSiteSelect.Size = New-Object System.Drawing.Size(200,20)
$lblSiteSelect.Text = "Select Site:"
$pnlTop.Controls.Add($lblSiteSelect)

$cmbSite = New-Object System.Windows.Forms.ComboBox
$cmbSite.Location = New-Object System.Drawing.Point(10,35)
$cmbSite.Size = New-Object System.Drawing.Size(300,20)
$pnlTop.Controls.Add($cmbSite)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Location = New-Object System.Drawing.Point(320,30)
$btnRun.Size = New-Object System.Drawing.Size(75,25)
$btnRun.Text = "Run"
$pnlTop.Controls.Add($btnRun)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Location = New-Object System.Drawing.Point(410,30)
$btnSave.Size = New-Object System.Drawing.Size(100,25)
$btnSave.Text = "Save CSV"
$pnlTop.Controls.Add($btnSave)

# DataGridView in the remaining area
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(10,90)
$grid.Size = New-Object System.Drawing.Size(760,460)
$grid.Anchor = 'Top,Bottom,Left,Right'
$grid.AutoSizeColumnsMode = "Fill"
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$form.Controls.Add($grid)

# ------------------------------
# Create a DataTable to serve as grid's data source
# ------------------------------
$dt = New-Object System.Data.DataTable
$dt.Columns.Add("Site ID")   | Out-Null
$dt.Columns.Add("Name")      | Out-Null
$dt.Columns.Add("Source")    | Out-Null
$dt.Columns.Add("Destination") | Out-Null
$dt.Columns.Add("Errors")    | Out-Null

$grid.DataSource = $dt.DefaultView

# ------------------------------
# Row PrePaint Event: Highlight rows with errors (non-empty "Errors" cell) in red
# ------------------------------
$grid.add_RowPrePaint({
    param($sender, $e)
    $row = $sender.Rows[$e.RowIndex]
    if ($row.Cells["Errors"].Value -and $row.Cells["Errors"].Value.ToString().Trim() -ne "") {
         $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Red
    }
})

# ------------------------------
# Right-Click Context Menu: Copy as CSV (selected rows only, without headers)
# ------------------------------
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuItemCopyCSV = New-Object System.Windows.Forms.ToolStripMenuItem("Copy as CSV")
$contextMenu.Items.Add($menuItemCopyCSV) | Out-Null
$grid.ContextMenuStrip = $contextMenu

$menuItemCopyCSV.Add_Click({
    $csvText = ""
    # Process only selected rows (if none selected, nothing is copied)
    foreach ($row in $grid.SelectedRows) {
        $cells = @()
        foreach ($cell in $row.Cells) {
            $val = $cell.Value
            if ($val -eq $null) { $val = "" }
            $cells += $val.ToString()
        }
        $csvText += ($cells -join ",") + "`r`n"
    }
    [System.Windows.Forms.Clipboard]::SetText($csvText, 'Text')
})

# ------------------------------
# Preload Site Metadata CSV and Populate the Dropdown
# ------------------------------
if (Test-Path $SiteMetadataCSV) {
    $sites = Load-CSVFile $SiteMetadataCSV
    if ($sites) {
        foreach ($s in $sites) {
            $cmbSite.Items.Add($s.'Site-Name')
        }
        if ($cmbSite.Items.Count -gt 0) { $cmbSite.SelectedIndex = 0 }
    }
}
else {
    [System.Windows.Forms.MessageBox]::Show("Site Metadata CSV not found at: $SiteMetadataCSV", "Error", `
         [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

# ------------------------------
# Run Button Event: Process the Data Migration
# ------------------------------
$btnRun.Add_Click({
    # Clear previous results
    $dt.Clear()

    $dataStandards = Load-CSVFile $DataStandardsCSV
    $sites = Load-CSVFile $SiteMetadataCSV

    if (-not $dataStandards -or -not $sites) {
        [System.Windows.Forms.MessageBox]::Show("One or more CSV files could not be loaded.", "Error", `
             [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Get the selected site record from Site Metadata based on the dropdown selection
    $selectedSiteName = $cmbSite.SelectedItem
    $selectedSite = $sites | Where-Object { $_.'Site-Name' -eq $selectedSiteName } | Select-Object -First 1
    if (-not $selectedSite) {
        [System.Windows.Forms.MessageBox]::Show("Selected site not found in Site Metadata.", "Error", `
             [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Get legacy meta data and check for missing values
    $legacyRoot = $selectedSite.'Legacy-Root'
    $legacyShare = $selectedSite.'Legacy-Share'
    if ([string]::IsNullOrEmpty($legacyRoot)) {
        [System.Windows.Forms.MessageBox]::Show("Missing Legacy-Root for site $selectedSiteName", "Meta Data Error", `
             [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    if ([string]::IsNullOrEmpty($legacyShare)) {
        [System.Windows.Forms.MessageBox]::Show("Missing Legacy-Share for site $selectedSiteName", "Meta Data Error", `
             [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Compute the base legacy path using the selected site's Legacy-Root and Legacy-Share
    $legacyRootTrim = $legacyRoot.TrimEnd("\")
    $legacyShareTrim = $legacyShare.TrimStart("\")
    $basePath = Join-Path $legacyRootTrim $legacyShareTrim

    if (-not (Test-Path $basePath)) {
        [System.Windows.Forms.MessageBox]::Show("Legacy base path $basePath does not exist.", "Error", `
             [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # List directories two levels deep from the base path
    try {
        $firstLevelDirs = Get-ChildItem -Path $basePath -Directory
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to list directories in $basePath.", "Error", `
             [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    foreach ($dir in $firstLevelDirs) {
        try {
            $secondLevelDirs = Get-ChildItem -Path $dir.FullName -Directory
        }
        catch {
            continue
        }
        foreach ($subDir in $secondLevelDirs) {
            $sourcePath = $subDir.FullName
            # Extract the relative path (e.g. "\home\students") from the base path
            $relativePath = $sourcePath.Substring($basePath.Length)
            if ($relativePath -notlike "\*") {
                $relativePath = "\" + $relativePath
            }
            $relativePath = $relativePath.TrimEnd("\")

            # Attempt an exact match against the Data Standards mapping Source-Path
            $match = $dataStandards | Where-Object { $_.'Source-Path'.Trim() -eq $relativePath }
            if ($match) {
                foreach ($m in $match) {
                    $destTemplate = $m.'Destination-Path'
                    $destination = ReplaceTokens $destTemplate $selectedSite

                    # Replace tokens in the Data Type field
                    $dataTypeReplaced = ReplaceTokens $m.'Data Type' $selectedSite
                    if ($dataTypeReplaced -and $dataTypeReplaced.StartsWith($selectedSite.'Site-Name')) {
                        $name = "$dataTypeReplaced Data"
                    }
                    else {
                        $name = "$($selectedSite.'Site-Name') $dataTypeReplaced Data"
                    }
                    $siteID = $selectedSite.'Site-Code'
                    # Add row with no error message
                    $dr = $dt.NewRow()
                    $dr["Site ID"] = $siteID
                    $dr["Name"] = $name
                    $dr["Source"] = $sourcePath
                    $dr["Destination"] = $destination
                    $dr["Errors"] = ""  # no error
                    $dt.Rows.Add($dr)
                }
            }
            else {
                $siteID = $selectedSite.'Site-Code'
                $name = "$($selectedSite.'Site-Name') Unknown Data"
                $dr = $dt.NewRow()
                $dr["Site ID"] = $siteID
                $dr["Name"] = $name
                $dr["Source"] = $sourcePath
                $dr["Destination"] = "Non standard share found"
                $dr["Errors"] = "Non standard share found"
                $dt.Rows.Add($dr)
            }
        }
    }
    # Sort the DataTable by Errors ascending
    $dt.DefaultView.Sort = "Errors ASC"
    $grid.DataSource = $dt.DefaultView
})

# ------------------------------
# Save CSV Button Event: Export the DataTable to CSV
# ------------------------------
$btnSave.Add_Click({
    if ($dt.Rows.Count -eq 0) { return }
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
    if ($saveFileDialog.ShowDialog() -eq "OK") {
        try {
            $dt | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation
            [System.Windows.Forms.MessageBox]::Show("CSV saved successfully to $($saveFileDialog.FileName)", "Success", `
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to save CSV.", "Error", `
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# ------------------------------
# Handle Form Resize to Adjust Grid Size
# ------------------------------
$form.Add_Resize({
    $grid.Width = $form.ClientSize.Width - 20
    $grid.Height = $form.ClientSize.Height - 120
})

[void]$form.ShowDialog()
