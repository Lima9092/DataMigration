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

# Load required .NET assemblies for Windows Forms and Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Helper Functions ---

# Function to load a CSV file and return its contents
function Load-CSVFile($filePath) {
    try {
        return Import-Csv -Path $filePath
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to load CSV: $filePath", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $null
    }
}

# Function to replace tokens in a template string using the global variables and the selected site
function ReplaceTokens($template, $siteMetadata) {
    if (-not $template) { return "" }
    $result = $template
    $result = $result.Replace("<storageAccount>", $GlobalStorageAccount)
    $result = $result.Replace("<studentcontainer>", $GlobalStudentContainer)
    $result = $result.Replace("<staffpersonalshare>", $GlobalStaffPersonalShare)
    $result = $result.Replace("<SASToken>", $GlobalSASToken)
    $result = $result.Replace("<sitecode>", $siteMetadata.'Site-Code')
    $result = $result.Replace("<sitename>", $siteMetadata.'Site-Name')
    return $result
}

# --- Build the GUI ---

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Data Migration Tool"
$form.Size = New-Object System.Drawing.Size(800,600)
$form.StartPosition = "CenterScreen"

# Site selection dropdown (populated from Site-Metadata CSV)
$lblSiteSelect = New-Object System.Windows.Forms.Label
$lblSiteSelect.Location = New-Object System.Drawing.Point(10,10)
$lblSiteSelect.Size = New-Object System.Drawing.Size(200,20)
$lblSiteSelect.Text = "Select Site:"
$form.Controls.Add($lblSiteSelect)

$cmbSite = New-Object System.Windows.Forms.ComboBox
$cmbSite.Location = New-Object System.Drawing.Point(10,35)
$cmbSite.Size = New-Object System.Drawing.Size(300,20)
$form.Controls.Add($cmbSite)

# Run button to start processing
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Location = New-Object System.Drawing.Point(10,65)
$btnRun.Size = New-Object System.Drawing.Size(75,23)
$btnRun.Text = "Run"
$form.Controls.Add($btnRun)

# Data grid to display output in a spreadsheet-like view
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(10,100)
$grid.Size = New-Object System.Drawing.Size(760,400)
$grid.AutoSizeColumnsMode = "Fill"
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$form.Controls.Add($grid)

# Right-click context menu for "Copy as CSV"
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuItemCopyCSV = New-Object System.Windows.Forms.ToolStripMenuItem("Copy as CSV")
$contextMenu.Items.Add($menuItemCopyCSV) | Out-Null
$grid.ContextMenuStrip = $contextMenu

$menuItemCopyCSV.Add_Click({
    $csvText = ""
    # Build header row
    $headers = @()
    foreach ($col in $grid.Columns) {
        $headers += $col.HeaderText
    }
    $csvText += ($headers -join ",") + "`r`n"
    # Build each row's CSV line
    foreach ($row in $grid.Rows) {
        if (-not $row.IsNewRow) {
            $cells = @()
            foreach ($cell in $row.Cells) {
                $val = $cell.Value
                if ($val -eq $null) { $val = "" }
                $cells += $val.ToString()
            }
            $csvText += ($cells -join ",") + "`r`n"
        }
    }
    [System.Windows.Forms.Clipboard]::SetText($csvText, 'Text')
})

# --- Preload Site Metadata CSV and Populate the Dropdown ---
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
    [System.Windows.Forms.MessageBox]::Show("Site Metadata CSV not found at: $SiteMetadataCSV", "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

# --- Setup the Data Grid Columns ---
$grid.Columns.Add("SiteID", "Site ID") | Out-Null
$grid.Columns.Add("Name", "Name") | Out-Null
$grid.Columns.Add("Source", "Source") | Out-Null
$grid.Columns.Add("Destination", "Destination") | Out-Null

# --- Run Button Event: Process the Data Migration ---
$btnRun.Add_Click({
    $grid.Rows.Clear()

    $dataStandards = Load-CSVFile $DataStandardsCSV
    $sites = Load-CSVFile $SiteMetadataCSV

    if (-not $dataStandards -or -not $sites) {
        [System.Windows.Forms.MessageBox]::Show("One or more CSV files could not be loaded.", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Get the selected site record from Site Metadata based on the dropdown selection
    $selectedSiteName = $cmbSite.SelectedItem
    $selectedSite = $sites | Where-Object { $_.'Site-Name' -eq $selectedSiteName } | Select-Object -First 1
    if (-not $selectedSite) {
        [System.Windows.Forms.MessageBox]::Show("Selected site not found in Site Metadata.", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Get legacy meta data and check for missing values
    $legacyRoot = $selectedSite.'Legacy-Root'
    $legacyShare = $selectedSite.'Legacy-Share'
    if ([string]::IsNullOrEmpty($legacyRoot)) {
        [System.Windows.Forms.MessageBox]::Show("Missing Legacy-Root for site $selectedSiteName", "Meta Data Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    if ([string]::IsNullOrEmpty($legacyShare)) {
        [System.Windows.Forms.MessageBox]::Show("Missing Legacy-Share for site $selectedSiteName", "Meta Data Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Compute the base legacy path using the selected site's Legacy-Root and Legacy-Share
    $legacyRootTrim = $legacyRoot.TrimEnd("\")
    $legacyShareTrim = $legacyShare.TrimStart("\")
    $basePath = Join-Path $legacyRootTrim $legacyShareTrim

    if (-not (Test-Path $basePath)) {
        [System.Windows.Forms.MessageBox]::Show("Legacy base path $basePath does not exist.", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # List directories two levels deep from the base path
    try {
        $firstLevelDirs = Get-ChildItem -Path $basePath -Directory
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to list directories in $basePath.", "Error",
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
                    $grid.Rows.Add($siteID, $name, $sourcePath, $destination) | Out-Null
                }
            }
            else {
                $siteID = $selectedSite.'Site-Code'
                $name = "$($selectedSite.'Site-Name') Unknown Data"
                $rowIndex = $grid.Rows.Add()
                $row = $grid.Rows[$rowIndex]
                $row.Cells["SiteID"].Value = $siteID
                $row.Cells["Name"].Value = $name
                $row.Cells["Source"].Value = $sourcePath
                $row.Cells["Destination"].Value = "Non standard share found"
                $row.Cells["Destination"].Style.ForeColor = [System.Drawing.Color]::Red
            }
        }
    }
})

# --- Handle Form Resize to Adjust Grid Size ---
$form.Add_Resize({
    $grid.Width = $form.ClientSize.Width - 20
    $grid.Height = $form.ClientSize.Height - 120
})

# Show the form
[void]$form.ShowDialog()
