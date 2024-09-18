# Import necessary assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to check and install required modules
function Check-And-InstallModule {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        $install = [System.Windows.Forms.MessageBox]::Show("$ModuleName is not installed. Would you like to install it now?", "Module Not Found", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($install -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                Install-Module -Name $ModuleName -Scope CurrentUser -Force
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to install $ModuleName. Error: $_", "Installation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                exit
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("The script cannot run without $ModuleName. Exiting.", "Module Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            exit
        }
    }
}

# Check and install Az.Accounts module
Check-And-InstallModule -ModuleName 'Az.Accounts'

# Check and install Az.Storage module
Check-And-InstallModule -ModuleName 'Az.Storage'

# Import Azure modules
Import-Module Az.Accounts -Force
Import-Module Az.Storage -Force

# Add this type to allow window manipulation
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Minimize the PowerShell console window
$consolePtr = [ConsoleWindow]::GetConsoleWindow()
[ConsoleWindow]::ShowWindow($consolePtr, 2)

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Azure Storage Search Tool"
$form.Size = New-Object System.Drawing.Size(800,800)
$form.StartPosition = "CenterScreen"

# Create and add controls
# Storage Type Selection (File Share or Blob Container)
$lblStorageType = New-Object System.Windows.Forms.Label
$lblStorageType.Location = New-Object System.Drawing.Point(10,20)
$lblStorageType.Size = New-Object System.Drawing.Size(100,20)
$lblStorageType.Text = "Storage Type:"
$form.Controls.Add($lblStorageType)

$rbFileShare = New-Object System.Windows.Forms.RadioButton
$rbFileShare.Location = New-Object System.Drawing.Point(120,20)
$rbFileShare.Size = New-Object System.Drawing.Size(80,20)
$rbFileShare.Text = "File Share"
$rbFileShare.Checked = $true
$form.Controls.Add($rbFileShare)

$rbBlobContainer = New-Object System.Windows.Forms.RadioButton
$rbBlobContainer.Location = New-Object System.Drawing.Point(210,20)
$rbBlobContainer.Size = New-Object System.Drawing.Size(100,20)
$rbBlobContainer.Text = "Blob Container"
$form.Controls.Add($rbBlobContainer)

# Keywords Label and TextBox
$lblKeywords = New-Object System.Windows.Forms.Label
$lblKeywords.Location = New-Object System.Drawing.Point(10,50)
$lblKeywords.Size = New-Object System.Drawing.Size(100,20)
$lblKeywords.Text = "Keywords:"
$form.Controls.Add($lblKeywords)

$txtKeywords = New-Object System.Windows.Forms.TextBox
$txtKeywords.Location = New-Object System.Drawing.Point(120,50)
$txtKeywords.Size = New-Object System.Drawing.Size(300,20)
$form.Controls.Add($txtKeywords)

# Date Range Label and Controls
$lblDateRange = New-Object System.Windows.Forms.Label
$lblDateRange.Location = New-Object System.Drawing.Point(10,80)
$lblDateRange.Size = New-Object System.Drawing.Size(100,20)
$lblDateRange.Text = "Date Range:"
$form.Controls.Add($lblDateRange)

$dtpStart = New-Object System.Windows.Forms.DateTimePicker
$dtpStart.Location = New-Object System.Drawing.Point(120,80)
$dtpStart.Size = New-Object System.Drawing.Size(140,20)
$form.Controls.Add($dtpStart)

$lblTo = New-Object System.Windows.Forms.Label
$lblTo.Location = New-Object System.Drawing.Point(270,80)
$lblTo.Size = New-Object System.Drawing.Size(30,20)
$lblTo.Text = "to"
$form.Controls.Add($lblTo)

$dtpEnd = New-Object System.Windows.Forms.DateTimePicker
$dtpEnd.Location = New-Object System.Drawing.Point(310,80)
$dtpEnd.Size = New-Object System.Drawing.Size(140,20)
$form.Controls.Add($dtpEnd)

$chkAllDates = New-Object System.Windows.Forms.CheckBox
$chkAllDates.Location = New-Object System.Drawing.Point(460,80)
$chkAllDates.Size = New-Object System.Drawing.Size(100,20)
$chkAllDates.Text = "All Dates"
$form.Controls.Add($chkAllDates)

# Load CSV Button
$btnLoadCSV = New-Object System.Windows.Forms.Button
$btnLoadCSV.Location = New-Object System.Drawing.Point(10,110)
$btnLoadCSV.Size = New-Object System.Drawing.Size(100,20)
$btnLoadCSV.Text = "Load CSV"
$form.Controls.Add($btnLoadCSV)

# ComboBox for Account Selection
$lblAccountSelection = New-Object System.Windows.Forms.Label
$lblAccountSelection.Location = New-Object System.Drawing.Point(120,110)
$lblAccountSelection.Size = New-Object System.Drawing.Size(100,20)
$lblAccountSelection.Text = "Select Account:"
$form.Controls.Add($lblAccountSelection)

$cmbAccounts = New-Object System.Windows.Forms.ComboBox
$cmbAccounts.Location = New-Object System.Drawing.Point(220,110)
$cmbAccounts.Size = New-Object System.Drawing.Size(300,20)
$form.Controls.Add($cmbAccounts)

# Storage Account Name (Editable)
$lblStorageAccount = New-Object System.Windows.Forms.Label
$lblStorageAccount.Location = New-Object System.Drawing.Point(10,140)
$lblStorageAccount.Size = New-Object System.Drawing.Size(100,20)
$lblStorageAccount.Text = "Storage Account:"
$form.Controls.Add($lblStorageAccount)

$txtStorageAccount = New-Object System.Windows.Forms.TextBox
$txtStorageAccount.Location = New-Object System.Drawing.Point(120,140)
$txtStorageAccount.Size = New-Object System.Drawing.Size(300,20)
# Removed ReadOnly
$form.Controls.Add($txtStorageAccount)

# SAS Token (Editable)
$lblSASToken = New-Object System.Windows.Forms.Label
$lblSASToken.Location = New-Object System.Drawing.Point(10,170)
$lblSASToken.Size = New-Object System.Drawing.Size(100,20)
$lblSASToken.Text = "SAS Token:"
$form.Controls.Add($lblSASToken)

$txtSASToken = New-Object System.Windows.Forms.TextBox
$txtSASToken.Location = New-Object System.Drawing.Point(120,170)
$txtSASToken.Size = New-Object System.Drawing.Size(300,20)
$txtSASToken.UseSystemPasswordChar = $true
# Removed ReadOnly
$form.Controls.Add($txtSASToken)

# Share or Container Name (Editable)
$lblShareOrContainer = New-Object System.Windows.Forms.Label
$lblShareOrContainer.Location = New-Object System.Drawing.Point(10,200)
$lblShareOrContainer.Size = New-Object System.Drawing.Size(100,20)
$lblShareOrContainer.Text = "Share/Container:"
$form.Controls.Add($lblShareOrContainer)

$txtShareOrContainer = New-Object System.Windows.Forms.TextBox
$txtShareOrContainer.Location = New-Object System.Drawing.Point(120,200)
$txtShareOrContainer.Size = New-Object System.Drawing.Size(300,20)
# Removed ReadOnly
$form.Controls.Add($txtShareOrContainer)

# Directory or Blob Prefix Path
$lblDirectory = New-Object System.Windows.Forms.Label
$lblDirectory.Location = New-Object System.Drawing.Point(10,230)
$lblDirectory.Size = New-Object System.Drawing.Size(100,20)
$lblDirectory.Text = "Directory/Prefix:"
$form.Controls.Add($lblDirectory)

$txtDirectory = New-Object System.Windows.Forms.TextBox
$txtDirectory.Location = New-Object System.Drawing.Point(120,230)
$txtDirectory.Size = New-Object System.Drawing.Size(300,20)
$txtDirectory.Text = ""
$form.Controls.Add($txtDirectory)

# Include Subdirectories Checkbox
$chkRecurse = New-Object System.Windows.Forms.CheckBox
$chkRecurse.Location = New-Object System.Drawing.Point(430,230)
$chkRecurse.Size = New-Object System.Drawing.Size(150,20)
$chkRecurse.Text = "Include Subdirectories"
$form.Controls.Add($chkRecurse)

# Search Button
$btnSearch = New-Object System.Windows.Forms.Button
$btnSearch.Location = New-Object System.Drawing.Point(690,20)
$btnSearch.Size = New-Object System.Drawing.Size(80,80)
$btnSearch.Text = "Search"
$form.Controls.Add($btnSearch)

# Help Button
$btnHelp = New-Object System.Windows.Forms.Button
$btnHelp.Location = New-Object System.Drawing.Point(690,110)
$btnHelp.Size = New-Object System.Drawing.Size(80,80)
$btnHelp.Text = "Help"
$form.Controls.Add($btnHelp)

# ListView for Results
$lstResults = New-Object System.Windows.Forms.ListView
$lstResults.Location = New-Object System.Drawing.Point(10,270)
$lstResults.Size = New-Object System.Drawing.Size(760,380)
$lstResults.View = [System.Windows.Forms.View]::Details
$lstResults.FullRowSelect = $true
$lstResults.Columns.Add("File/Blob Name", 200)
$lstResults.Columns.Add("Creation Time", 150)
$lstResults.Columns.Add("Last Modified", 150)
$lstResults.Columns.Add("Path", 240)
$form.Controls.Add($lstResults)

# Save to CSV Button
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Location = New-Object System.Drawing.Point(10,700)
$btnSave.Size = New-Object System.Drawing.Size(100,30)
$btnSave.Text = "Save to CSV"
$form.Controls.Add($btnSave)

# View Log Button
$btnViewLog = New-Object System.Windows.Forms.Button
$btnViewLog.Location = New-Object System.Drawing.Point(120,700)
$btnViewLog.Size = New-Object System.Drawing.Size(100,30)
$btnViewLog.Text = "View Log"
$form.Controls.Add($btnViewLog)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,650)
$progressBar.Size = New-Object System.Drawing.Size(760,20)
$form.Controls.Add($progressBar)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10,675)
$statusLabel.Size = New-Object System.Drawing.Size(760,20)
$statusLabel.Text = "Ready"
$form.Controls.Add($statusLabel)

