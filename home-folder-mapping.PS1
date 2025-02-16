# --- Configuration ---
$pathtranslation = "\\storageaccount.files.core.windows.net\staff-personal\"
$fuzzyThreshold = 0.25

# --- Add required .NET assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-LevenshteinDistance {
    param (
        [string]$s,
        [string]$t
    )
    if ($s.Length -eq 0) { return $t.Length }
    if ($t.Length -eq 0) { return $s.Length }
    $m = $s.Length + 1
    $n = $t.Length + 1
    $d = New-Object 'int[,]' $m, $n
    for ($i = 0; $i -lt $m; $i++) {
        $d[$i, 0] = $i
    }
    for ($j = 0; $j -lt $n; $j++) {
        $d[0, $j] = $j
    }
    for ($i = 1; $i -lt $m; $i++) {
        for ($j = 1; $j -lt $n; $j++) {
            if ($s[($i - 1)] -eq $t[($j - 1)]) { $cost = 0 } else { $cost = 1 }
            $deleteCost = $d[($i - 1), $j] + 1
            $insertCost = $d[$i, ($j - 1)] + 1
            $substituteCost = $d[($i - 1), ($j - 1)] + $cost
            $d[$i, $j] = [Math]::Min([Math]::Min($deleteCost, $insertCost), $substituteCost)
        }
    }
    return $d[$s.Length, $t.Length]
}

function Get-Similarity {
    param (
        [string]$s,
        [string]$t
    )
    $distance = Get-LevenshteinDistance -s $s -t $t
    $maxLen = [Math]::Max($s.Length, $t.Length)
    if ($maxLen -eq 0) { return 1 }
    return (1 - ($distance / $maxLen))
}

# --- Helper Functions for Pattern Matching ---
function Import-UserCsv {
    param (
        [string]$Path
    )
    $firstLine = Get-Content -Path $Path -TotalCount 1
    if ($firstLine -match "@") {
        return Import-Csv -Path $Path -Header "UPN","OneDrive"
    }
    else {
        return Import-Csv -Path $Path
    }
}

function Remove-TrailingNumbers {
    param (
        [string]$text
    )
    return ($text.Trim() -replace "\d+$", "")
}

# This function splits the username and returns name parts
function Extract-NameParts {
    param (
        [string]$fullName
    )
    $fullName = $fullName.Trim()
    $parts = $fullName.Split(".")
    if ($parts.Length -ge 2) {
        $firstName = $parts[0].Trim()
        $lastName = $parts[1].Trim()
        $firstInitial = $firstName.Substring(0,1)
        $lastInitial = $lastName.Substring(0,1)
        return @{
            FirstName    = $firstName;
            LastName     = $lastName;
            FirstInitial = $firstInitial;
            LastInitial  = $lastInitial
        }
    }
    else {
        return @{
            FirstName    = $fullName;
            LastName     = "";
            FirstInitial = $fullName.Substring(0,1);
            LastInitial  = ""
        }
    }
}

# Normalizes folder names (removes spaces) and checks against expected name parts.
function IsMatch {
    param (
        [string]$folderName,
        [hashtable]$nameParts
    )
    $folderNameNormalized = ($folderName.Trim().ToLower()) -replace "\s+", ""
    $firstName  = $nameParts.FirstName.ToLower()
    $lastName   = $nameParts.LastName.ToLower()
    $firstInit  = $nameParts.FirstInitial.ToLower()
    $lastInit   = $nameParts.LastInitial.ToLower()
    
    if ($folderNameNormalized -eq "$firstInit$lastName") { return $true }
    if ($folderNameNormalized -eq "$firstName$lastName") { return $true }
    if ($folderNameNormalized -eq "$lastName$firstName") { return $true }
    if ($folderNameNormalized -eq "$firstInit.$lastName") { return $true }
    if ($folderNameNormalized -eq "$firstName.$lastName") { return $true }
    for ($i = 1; $i -le 4; $i++) {
         $pattern = "^" + [regex]::Escape($firstInit) + ".{1,$i}" + [regex]::Escape($lastName) + "$"
         if ($folderNameNormalized -match $pattern) { return $true }
    }
    if ($folderNameNormalized -eq "$lastName$firstInit") { return $true }
    if ($folderNameNormalized -eq "$firstName$lastInit") { return $true }
    return $false
}

