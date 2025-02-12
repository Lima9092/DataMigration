Add-Type -MemberDefinition @"
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(System.IntPtr hWnd, int nCmdShow);
"@ -Name "Win32" -Namespace "PInvoke"

# SW_MINIMIZE constant is 6 (SW_HIDE would be 0)
$consoleHandle = (Get-Process -Id $pid).MainWindowHandle
if ($consoleHandle -ne [IntPtr]::Zero) {
    [PInvoke.Win32]::ShowWindowAsync($consoleHandle, 6)
}

# Add required .NET assemblies for GUI and drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# Helper: Import CSV file (with header if needed)

function Import-UserCsv {
    param (
        [string]$Path
    )
    # Read the first line to decide if a header exists.
    $firstLine = Get-Content -Path $Path -TotalCount 1
    if ($firstLine -match "@") {
        # Force header to be UPN and OneDrive (adjust if needed)
        return Import-Csv -Path $Path -Header "UPN","OneDrive"
    }
    else {
        return Import-Csv -Path $Path
    }
}


# Functions for Pattern Matching (working version)

# Remove trailing numbers and trim extra spaces (e.g. "john.doe123" becomes "john.doe")
function Remove-TrailingNumbers {
    param (
        [string]$text
    )
    return ($text.Trim() -replace "\d+$", "")
}

# Extract name parts from a string assumed to be "FirstName.LastName"
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

# Test whether a folder name matches one of the expected patterns derived from the user’s name parts.
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
    
    # Pattern 1: firstInitial.lastName (e.g. "j.doe")
    if ($folderNameLower -eq "$firstInit.$lastName") { return $true }
    # Pattern 2: firstName.lastName (e.g. "john.doe")
    if ($folderNameLower -eq "$firstName.$lastName") { return $true }
    # Pattern 3: firstInitiallastName (e.g. "jdoe")
    if ($folderNameLower -eq "$firstInit$lastName") { return $true }
    
    # Pattern 4: firstInitial followed by 1-4 arbitrary characters then lastName
    for ($i = 1; $i -le 4; $i++) {
         $pattern = "^" + [regex]::Escape($firstInit) + ".{1,$i}" + [regex]::Escape($lastName) + "$"
         if ($folderNameLower -match $pattern) { return $true }
    }
    # Pattern 5: lastNamefirstInitial (e.g. "doej")
    if ($folderNameLower -eq "$lastName$firstInit") { return $true }
    # Pattern 6: firstNamelastName (e.g. "johndoe")
    if ($folderNameLower -eq "$firstName$lastName") { return $true }
    # Pattern 7: lastNamefirstName (e.g. "doejohn")
    if ($folderNameLower -eq "$lastName$firstName") { return $true }
    # Pattern 8: firstNamelastInitial (e.g. "johnd")
    if ($folderNameLower -eq "$firstName$lastInit") { return $true }
    
    return $false
}


# Build the GUI

$form = New-Object System.Windows.Forms.Form
$form.Text = "Home Drive Mapping"
$form.Size = New-Object System.Drawing.Size(800,600)
$form.StartPosition = "CenterScreen"

# CSV file selection
$labelCSV = New-Object System.Windows.Forms.Label
$labelCSV.Location = New-Object System.Drawing.Point(10,20)
$labelCSV.Size = New-Object System.Drawing.Size(120,20)
$labelCSV.Text = "Select Users CSV File:"
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
$labelDir.Text = "Select Home Directory:"
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

# Checkboxes for extra data
$checkBoxFileCount = New-Object System.Windows.Forms.CheckBox
$checkBoxFileCount.Location = New-Object System.Drawing.Point(140,100)
$checkBoxFileCount.Size = New-Object System.Drawing.Size(150,20)
$checkBoxFileCount.Text = "Include File Count"
$form.Controls.Add($checkBoxFileCount)

$checkBoxFolderSize = New-Object System.Windows.Forms.CheckBox
$checkBoxFolderSize.Location = New-Object System.Drawing.Point(300,100)
$checkBoxFolderSize.Size = New-Object System.Drawing.Size(150,20)
$checkBoxFolderSize.Text = "Include Folder Size"
$form.Controls.Add($checkBoxFolderSize)

# Run and Save buttons
$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Location = New-Object System.Drawing.Point(10,140)
$buttonRun.Size = New-Object System.Drawing.Size(100,30)
$buttonRun.Text = "Run"
$form.Controls.Add($buttonRun)

$buttonSave = New-Object System.Windows.Forms.Button
$buttonSave.Location = New-Object System.Drawing.Point(120,140)
$buttonSave.Size = New-Object System.Drawing.Size(100,30)
$buttonSave.Text = "Save CSV"
$form.Controls.Add($buttonSave)

# DataGridView for results; bind a DataTable for headers.
$dataGrid = New-Object System.Windows.Forms.DataGridView
$dataGrid.Location = New-Object System.Drawing.Point(10,180)
$dataGrid.Size = New-Object System.Drawing.Size(760,300)
$dataGrid.AutoSizeColumnsMode = "Fill"
$dataGrid.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor `
                     [System.Windows.Forms.AnchorStyles]::Bottom -bor `
                     [System.Windows.Forms.AnchorStyles]::Left -bor `
                     [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($dataGrid)

$global:results = @()


# Event Handlers

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
    
    # Get top-level folders in the selected directory.
    $topFolders = Get-ChildItem -Path $textBoxDir.Text -Directory
    $folderInfoList = @()
    foreach ($topFolder in $topFolders) {
         # Recurse one additional level: get subfolders within each top folder.
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
              
              # Gather all matching folder records for this user.
              $matchesForUser = @()
              foreach ($folder in $folderInfoList) {
                   if (IsMatch $folder.FolderName $nameParts) {
                        $matchesForUser += [PSCustomObject]@{
                             "Email"       = $email
                             "Source"      = $folder.UNCPath
                             "OneDrive"    = $user.OneDrive
                             "File Count"  = $folder."File Count"
                             "Folder Size" = $folder."Folder Size"
                             "Errors"      = ""
                        }
                   }
              }
              
              if ($matchesForUser.Count -gt 0) {
                   # If more than one folder match is found for this user, mark each with "Duplicate".
                   if ($matchesForUser.Count -gt 1) {
                        foreach ($match in $matchesForUser) {
                             $match.Errors = "Duplicate"
                        }
                   }
                   $global:results += $matchesForUser
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
    }
    
    # Build a DataTable for display with headers.
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