# Global variable to store CSV data
$csvData = @()

# Enable logging to a file
$logFilePath = Join-Path -Path $env:TEMP -ChildPath "AzureStorageSearch.log"
$logStream = New-Object System.IO.StreamWriter($logFilePath, $true)
$logStream.AutoFlush = $true

# Function to log messages
function Log-Message {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logStream.WriteLine("$timestamp - $Message")
}

# Event handlers

# Load CSV Button Click Event
$btnLoadCSV.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
    $openFileDialog.Title = "Select CSV File"
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $csvData = Import-Csv -Path $openFileDialog.FileName
            # Log the loaded CSV data
            Log-Message "CSV Data Loaded: $($csvData | ConvertTo-Json -Depth 3)"
            $cmbAccounts.Items.Clear()
            $cmbAccounts.DisplayMember = "DisplayName" # Set the DisplayMember
            foreach ($entry in $csvData) {
                $displayName = "$($entry.StorageAccount) - $($entry.ShareOrContainer)"
                # Create a custom object with DisplayName and Data properties
                $item = New-Object PSObject -Property @{
                    DisplayName = $displayName
                    Data = $entry
                }
                $cmbAccounts.Items.Add($item)
            }
            if ($cmbAccounts.Items.Count -gt 0) {
                $cmbAccounts.SelectedIndex = 0
            }
            $statusLabel.Text = "CSV loaded successfully."
            Log-Message "CSV loaded successfully from $($openFileDialog.FileName)"
        } catch {
            $errorMsg = "Failed to load CSV file: $_"
            [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            Log-Message $errorMsg
        }
    }
})