# --- New Helper Function: Get Directories Up To a Specified Depth ---
# This function returns subdirectories up to a given maxDepth (levels 1 and 2 in our case).
function Get-DirectoriesUpToDepth {
    param(
       [string]$Path,
       [int]$maxDepth = 2,
       [int]$currentLevel = 1
    )
    if ($currentLevel -gt $maxDepth) { return @() }
    $dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
    $result = @()
    foreach ($dir in $dirs) {
         $result += $dir
         $result += Get-DirectoriesUpToDepth -Path $dir.FullName -maxDepth $maxDepth -currentLevel ($currentLevel + 1)
    }
    return $result
}

# --- Build the GUI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Home Drive Mapping"
$form.Size = New-Object System.Drawing.Size(800,680)
$form.StartPosition = "CenterScreen"

# --- Site Metadata DropDown ---
$labelSelectSite = New-Object System.Windows.Forms.Label
$labelSelectSite.Location = New-Object System.Drawing.Point(10,20)
$labelSelectSite.Size = New-Object System.Drawing.Size(120,20)
$labelSelectSite.Text = "Select Site:"
$form.Controls.Add($labelSelectSite)

$comboBoxSite = New-Object System.Windows.Forms.ComboBox
$comboBoxSite.Location = New-Object System.Drawing.Point(140,20)
$comboBoxSite.Size = New-Object System.Drawing.Size(250,20)
$comboBoxSite.DropDownStyle = 'DropDownList'
$form.Controls.Add($comboBoxSite)

# Global variables for site metadata and selection
$global:siteMetadata = @()
$global:selectedSite = $null
$global:knownHomes = ""

# Load site-metadata.csv from the script's root folder.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$metadataPath = Join-Path $scriptDir "site-metadata.csv"
if (Test-Path $metadataPath) {
    $global:siteMetadata = Import-Csv -Path $metadataPath
    foreach ($site in $global:siteMetadata) {
        $comboBoxSite.Items.Add($site.'Site-Name') | Out-Null
    }
}
else {
    [System.Windows.Forms.MessageBox]::Show("site-metadata.csv not found in $scriptDir","Error","OK","Error")
}

