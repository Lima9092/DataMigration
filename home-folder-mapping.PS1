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

    # Dimensions of the matrix
    $m = $s.Length + 1
    $n = $t.Length + 1
    $d = New-Object 'int[,]' $m, $n

    # Initialize the first column and row.
    for ($i = 0; $i -lt $m; $i++) {
        $d[$i, 0] = $i
    }
    for ($j = 0; $j -lt $n; $j++) {
        $d[0, $j] = $j
    }

    # Populate the matrix.
    for ($i = 1; $i -lt $m; $i++) {
        for ($j = 1; $j -lt $n; $j++) {
            if ($s[($i - 1)] -eq $t[($j - 1)]) {
                $cost = 0
            }
            else {
                $cost = 1
            }
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

function IsMatch {
    param (
        [string]$folderName,
        [hashtable]$nameParts
    )
    $folderNameLower = $folderName.Trim().ToLower()
    $firstName  = $nameParts.FirstName.ToLower()
    $lastName   = $nameParts.LastName.ToLower()
    $firstInit  = $nameParts.FirstInitial.ToLower()
    $lastInit   = $nameParts.LastInitial.ToLower()
    
    if ($folderNameLower -eq "$firstInit.$lastName") { return $true }
    if ($folderNameLower -eq "$firstName.$lastName") { return $true }
    if ($folderNameLower -eq "$firstInit$lastName") { return $true }
    
    for ($i = 1; $i -le 4; $i++) {
         $pattern = "^" + [regex]::Escape($firstInit) + ".{1,$i}" + [regex]::Escape($lastName) + "$"
         if ($folderNameLower -match $pattern) { return $true }
    }
    if ($folderNameLower -eq "$lastName$firstInit") { return $true }
    if ($folderNameLower -eq "$firstName$lastName") { return $true }
    if ($folderNameLower -eq "$lastName$firstName") { return $true }
    if ($folderNameLower -eq "$firstName$lastInit") { return $true }
    
    return $false
}

# --- Build the GUI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Home Drive Mapping"
$form.Size = New-Object System.Drawing.Size(800,600)
$form.StartPosition = "CenterScreen"

# CSV file selection
$labelCSV = New-Object System.Windows.Forms.Label
$labelCSV.Location = New-Object System.Drawing.Point(10,20)
$labelCSV.Size = New-Object System.Drawing.Size(120,20)
$labelCSV.Text = "Select CSV File:"
$form.Controls.Add($labelCSV)

$textBoxCSV = New-Object System.Windows.Forms.TextBox
$textBoxCSV.Location = New-Object System.Drawing.Point(140,20)
$textBoxCSV.Size = New-Object System.Drawing.Size(500,20)
$form.Controls.Add($textBoxCSV)

$buttonBrowseCSV = New-Object System.Windows.Forms.Button
$buttonBrowseCSV.Location = New-Object System.Drawing.Point(650,18)
$buttonBrowseCSV.Size = New-Object System.Drawing.Size(100,24)
$buttonBrowseCSV.Text = "Browse CSV"
$form.Controls.Add($buttonBrowseCSV)

# Directory selection
$labelDir = New-Object System.Windows.Forms.Label
$labelDir.Location = New-Object System.Drawing.Point(10,60)
$labelDir.Size = New-Object System.Drawing.Size(120,20)
$labelDir.Text = "Select Directory:"
$form.Controls.Add($labelDir)

$textBoxDir = New-Object System.Windows.Forms.TextBox
$textBoxDir.Location = New-Object System.Drawing.Point(140,60)
$textBoxDir.Size = New-Object System.Drawing.Size(500,20)
$form.Controls.Add($textBoxDir)

$buttonBrowseDir = New-Object System.Windows.Forms.Button
$buttonBrowseDir.Location = New-Object System.Drawing.Point(650,58)
$buttonBrowseDir.Size = New-Object System.Drawing.Size(100,24)
$buttonBrowseDir.Text = "Browse Dir"
$form.Controls.Add($buttonBrowseDir)

# Site Code selection (aligned with other text boxes)
$labelSite = New-Object System.Windows.Forms.Label
$labelSite.Location = New-Object System.Drawing.Point(10,100)
$labelSite.Size = New-Object System.Drawing.Size(120,20)
$labelSite.Text = "Site Code:"
$form.Controls.Add($labelSite)

$textBoxSite = New-Object System.Windows.Forms.TextBox
$textBoxSite.Location = New-Object System.Drawing.Point(140,100)
$textBoxSite.Size = New-Object System.Drawing.Size(150,20)
$form.Controls.Add($textBoxSite)

# Checkboxes for extra data
$checkBoxFileCount = New-Object System.Windows.Forms.CheckBox
$checkBoxFileCount.Location = New-Object System.Drawing.Point(140,130)
$checkBoxFileCount.Size = New-Object System.Drawing.Size(150,20)
$checkBoxFileCount.Text = "Include File Count"
$form.Controls.Add($checkBoxFileCount)

$checkBoxFolderSize = New-Object System.Windows.Forms.CheckBox
$checkBoxFolderSize.Location = New-Object System.Drawing.Point(300,130)
$checkBoxFolderSize.Size = New-Object System.Drawing.Size(150,20)
$checkBoxFolderSize.Text = "Include Folder Size"
$form.Controls.Add($checkBoxFolderSize)

# Run and Save buttons
$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Location = New-Object System.Drawing.Point(10,160)
$buttonRun.Size = New-Object System.Drawing.Size(100,30)
$buttonRun.Text = "Run"
$form.Controls.Add($buttonRun)

$buttonSave = New-Object System.Windows.Forms.Button
$buttonSave.Location = New-Object System.Drawing.Point(120,160)
$buttonSave.Size = New-Object System.Drawing.Size(100,30)
$buttonSave.Text = "Save CSV"
$form.Controls.Add($buttonSave)

# DataGridView for results; bind a DataTable for headers.
$dataGrid = New-Object System.Windows.Forms.DataGridView
$dataGrid.Location = New-Object System.Drawing.Point(10,200)
$dataGrid.Size = New-Object System.Drawing.Size(760,300)
$dataGrid.AutoSizeColumnsMode = "Fill"
$dataGrid.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor `
                     [System.Windows.Forms.AnchorStyles]::Bottom -bor `
                     [System.Windows.Forms.AnchorStyles]::Left -bor `
                     [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($dataGrid)

$global:results = @()

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
    
    # Get top-level folders, then get subfolders one level deeper (assumed home folders).
    $topFolders = Get-ChildItem -Path $textBoxDir.Text -Directory
    $folderInfoList = @()
    foreach ($topFolder in $topFolders) {
         $subFolders = Get-ChildItem -Path $topFolder.FullName -Directory
         foreach ($folder in $subFolders) {
              $folderInfo = [PSCustomObject]@{
                   FolderName    = $folder.Name
                   UNCPath       = $folder.FullName
                   "File Count"  = $null
                   "Folder Size" = $null
              }
              if ($checkBoxFileCount.Checked) {
                   try {
                        $files = Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue
                        $folderInfo."File Count" = $files.Count
                   }
                   catch {
                        $folderInfo."File Count" = "Error"
                   }
              }
              if ($checkBoxFolderSize.Checked) {
                   try {
                        $files = Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue
                        $sizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
                        $folderInfo."Folder Size" = [math]::Round($sizeBytes / 1MB, 2)
                   }
                   catch {
                        $folderInfo."Folder Size" = "Error"
                   }
              }
              $folderInfoList += $folderInfo
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
                        # Compute relative path from the chosen directory.
                        $basePath = $textBoxDir.Text.Trim()
                        if (-not $basePath.EndsWith("\")) { $basePath += "\" }
                        $relativePath = $folder.UNCPath.Substring($basePath.Length)
                        if ($relativePath.StartsWith("\")) { $relativePath = $relativePath.Substring(1) }
                        $siteCode = $textBoxSite.Text.Trim()
                        $newSource = $pathtranslation + $siteCode + "\" + $relativePath
                        
                        $matchesForUser += [PSCustomObject]@{
                             "Email"       = $email
                             "Source"      = $newSource
                             "OneDrive"    = $user.OneDrive
                             "File Count"  = $folder."File Count"
                             "Folder Size" = $folder."Folder Size"
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
                        $folderName = $folder.FolderName.Trim().ToLower()
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
                        $siteCode = $textBoxSite.Text.Trim()
                        $newSource = $pathtranslation + $siteCode + "\" + $relativePath
                        
                        $global:results += [PSCustomObject]@{
                             "Email"       = $email
                             "Source"      = $newSource
                             "OneDrive"    = $user.OneDrive
                             "File Count"  = $bestMatch."File Count"
                             "Folder Size" = $bestMatch."Folder Size"
                             "Errors"      = ("Fuzzy Match (score: {0:N2})" -f $bestScore)
                        }
                   }
                   else {
                        $global:results += [PSCustomObject]@{
                             "Email"       = $email
                             "Source"      = ""
                             "OneDrive"    = $user.OneDrive
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

[void]$form.ShowDialog()