# ComboBox Selection Changed Event
$cmbAccounts.Add_SelectedIndexChanged({
    $selectedItem = $cmbAccounts.SelectedItem
    Log-Message "ComboBox SelectedIndexChanged event fired. SelectedItem: $($selectedItem.DisplayName)"
    if ($selectedItem -ne $null) {
        $selectedEntry = $selectedItem.Data
        Log-Message "SelectedEntry: $($selectedEntry | ConvertTo-Json -Depth 3)"
        $txtStorageAccount.Text = $selectedEntry.StorageAccount
        $txtShareOrContainer.Text = $selectedEntry.ShareOrContainer
        $txtSASToken.Text = $selectedEntry.SASToken
        Log-Message "Selected account: $($selectedEntry.StorageAccount), Share/Container: $($selectedEntry.ShareOrContainer)"
    }
})

# View Log Button Click Event
$btnViewLog.Add_Click({
    if (Test-Path $logFilePath) {
        Start-Process notepad.exe $logFilePath
    } else {
        [System.Windows.Forms.MessageBox]::Show("Log file not found.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Search Button Click Event
$btnSearch.Add_Click({
    try {
        # Clear previous results and reset progress
        $lstResults.Items.Clear()
        $progressBar.Value = 0
        $statusLabel.Text = "Preparing to search..."
        $form.Refresh()
        Log-Message "Search initiated."

        # Determine storage type
        if ($rbFileShare.Checked) {
            $storageType = "FileShare"
        } elseif ($rbBlobContainer.Checked) {
            $storageType = "BlobContainer"
        } else {
            $statusLabel.Text = "Please select a storage type."
            Log-Message "Search aborted: No storage type selected."
            return
        }

        # Get inputs from GUI
        $keywords = $txtKeywords.Text -split ',' | ForEach-Object { $_.Trim() }
        $startDate = $dtpStart.Value.Date
        $endDate = $dtpEnd.Value.Date.AddDays(1).AddSeconds(-1)
        $useAllDates = $chkAllDates.Checked
        $recurse = $chkRecurse.Checked

        $storageAccountName = $txtStorageAccount.Text
        $sasToken = $txtSASToken.Text
        $shareOrContainerName = $txtShareOrContainer.Text
        $directoryPath = $txtDirectory.Text

        if (-not $storageAccountName -or -not $sasToken -or -not $shareOrContainerName) {
            $statusLabel.Text = "Please provide Storage Account, SAS Token, and Share/Container."
            Log-Message "Search aborted: Missing storage account details."
            return
        }

        Log-Message "Creating storage context for account: $storageAccountName"

        # Create storage context using SAS Token
        try {
            $ctx = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken -Protocol Https -ErrorAction Stop
            Log-Message "Storage context created successfully."

            # Log the endpoint being used
            if ($storageType -eq "FileShare") {
                Log-Message "Using endpoint: $($ctx.FileEndPoint)"
            } elseif ($storageType -eq "BlobContainer") {
                Log-Message "Using endpoint: $($ctx.BlobEndPoint)"
            }
        } catch {
            $errorDetails = $_.Exception.Message
            Log-Message "Exception details: $errorDetails"

            if ($errorDetails -match "AuthorizationFailure" -or $errorDetails -match "403" -or $errorDetails -match "AuthenticationFailed") {
                $errorMsg = "Failed to create storage context due to authorization failure. Check your SAS token permissions."
            } else {
                $errorMsg = "Failed to create storage context: $errorDetails"
            }
            $statusLabel.Text = $errorMsg
            Log-Message $errorMsg
            return
        }

        # Configure the ListView control
        $lstResults.View = [System.Windows.Forms.View]::Details
        $lstResults.Columns.Clear()
        $lstResults.Columns.Add("Name", 250) | Out-Null
        $lstResults.Columns.Add("Creation Time", 150) | Out-Null
        $lstResults.Columns.Add("Last Modified", 150) | Out-Null
        $lstResults.Columns.Add("URI", 300) | Out-Null

        if ($storageType -eq "BlobContainer") {
            # Call function to search blob containers
            Log-Message "Starting search in Azure Blob Container."

            # Function to list blobs
            function Get-AzureBlobs {
                param(
                    $Context,
                    [string]$ContainerName,
                    [string]$Prefix
                )
                $results = @()
                try {
                    $statusLabel.Text = "Retrieving blobs with prefix: $Prefix"
                    $form.Refresh()
                    Log-Message "Retrieving blobs with prefix: $Prefix"

                    $blobList = Get-AzStorageBlob -Context $Context -Container $ContainerName -Prefix $Prefix -ErrorAction Stop
                    Log-Message "Retrieved $($blobList.Count) blobs with prefix: $Prefix"
                } catch {
                    $errorDetails = $_.Exception.Message
                    Log-Message "Exception details: $errorDetails"

                    if ($errorDetails -match "AuthorizationFailure" -or $errorDetails -match "403" -or $errorDetails -match "AuthenticationFailed") {
                        $errorMsg = "Access denied when listing blobs with prefix: $Prefix. Check your SAS token permissions."
                    } else {
                        $errorMsg = "Error retrieving blobs with prefix: $Prefix. Error: $errorDetails"
                    }
                    $statusLabel.Text = $errorMsg
                    Log-Message $errorMsg
                    return $results
                }

                foreach ($blob in $blobList) {
                    Log-Message "Processing blob: $($blob.Name)"
                    $results += $blob
                }
                return $results
            }

            # Get blobs
            $statusLabel.Text = "Retrieving blobs from Azure Blob Container..."
            $form.Refresh()
            Log-Message "Retrieving blobs from container: $shareOrContainerName, prefix: $directoryPath"
            try {
                $blobs = Get-AzureBlobs -Context $ctx -ContainerName $shareOrContainerName -Prefix $directoryPath
                Log-Message "Total blobs retrieved: $($blobs.Count)"
            } catch {
                $errorDetails = $_.Exception.Message
                Log-Message "Exception details: $errorDetails"

                if ($errorDetails -match "AuthorizationFailure" -or $errorDetails -match "403" -or $errorDetails -match "AuthenticationFailed") {
                    $errorMsg = "Access denied when retrieving blobs. Check your SAS token permissions."
                } else {
                    $errorMsg = "Error retrieving blobs: $errorDetails"
                }
                $statusLabel.Text = $errorMsg
                Log-Message $errorMsg
                return
            }

            if ($blobs.Count -eq 0) {
                $statusLabel.Text = "No blobs found with the specified prefix."
                Log-Message "No blobs found with the specified prefix."
                return
            }

            $totalBlobs = $blobs.Count
            $processedBlobs = 0

            foreach ($blob in $blobs) {
                $processedBlobs++
                $progressBar.Value = [Math]::Round(($processedBlobs / $totalBlobs) * 100)
                $statusLabel.Text = "Processing blob ${processedBlobs} of ${totalBlobs}: $($blob.Name)"
                $form.Refresh()

                # Get blob properties
                try {
                    $lastModified = $blob.LastModified
                    $creationTime = $null

                    if ($blob.Properties -and $blob.Properties.CreationTime) {
                        $creationTime = $blob.Properties.CreationTime
                    }

                    # If CreationTime is null, use LastModified
                    if (-not $creationTime) {
                        $creationTime = $lastModified
                    }

                    # Ensure $creationTime and $lastModified are not null
                    if (-not $creationTime) {
                        $creationTimeString = "N/A"
                    } else {
                        $creationTimeString = $creationTime.ToString("yyyy-MM-dd HH:mm")
                    }

                    if (-not $lastModified) {
                        $lastModifiedString = "N/A"
                    } else {
                        $lastModifiedString = $lastModified.ToString("yyyy-MM-dd HH:mm")
                    }
                } catch {
                    $errorDetails = $_.Exception.Message
                    Log-Message "Exception details: $errorDetails"
                    $errorMsg = "Failed to get properties for blob: $($blob.Name). Error: $errorDetails"
                    Log-Message $errorMsg
                    continue
                }

                # Check date range
                if (-not $useAllDates -and ($lastModified -lt $startDate -or $lastModified -gt $endDate)) {
                    continue
                }

                # Check if blob name matches keywords
                $matchFound = $false
                if ($keywords.Count -eq 0 -or ($keywords.Count -eq 1 -and $keywords[0] -eq "")) {
                    $matchFound = $true
                } else {
                    foreach ($keyword in $keywords) {
                        # Add wildcards to the keyword if it doesn't contain any
                        if ($keyword -notmatch '[\*\?]') {
                            $pattern = "*$keyword*"
                        } else {
                            $pattern = $keyword
                        }
                        if ($blob.Name -like $pattern) {
                            $matchFound = $true
                            break
                        }
                    }
                }

                if ($matchFound) {
                    try {
                        # Prepare values for ListViewItem
                        $uriString = if ($blob.Uri -ne $null) { $blob.Uri.AbsoluteUri } else { "N/A" }

                        # Create the ListViewItem and add subitems
                        $item = New-Object System.Windows.Forms.ListViewItem($blob.Name)

                        # Add subitems individually
                        $item.SubItems.Add($creationTimeString) | Out-Null
                        $item.SubItems.Add($lastModifiedString) | Out-Null
                        $item.SubItems.Add($uriString) | Out-Null

                        # Add the item to the ListView
                        $lstResults.Items.Add($item) | Out-Null
                        Log-Message "Blob matched: $($blob.Name)"
                    } catch {
                        $errorDetails = $_.Exception.ToString()
                        Log-Message "Exception adding item to ListView: $errorDetails"
                        continue
                    }
                }
            }

            $statusLabel.Text = "Search completed. Found $($lstResults.Items.Count) results."
            $progressBar.Value = 100
            Log-Message "Search completed. Found $($lstResults.Items.Count) results."

        } elseif ($storageType -eq "FileShare") {
            # Call function to search file shares
            Log-Message "Starting search in Azure File Share."

            # Function to recursively get files
            function Get-AzureFilesRecursive {
                param(
                    $Context,
                    [string]$ShareName,
                    [string]$Path,
                    [bool]$Recurse
                )
                $results = @()
                try {
                    # If Path is root, set to empty string
                    if ($Path -eq "/" -or $Path -eq "\") {
                        $Path = ""
                    }
                    $statusLabel.Text = "Retrieving files from path: $Path"
                    $form.Refresh()
                    Log-Message "Retrieving files from path: $Path"
                    $items = Get-AzStorageFile -Context $Context -ShareName $ShareName -Path $Path -ErrorAction Stop
                    Log-Message "Retrieved $($items.Count) items from path: $Path"
                } catch {
                    $errorDetails = $_.Exception.Message
                    Log-Message "Exception details: $errorDetails"

                    if ($errorDetails -match "AuthorizationFailure" -or $errorDetails -match "403" -or $errorDetails -match "AuthenticationFailed") {
                        $errorMsg = "Access denied when listing files at path: $Path. Check your SAS token permissions."
                    } else {
                        $errorMsg = "Error retrieving items from path: $Path. Error: $errorDetails"
                    }
                    $statusLabel.Text = $errorMsg
                    Log-Message $errorMsg
                    return $results
                }

                foreach ($item in $items) {
                    Log-Message "Processing item: $($item.Name) in path: $Path"
                    if ($item.IsDirectory) {
                        # It's a directory
                        if ($Recurse) {
                            $subDirPath = [System.IO.Path]::Combine($Path, $item.Name)
                            $results += Get-AzureFilesRecursive -Context $Context -ShareName $ShareName -Path $subDirPath -Recurse $Recurse
                        }
                    } else {
                        # It's a file
                        $fullPath = [System.IO.Path]::Combine($Path, $item.Name)
                        $item | Add-Member -NotePropertyName 'FullPath' -NotePropertyValue $fullPath -Force
                        $results += $item
                    }
                }
                return $results
            }

            # Get files
            $statusLabel.Text = "Retrieving files from Azure File Share..."
            $form.Refresh()
            Log-Message "Retrieving files from share: $shareOrContainerName, path: $directoryPath"
            try {
                $files = Get-AzureFilesRecursive -Context $ctx -ShareName $shareOrContainerName -Path $directoryPath -Recurse $recurse
                Log-Message "Total files retrieved: $($files.Count)"
            } catch {
                $errorDetails = $_.Exception.Message
                Log-Message "Exception details: $errorDetails"

                if ($errorDetails -match "AuthorizationFailure" -or $errorDetails -match "403" -or $errorDetails -match "AuthenticationFailed") {
                    $errorMsg = "Access denied when retrieving files. Check your SAS token permissions."
                } else {
                    $errorMsg = "Error retrieving files: $errorDetails"
                }
                $statusLabel.Text = $errorMsg
                Log-Message $errorMsg
                return
            }

            if ($files.Count -eq 0) {
                $statusLabel.Text = "No files found in the specified directory."
                Log-Message "No files found in the specified directory."
                return
            }

            $totalFiles = $files.Count
            $processedFiles = 0

            foreach ($file in $files) {
                $processedFiles++
                $progressBar.Value = [Math]::Round(($processedFiles / $totalFiles) * 100)
                $statusLabel.Text = "Processing file ${processedFiles} of ${totalFiles}: $($file.Name)"
                $form.Refresh()

                # Get file properties
                try {
                    $lastModified = $file.LastModified
                    $creationTime = $file.CreationTime

                    # If CreationTime is null, use LastModified
                    if (-not $creationTime) {
                        $creationTime = $lastModified
                    }

                    # Ensure $creationTime and $lastModified are not null
                    if (-not $creationTime) {
                        $creationTimeString = "N/A"
                    } else {
                        $creationTimeString = $creationTime.ToString("yyyy-MM-dd HH:mm")
                    }

                    if (-not $lastModified) {
                        $lastModifiedString = "N/A"
                    } else {
                        $lastModifiedString = $lastModified.ToString("yyyy-MM-dd HH:mm")
                    }
                } catch {
                    $errorDetails = $_.Exception.Message
                    Log-Message "Exception details: $errorDetails"
                    $errorMsg = "Failed to get properties for file: $($file.Name). Error: $errorDetails"
                    Log-Message $errorMsg
                    continue
                }

                # Check date range
                if (-not $useAllDates -and ($lastModified -lt $startDate -or $lastModified -gt $endDate)) {
                    continue
                }

                # Check if file name matches keywords
                $matchFound = $false
                if ($keywords.Count -eq 0 -or ($keywords.Count -eq 1 -and $keywords[0] -eq "")) {
                    $matchFound = $true
                } else {
                    foreach ($keyword in $keywords) {
                        # Add wildcards to the keyword if it doesn't contain any
                        if ($keyword -notmatch '[\*\?]') {
                            $pattern = "*$keyword*"
                        } else {
                            $pattern = $keyword
                        }
                        if ($file.Name -like $pattern) {
                            $matchFound = $true
                            break
                        }
                    }
                }

                if ($matchFound) {
                    try {
                        # Prepare values for ListViewItem
                        $uriString = if ($file.Context -ne $null) { $file.CloudFile.Uri.AbsoluteUri } else { "N/A" }

                        # Create the ListViewItem and add subitems
                        $item = New-Object System.Windows.Forms.ListViewItem($file.Name)
                        $item.SubItems.Add($creationTimeString) | Out-Null
                        $item.SubItems.Add($lastModifiedString) | Out-Null
                        $item.SubItems.Add($file.FullPath) | Out-Null

                        # Add the item to the ListView
                        $lstResults.Items.Add($item) | Out-Null
                        Log-Message "File matched: $($file.FullPath)"
                    } catch {
                        $errorDetails = $_.Exception.ToString()
                        Log-Message "Exception adding item to ListView: $errorDetails"
                        continue
                    }
                }
            }

            $statusLabel.Text = "Search completed. Found $($lstResults.Items.Count) results."
            $progressBar.Value = 100
            Log-Message "Search completed. Found $($lstResults.Items.Count) results."
        }
    } catch {
        $errorDetails = $_.Exception.ToString()
        Log-Message "Exception details: $errorDetails"
        $errorMsg = "An unexpected error occurred: $errorDetails"
        $statusLabel.Text = $errorMsg
        Log-Message $errorMsg
    }
})

# Save Button Click Event
$btnSave.Add_Click({
    try {
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "CSV Files (*.csv)|*.csv"
        $saveFileDialog.Title = "Save Results"
        $saveFileDialog.ShowDialog()

        if ($saveFileDialog.FileName -ne "") {
            $results = @()
            foreach ($item in $lstResults.Items) {
                $results += [PSCustomObject]@{
                    Name = $item.Text
                    CreationTime = $item.SubItems[1].Text
                    LastModified = $item.SubItems[2].Text
                    Path = $item.SubItems[3].Text
                }
            }
            $results | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8
            Log-Message "Results saved to CSV: $($saveFileDialog.FileName)"
        }
    } catch {
        $errorMsg = "Failed to save results to CSV: $_"
        [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Log-Message $errorMsg
    }
})

# Help Button Click Event
$btnHelp.Add_Click({
    $helpMessage = @"
Azure Storage Search Tool - Help

Overview:
This tool allows you to search for files within Azure File Shares and blobs within Azure Blob Containers based on keywords (with wildcard support), date ranges, and directory or prefix paths.

Steps to Use the Tool:

1. Select Storage Type:
   - Choose either 'File Share' or 'Blob Container' to specify the type of storage you want to search.

2. Load CSV File:
   - Click the 'Load CSV' button to select a CSV file containing your storage account details.
   - The CSV file should have the following headers:
     - `StorageAccount`: Name of your storage account.
     - `ShareOrContainer`: Name of the file share or blob container.
     - `SASToken`: A valid SAS token with 'Read' and 'List' permissions.

3. Select Account:
   - Choose an account from the drop-down list. The storage account, share/container, and SAS token fields will populate automatically.

4. Set Search Parameters:
   - Keywords: Enter keywords to search for in file/blob names.
     - If you enter a keyword without wildcards, the tool will search for files containing that keyword anywhere in the name.
     - You can also use wildcard patterns for more precise control.
     - Wildcards:
       - `*` matches any number of characters.
       - `?` matches any single character.
     - Examples:
       - `1` finds files containing '1' (e.g., '1.txt', 'file1.doc').
       - `*.txt` finds all text files.
       - `Report*` finds files starting with 'Report'.
     - Separate multiple keywords with commas.

   - Date Range: Specify the start and end dates, or check 'All Dates' to include all files/blobs.
   - Directory/Prefix: Enter the directory path (for file shares) or blob prefix (for containers) where the search should begin. Leave blank for the root.
   - Include Subdirectories: Check this box if you want to search within all subdirectories or prefixes.

5. Start Search:
   - Click the 'Search' button to begin the search.
   - The status label will display progress updates, and the progress bar will indicate the search progress.

6. View Results:
   - Matching files/blobs will be displayed in the results list with their name, creation time, last modified time, and path.

7. Save Results:
   - Click the 'Save to CSV' button to export the results to a CSV file.

8. View Log:
   - Click the 'View Log' button to open the log file, which contains detailed information about the script's execution.

Additional Information:

- SAS Token Permissions:
  - Ensure your SAS token includes 'Read' and 'List' permissions and is not expired.
  - The token should be valid for the duration you plan to use the tool.

- Date Range Selection:
  - If 'All Dates' is unchecked, only files/blobs modified within the specified date range will be included.

- Keywords and Wildcards:
  - Keywords are matched using wildcard patterns.
  - If you do not include wildcards, the tool will search for files containing the keyword anywhere in the name.
  - Use `*` and `?` for flexible matching.

- Security Considerations:
  - Handle your SAS tokens securely and avoid sharing them publicly.
  - Secure your CSV file as it contains sensitive access information.

- Troubleshooting:
  - If no files/blobs are found, verify your search parameters and ensure the SAS token has the necessary permissions.
  - Use the 'View Log' button to check for any error messages or issues.

Support:
If you encounter any issues or have questions, please refer to the documentation or contact your administrator.

"@

    [System.Windows.Forms.MessageBox]::Show($helpMessage, "Help - Azure Storage Search Tool", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Form Resize Event
$form.Add_Resize({
    $lstResults.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 20), ($form.ClientSize.Height - 320))
    $progressBar.Location = New-Object System.Drawing.Point(10, ($form.ClientSize.Height - 90))
    $progressBar.Width = $form.ClientSize.Width - 20
    $statusLabel.Location = New-Object System.Drawing.Point(10, ($form.ClientSize.Height - 65))
    $statusLabel.Width = $form.ClientSize.Width - 20
    $btnSave.Location = New-Object System.Drawing.Point(10, ($form.ClientSize.Height - 40))
    $btnViewLog.Location = New-Object System.Drawing.Point(120, ($form.ClientSize.Height - 40))
})

# Event when form is closed to dispose of the log stream
$form.Add_FormClosed({
    $logStream.Close()
})

# Show the form
$form.ShowDialog()