# When a site is selected, prepopulate the directory textbox and store the selected site info.
$comboBoxSite.Add_SelectedIndexChanged({
    $selectedSiteName = $comboBoxSite.SelectedItem
    $matchSite = $global:siteMetadata | Where-Object { $_."Site-Name" -eq $selectedSiteName }
    if ($matchSite) {
        $global:selectedSite = $matchSite
        $legacyRoot = $matchSite.'Legacy-Root'
        $legacyShare = $matchSite.'Legacy-Share'
        if (-not $legacyRoot.EndsWith("\")) { $legacyRoot += "\" }
        $basePath = ($legacyRoot.TrimEnd("\") + $legacyShare).Replace("\\\\", "\")
        $textBoxDir.Text = $basePath
        $global:knownHomes = $matchSite.'Known-Homes'
    }
})

# --- CSV file selection ---
$labelCSV = New-Object System.Windows.Forms.Label
$labelCSV.Location = New-Object System.Drawing.Point(10,60)
$labelCSV.Size = New-Object System.Drawing.Size(120,20)
$labelCSV.Text = "Select CSV File:"
$form.Controls.Add($labelCSV)

$textBoxCSV = New-Object System.Windows.Forms.TextBox
$textBoxCSV.Location = New-Object System.Drawing.Point(140,60)
$textBoxCSV.Size = New-Object System.Drawing.Size(500,20)
$form.Controls.Add($textBoxCSV)

$buttonBrowseCSV = New-Object System.Windows.Forms.Button
$buttonBrowseCSV.Location = New-Object System.Drawing.Point(650,58)
$buttonBrowseCSV.Size = New-Object System.Drawing.Size(100,24)
$buttonBrowseCSV.Text = "Browse CSV"
$form.Controls.Add($buttonBrowseCSV)

# --- Directory selection ---
$labelDir = New-Object System.Windows.Forms.Label
$labelDir.Location = New-Object System.Drawing.Point(10,100)
$labelDir.Size = New-Object System.Drawing.Size(120,20)
$labelDir.Text = "Select Directory:"
$form.Controls.Add($labelDir)

$textBoxDir = New-Object System.Windows.Forms.TextBox
$textBoxDir.Location = New-Object System.Drawing.Point(140,100)
$textBoxDir.Size = New-Object System.Drawing.Size(500,20)
$form.Controls.Add($textBoxDir)

$buttonBrowseDir = New-Object System.Windows.Forms.Button
$buttonBrowseDir.Location = New-Object System.Drawing.Point(650,98)
$buttonBrowseDir.Size = New-Object System.Drawing.Size(100,24)
$buttonBrowseDir.Text = "Browse Dir"
$form.Controls.Add($buttonBrowseDir)

# --- Checkboxes for extra data ---
$checkBoxFileCount = New-Object System.Windows.Forms.CheckBox
$checkBoxFileCount.Location = New-Object System.Drawing.Point(140,140)
$checkBoxFileCount.Size = New-Object System.Drawing.Size(150,20)
$checkBoxFileCount.Text = "Include File Count"
$form.Controls.Add($checkBoxFileCount)

$checkBoxFolderSize = New-Object System.Windows.Forms.CheckBox
$checkBoxFolderSize.Location = New-Object System.Drawing.Point(300,140)
$checkBoxFolderSize.Size = New-Object System.Drawing.Size(150,20)
$checkBoxFolderSize.Text = "Include Folder Size"
$form.Controls.Add($checkBoxFolderSize)

# --- Run and Save buttons ---
$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Location = New-Object System.Drawing.Point(10,180)
$buttonRun.Size = New-Object System.Drawing.Size(100,30)
$buttonRun.Text = "Run"
$form.Controls.Add($buttonRun)

$buttonSave = New-Object System.Windows.Forms.Button
$buttonSave.Location = New-Object System.Drawing.Point(120,180)
$buttonSave.Size = New-Object System.Drawing.Size(100,30)
$buttonSave.Text = "Save CSV"
$form.Controls.Add($buttonSave)

# --- DataGridView for results ---
$dataGrid = New-Object System.Windows.Forms.DataGridView
$dataGrid.Location = New-Object System.Drawing.Point(10,220)
$dataGrid.Size = New-Object System.Drawing.Size(760,380)
$dataGrid.AutoSizeColumnsMode = "Fill"
$dataGrid.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($dataGrid)

$global:results = @()

# --- Context Menu: Right-Click "Copy as CSV" ---
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuItemCopyAsCSV = New-Object System.Windows.Forms.ToolStripMenuItem("Copy as CSV")
$contextMenu.Items.Add($menuItemCopyAsCSV)
$dataGrid.ContextMenuStrip = $contextMenu

$menuItemCopyAsCSV.add_Click({
    $selectedRows = $dataGrid.SelectedRows
    if ($selectedRows.Count -eq 0) { return }
    # Build CSV text: include headers
    $headers = $dataGrid.Columns | ForEach-Object { $_.HeaderText }
    $csvContent = @()
    $csvContent += [string]::Join(",", $headers)
    foreach ($row in $selectedRows) {
        $values = @()
        foreach ($col in $dataGrid.Columns) {
            $cellValue = $row.Cells[$col.Index].Value
            if ($cellValue -eq $null) { $cellValue = "" }
            $escapedValue = $cellValue.ToString().Replace('"','""')
            if ($escapedValue.Contains(",") -or $escapedValue.Contains('"') -or $escapedValue.Contains("`n")) {
                $escapedValue = '"' + $escapedValue + '"'
            }
            $values += $escapedValue
        }
        $csvContent += [string]::Join(",", $values)
    }
    $csvText = $csvContent -join "`r`n"
    [System.Windows.Forms.Clipboard]::SetText($csvText)
})

# --- Event Handlers ---
$buttonBrowseCSV.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
    if ($openFileDialog.ShowDialog() -eq "OK") {
         $textBoxCSV.Text = $openFileDialog.FileName
    }
})

$buttonBrowseDir.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq "OK") {
         $textBoxDir.Text = $folderBrowser.SelectedPath
    }
})

$buttonRun.Add_Click({
    $global:results = @()
    if (-not (Test-Path $textBoxCSV.Text)) { return }
    try {
         $users = Import-UserCsv -Path $textBoxCSV.Text
    }
    catch { return }
    if (-not (Test-Path $textBoxDir.Text)) { return }
    
    # Build folder list.
    $folderInfoList = @()
    if ($global:knownHomes -and $global:knownHomes.Trim() -ne "") {
         # Use each known-home folder as the base and search only 1–2 levels deep.
         $knownHomesList = $global:knownHomes.Split(";") | ForEach-Object { $_.Trim() }
         foreach ($homeFolder in $knownHomesList) {
             $homePath = Join-Path $textBoxDir.Text $homeFolder
             if (Test-Path $homePath) {
                 $folders = Get-DirectoriesUpToDepth -Path $homePath -maxDepth 2
                 foreach ($folder in $folders) {
                     $folderInfoList += [PSCustomObject]@{
                         FolderName    = $folder.Name
                         UNCPath       = $folder.FullName
                         "File Count"  = $null
                         "Folder Size" = $null
                     }
                 }
             }
         }
    }
    else {
         # If no known-home is defined, use the base directory and search deeper if needed.
         $basePath = $textBoxDir.Text
         if (Test-Path $basePath) {
             # Here you could adjust the depth if desired (using maxDepth 3, for example)
             $folders = Get-DirectoriesUpToDepth -Path $basePath -maxDepth 3
             foreach ($folder in $folders) {
                 $folderInfoList += [PSCustomObject]@{
                     FolderName    = $folder.Name
                     UNCPath       = $folder.FullName
                     "File Count"  = $null
                     "Folder Size" = $null
                 }
             }
         }
    }
    
    # Process each user from the CSV.
    foreach ($user in $users) {
         if ($user.UPN) {
              $email = $user.UPN.Trim()
              $localPart = ($email.Split("@")[0]).Trim()
              $localPart = Remove-TrailingNumbers $localPart
              $nameParts = Extract-NameParts $localPart
              
              # Attempt exact pattern matching.
              $matchesForUser = @()
              foreach ($folder in $folderInfoList) {
                   if (IsMatch $folder.FolderName $nameParts) {
                        $basePath = $textBoxDir.Text.Trim()
                        if (-not $basePath.EndsWith("\")) { $basePath += "\" }
                        $relativePath = $folder.UNCPath.Substring($basePath.Length)
                        if ($relativePath.StartsWith("\")) { $relativePath = $relativePath.Substring(1) }
                        $siteCode = ($global:selectedSite.'Site-Code').Trim()
                        $newSource = $pathtranslation + $siteCode + "\" + $relativePath
                        
                        $matchesForUser += [PSCustomObject]@{
                             "Email"       = $email
                             "Source"      = $newSource
                             "OneDrive"    = $user.OneDrive
                             "UNCPath"     = $folder.UNCPath
                             "File Count"  = $null
                             "Folder Size" = $null
                             "Errors"      = ""
                        }
                   }
              }
              
              # If no exact match was found, try fuzzy matching.
              if ($matchesForUser.Count -eq 0) {
                   $bestMatch = $null
                   $bestScore = 0
                   $reference = $localPart.ToLower()
                   foreach ($folder in $folderInfoList) {
                        $folderName = ($folder.FolderName.Trim().ToLower()) -replace "\s+", ""
                        $score = Get-Similarity -s $folderName -t $reference
                        if ($score -gt $bestScore) {
                             $bestScore = $score
                             $bestMatch = $folder
                        }
                   }
                   if ($bestScore -ge $fuzzyThreshold -and $bestMatch -ne $null) {
                        $basePath = $textBoxDir.Text.Trim()
                        if (-not $basePath.EndsWith("\")) { $basePath += "\" }
                        $relativePath = $bestMatch.UNCPath.Substring($basePath.Length)
                        if ($relativePath.StartsWith("\")) { $relativePath = $relativePath.Substring(1) }
                        $siteCode = ($global:selectedSite.'Site-Code').Trim()
                        $newSource = $pathtranslation + $siteCode + "\" + $relativePath
                        
                        $global:results += [PSCustomObject]@{
                             "Email"       = $email
                             "Source"      = $newSource
                             "OneDrive"    = $user.OneDrive
                             "UNCPath"     = $bestMatch.UNCPath
                             "File Count"  = $null
                             "Folder Size" = $null
                             "Errors"      = ("Fuzzy Match (score: {0:N2})" -f $bestScore)
                        }
                   }
                   else {
                        $global:results += [PSCustomObject]@{
                             "Email"       = $email
                             "Source"      = ""
                             "OneDrive"    = $user.OneDrive
                             "UNCPath"     = ""
                             "File Count"  = ""
                             "Folder Size" = ""
                             "Errors"      = "Home Folder Not Found"
                        }
                   }
              }
              else {
                   if ($matchesForUser.Count -gt 1) {
                        foreach ($match in $matchesForUser) {
                             $match.Errors = "Duplicate"
                        }
                   }
                   $global:results += $matchesForUser
              }
         }
    }
    
    # Now, only compute file count and folder size for duplicates.
    foreach ($result in $global:results) {
         if ($result.Errors -and $result.Errors -like "*Duplicate*") {
              if ($checkBoxFileCount.Checked -and $result.UNCPath) {
                   try {
                       $files = Get-ChildItem -Path $result.UNCPath -Recurse -File -ErrorAction SilentlyContinue
                       $result."File Count" = $files.Count
                   }
                   catch {
                       $result."File Count" = "Error"
                   }
              }
              if ($checkBoxFolderSize.Checked -and $result.UNCPath) {
                   try {
                       $files = Get-ChildItem -Path $result.UNCPath -Recurse -File -ErrorAction SilentlyContinue
                       $sizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
                       $result."Folder Size" = [math]::Round($sizeBytes / 1MB, 2)
                   }
                   catch {
                       $result."Folder Size" = "Error"
                   }
              }
         }
    }
    
    # Build a DataTable for display.
    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("Email") | Out-Null
    $dt.Columns.Add("Source") | Out-Null
    $dt.Columns.Add("OneDrive") | Out-Null
    $dt.Columns.Add("File Count") | Out-Null
    $dt.Columns.Add("Folder Size (MB)") | Out-Null
    $dt.Columns.Add("Errors") | Out-Null
    
    foreach ($item in $global:results) {
         $row = $dt.NewRow()
         $row["Email"] = $item.Email
         $row["Source"] = $item.Source
         $row["OneDrive"] = $item.OneDrive
         $row["File Count"] = $item."File Count"
         $row["Folder Size (MB)"] = $item."Folder Size"
         $row["Errors"] = $item.Errors
         $dt.Rows.Add($row)
    }
    
    $dataGrid.DataSource = $dt
    $dataGrid.Refresh()
})

$buttonSave.Add_Click({
    if ($global:results.Count -eq 0) { return }
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
    if ($saveFileDialog.ShowDialog() -eq "OK") {
         try {
              $global:results | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation
         }
         catch { }
    }
})

# --- Highlight Rows with Errors ---
$dataGrid.add_RowPrePaint({
    param($sender, $e)
    $row = $sender.Rows[$e.RowIndex]
    if ($row.Cells["Errors"].Value -and $row.Cells["Errors"].Value.ToString().Trim() -ne "") {
         $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::LightPink
    }
})

[void]$form.ShowDialog()
