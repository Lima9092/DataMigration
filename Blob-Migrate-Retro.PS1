# Minimize the PowerShell command prompt (optional)
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("kernel32.dll", ExactSpelling = true)]
        public static extern IntPtr GetConsoleWindow();
    }
"@
$consolePtr = [Win32]::GetConsoleWindow()
if ($consolePtr -ne [IntPtr]::Zero) {
    # 6 = Minimize the window
    [Win32]::ShowWindow($consolePtr, 6)
}

# Load required assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$global:csvPath = ".\Blob-Migrations-Retro.csv"       # CSV file path (ensure this file exists)
$global:masterSummaryPath = ".\Blob-Master-Summary.csv"  # Master summary CSV file path (if needed)
$global:currentRunSummaries = @()
$global:azCopyProcess = $null

# Function to execute the retrospective copy for a given migration
function Run-RetrospectiveCopy {
    param (
        [string]$siteId,
        [string]$storageAccount,
        [string]$AzureContainer,   # Source container (the original container)
        [string]$ActiveContainer,  # Destination container (active container)
        [string]$sasToken,
        [string]$tagName,
        [string]$tagValue
    )
    try {
        # Build source URL from the AzureContainer
        $sourceUrl = "https://$storageAccount.blob.core.windows.net/$AzureContainer`?$sasToken"
        # Build destination URL using the ActiveContainer (do not append siteId)
        $destinationUrl = "https://$storageAccount.blob.core.windows.net/$ActiveContainer`?$sasToken"

        $outputBox.AppendText("----------------------------------------------------" + [Environment]::NewLine)
        $outputBox.AppendText("Processing Site ID: $siteId" + [Environment]::NewLine)
        $outputBox.AppendText("Source:      $sourceUrl" + [Environment]::NewLine)
        $outputBox.AppendText("Destination: $destinationUrl" + [Environment]::NewLine)

        # Prepare a log folder for AzCopy logs
        $logFolder = Join-Path -Path $PSScriptRoot -ChildPath "Logs\$siteId\RetrospectiveLogs"
        if (-not (Test-Path $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        }
        $env:AZCOPY_LOG_LOCATION = $logFolder

        # Build the AzCopy command arguments
        $azCopyArgs = @(
            "cp",
            "`"$sourceUrl`"",
            "`"$destinationUrl`"",
            "--recursive",
            "--overwrite=ifSourceNewer",
            "--include-pattern=*.jpg;*.bmp",
            "--blob-tags=`"$tagName=$tagValue`"",
            "--log-level=INFO"
        )
        $outputBox.AppendText("Executing AzCopy command:" + [Environment]::NewLine)
        $outputBox.AppendText("azcopy $($azCopyArgs -join ' ')" + [Environment]::NewLine)

        $startTime = Get-Date
        $azCopyOutput = & azcopy $azCopyArgs 2>&1
        $endTime = Get-Date

        $outputBox.AppendText($azCopyOutput + [Environment]::NewLine)
        # Extract details from the output (if available)
        $jobId = ([regex]::Match($azCopyOutput, "Job ([a-f0-9-]+) has started")).Groups[1].Value
        $totalFiles = ([regex]::Match($azCopyOutput, "Number of File Transfers: (\d+)")).Groups[1].Value
        $totalTransfers = ([regex]::Match($azCopyOutput, "Total Number of Transfers: (\d+)")).Groups[1].Value
        $finalJobStatus = ([regex]::Match($azCopyOutput, "Final Job Status: (\w+)")).Groups[1].Value
        $duration = ($endTime - $startTime).TotalMinutes

        # Create a summary object for the retrospective copy
        $summary = [PSCustomObject]@{
            SiteID            = $siteId
            JobName           = "Retrospective Copy"
            JobId             = $jobId
            Source            = $AzureContainer
            Destination       = $ActiveContainer
            MigrationType     = "Retrospective Copy"
            StartDate         = $startTime.ToString("yyyy/MM/dd")
            StartTime         = $startTime.ToString("HH:mm:ss")
            EndDate           = $endTime.ToString("yyyy/MM/dd")
            EndTime           = $endTime.ToString("HH:mm:ss")
            "Duration (Mins)" = [math]::Round($duration, 4)
            TotalFiles        = $totalFiles
            TotalTransfers    = $totalTransfers
            FinalJobStatus    = $finalJobStatus
        }
        $global:currentRunSummaries += $summary
        $outputBox.AppendText("Retrospective copy completed for Site ID: $siteId" + [Environment]::NewLine)
    }
    catch {
        $errorMessage = "Error executing retrospective copy for Site ID: $siteId`nError: $_"
        $outputBox.AppendText($errorMessage + [Environment]::NewLine)
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Function for summarizing logs and saving CSV summary files
function Summarize-Logs {
    try {
        $outputBox.AppendText("Entering Summarize-Logs function." + [Environment]::NewLine)
        if ($global:currentRunSummaries.Count -eq 0) {
            $outputBox.AppendText("No retrospective copy operations found for the current run." + [Environment]::NewLine)
            return
        }
        $currentDateTime = Get-Date -Format "ddMMyy-HHmm"
        $logsFolder = Join-Path $PSScriptRoot "Logs"
        if (-not (Test-Path $logsFolder)) {
            New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
        }
        $summaryFileName = "Retrospective-Summary-$currentDateTime.csv"
        # Group summaries by Site ID and save per-site summaries
        $groupedSummaries = $global:currentRunSummaries | Group-Object -Property SiteID
        foreach ($group in $groupedSummaries) {
            $siteId = $group.Name
            $sitePath = Join-Path $logsFolder $siteId
            if (-not (Test-Path $sitePath)) {
                New-Item -ItemType Directory -Path $sitePath -Force | Out-Null
            }
            $summaryPath = Join-Path $sitePath $summaryFileName
            $group.Group | Export-Csv -Path $summaryPath -NoTypeInformation
            $outputBox.AppendText("Detailed summary for Site ID $siteId saved to $summaryPath" + [Environment]::NewLine)
        }
        # Append to a master summary CSV file in the root folder
        $masterSummaryPath = Join-Path $PSScriptRoot "Blob-Master-Summary.csv"
        if (-not (Test-Path $masterSummaryPath)) {
            $emptyMasterSummary = @"
SiteID,LogFileName,JobName,JobId,Source,Destination,MigrationType,StartDate,StartTime,EndDate,EndTime,Duration (Mins),TotalFiles,TotalTransfers,FinalJobStatus
"@
            $emptyMasterSummary | Out-File -FilePath $masterSummaryPath -Encoding UTF8
            $existingMasterSummary = @()
        }
        else {
            $existingMasterSummary = Import-Csv $masterSummaryPath
        }
        $newEntries = @()
        foreach ($summary in $global:currentRunSummaries) {
            $summaryWithLogFileName = [PSCustomObject]@{
                SiteID            = $summary.SiteID
                LogFileName       = $summaryFileName
                JobName           = $summary.JobName
                JobId             = $summary.JobId
                Source            = $summary.Source
                Destination       = $summary.Destination
                MigrationType     = $summary.MigrationType
                StartDate         = $summary.StartDate
                StartTime         = $summary.StartTime
                EndDate           = $summary.EndDate
                EndTime           = $summary.EndTime
                "Duration (Mins)" = $summary.'Duration (Mins)'
                TotalFiles        = $summary.TotalFiles
                TotalTransfers    = $summary.TotalTransfers
                FinalJobStatus    = $summary.FinalJobStatus
            }
            $jobKey = "$($summary.JobId)-$($summary.StartDate)-$($summary.StartTime)"
            if (-not ($existingMasterSummary | Where-Object { "$($_.JobId)-$($_.StartDate)-$($_.StartTime)" -eq $jobKey })) {
                $newEntries += $summaryWithLogFileName
            }
        }
        if ($newEntries.Count -gt 0) {
            $newEntries | Export-Csv -Path $masterSummaryPath -NoTypeInformation -Append
            $outputBox.AppendText("Appended $($newEntries.Count) new entries to master summary at $masterSummaryPath" + [Environment]::NewLine)
        }
        else {
            $outputBox.AppendText("No new entries to append to master summary." + [Environment]::NewLine)
        }
        $outputBox.AppendText("Exiting Summarize-Logs function." + [Environment]::NewLine)
    }
    catch {
        $errorMessage = "Error in Summarize-Logs: $_"
        $outputBox.AppendText($errorMessage + [Environment]::NewLine)
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Blob Migrations: Retrospective Copy"
$form.Size = New-Object System.Drawing.Size(640,620)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Create ListBox (with horizontal scrolling) to display migrations from CSV
$migrationListBox = New-Object System.Windows.Forms.ListBox
$migrationListBox.SelectionMode = "MultiExtended"
$migrationListBox.HorizontalScrollbar = $true
$migrationListBox.Location = New-Object System.Drawing.Point(20,20)
$migrationListBox.Size = New-Object System.Drawing.Size(580,150)
$form.Controls.Add($migrationListBox)

# Create labels and text boxes for Tag Name and Tag Value
$tagNameLabel = New-Object System.Windows.Forms.Label
$tagNameLabel.Text = "Tag Name:"
$tagNameLabel.Location = New-Object System.Drawing.Point(20,180)
$tagNameLabel.Size = New-Object System.Drawing.Size(100,20)
$form.Controls.Add($tagNameLabel)

$tagNameBox = New-Object System.Windows.Forms.TextBox
$tagNameBox.Text = "Meganexus"
$tagNameBox.Location = New-Object System.Drawing.Point(130,180)
$tagNameBox.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($tagNameBox)

$tagValueLabel = New-Object System.Windows.Forms.Label
$tagValueLabel.Text = "Tag Value:"
$tagValueLabel.Location = New-Object System.Drawing.Point(20,210)
$tagValueLabel.Size = New-Object System.Drawing.Size(100,20)
$form.Controls.Add($tagValueLabel)

$tagValueBox = New-Object System.Windows.Forms.TextBox
$tagValueBox.Text = "No"
$tagValueBox.Location = New-Object System.Drawing.Point(130,210)
$tagValueBox.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($tagValueBox)

# Create output log TextBox (multiline)
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.ReadOnly = $true
$outputBox.Size = New-Object System.Drawing.Size(580,200)
$outputBox.Location = New-Object System.Drawing.Point(20,240)
$form.Controls.Add($outputBox)

# Create buttons for Run, Run All, View Summary, Help, Exit, and Cancel
$retroButton = New-Object System.Windows.Forms.Button
$retroButton.Location = New-Object System.Drawing.Point(20,460)
$retroButton.Size = New-Object System.Drawing.Size(120,30)
$retroButton.Text = "Run"
$form.Controls.Add($retroButton)

$retroAllButton = New-Object System.Windows.Forms.Button
$retroAllButton.Location = New-Object System.Drawing.Point(150,460)
$retroAllButton.Size = New-Object System.Drawing.Size(120,30)
$retroAllButton.Text = "Run All"
$form.Controls.Add($retroAllButton)

$viewSummaryButton = New-Object System.Windows.Forms.Button
$viewSummaryButton.Location = New-Object System.Drawing.Point(280,460)
$viewSummaryButton.Size = New-Object System.Drawing.Size(120,30)
$viewSummaryButton.Text = "View Summary"
$form.Controls.Add($viewSummaryButton)

$helpButton = New-Object System.Windows.Forms.Button
$helpButton.Location = New-Object System.Drawing.Point(410,460)
$helpButton.Size = New-Object System.Drawing.Size(80,30)
$helpButton.Text = "Help"
$form.Controls.Add($helpButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(500,460)
$exitButton.Size = New-Object System.Drawing.Size(100,30)
$exitButton.Text = "Exit"
$form.Controls.Add($exitButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(20,500)
$cancelButton.Size = New-Object System.Drawing.Size(120,30)
$cancelButton.Text = "Cancel"
$cancelButton.Enabled = $false
$form.Controls.Add($cancelButton)

# Create a progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(150,500)
$progressBar.Size = New-Object System.Drawing.Size(450,30)
$form.Controls.Add($progressBar)

# Load CSV data and populate the ListBox
try {
    $migrations = Import-Csv $global:csvPath
    foreach ($migration in $migrations) {
        # Display a summary line using the new column names
        $item = "Site ID: $($migration.'Site ID'), AzureContainer: $($migration.AzureContainer), ActiveContainer: $($migration.ActiveContainer), Storage: $($migration.StorageAccount)"
        $migrationListBox.Items.Add($item)
    }
}
catch {
    [System.Windows.Forms.MessageBox]::Show("Error loading CSV file: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

# Check if master summary file exists; if not, create an empty one
if (-not (Test-Path $global:masterSummaryPath)) {
    try {
        $emptyMasterSummary = @"
SiteID,LogFileName,JobName,JobId,Source,Destination,MigrationType,StartDate,StartTime,EndDate,EndTime,Duration (Mins),TotalFiles,TotalTransfers,FinalJobStatus
"@
        $emptyMasterSummary | Out-File -FilePath $global:masterSummaryPath -Encoding UTF8
        $outputBox.AppendText("Created new master summary file at $global:masterSummaryPath" + [Environment]::NewLine)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error creating master summary file: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Event handler for the "Retrospective Copy" button (process selected migrations)
$retroButton.Add_Click({
    if ($migrationListBox.SelectedIndices.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one migration from the list.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    $cancelButton.Enabled = $true
    $global:currentRunSummaries = @()
    $progressBar.Value = 0
    # Set the progress bar maximum to the number of selected migrations
    $progressBar.Maximum = $migrationListBox.SelectedIndices.Count
    foreach ($index in $migrationListBox.SelectedIndices) {
        $selectedMigration = $migrations[$index]
        Run-RetrospectiveCopy -siteId $selectedMigration.'Site ID' `
            -storageAccount $selectedMigration.StorageAccount `
            -AzureContainer $selectedMigration.AzureContainer `
            -ActiveContainer $selectedMigration.ActiveContainer `
            -sasToken $selectedMigration.'SAS Token' `
            -tagName $tagNameBox.Text `
            -tagValue $tagValueBox.Text
        $progressBar.Value += 1
        [System.Windows.Forms.Application]::DoEvents()
    }
    $cancelButton.Enabled = $false
    Summarize-Logs
})

# Event handler for the "Run All" button (process all migrations)
$retroAllButton.Add_Click({
    $cancelButton.Enabled = $true
    $global:currentRunSummaries = @()
    $progressBar.Value = 0
    $progressBar.Maximum = $migrations.Count
    foreach ($migration in $migrations) {
        Run-RetrospectiveCopy -siteId $migration.'Site ID' `
            -storageAccount $migration.StorageAccount `
            -AzureContainer $migration.AzureContainer `
            -ActiveContainer $migration.ActiveContainer `
            -sasToken $migration.'SAS Token' `
            -tagName $tagNameBox.Text `
            -tagValue $tagValueBox.Text
        $progressBar.Value += 1
        [System.Windows.Forms.Application]::DoEvents()
    }
    $cancelButton.Enabled = $false
    Summarize-Logs
})

# Event handler for the "View Summary" button
$viewSummaryButton.Add_Click({
    $masterSummaryPath = Join-Path $PSScriptRoot "Blob-Master-Summary.csv"
    if (Test-Path $masterSummaryPath) {
        try {
            $csvData = Import-Csv $masterSummaryPath
            if ($csvData.Count -eq 0) { throw "The CSV file is empty." }
            $summaryForm = New-Object System.Windows.Forms.Form
            $summaryForm.Text = "Master Summary - Retrospective Copy"
            $summaryForm.Size = New-Object System.Drawing.Size(1000,600)
            $summaryForm.StartPosition = "CenterScreen"
            $dataGridView = New-Object System.Windows.Forms.DataGridView
            $dataGridView.Dock = "Fill"
            $dataGridView.ReadOnly = $true
            $dataGridView.AutoSizeColumnsMode = "Fill"
            $dataGridView.AutoGenerateColumns = $true
            $summaryForm.Controls.Add($dataGridView)
            $dataGridView.DataSource = [System.Collections.ArrayList]::new($csvData)
            $summaryForm.ShowDialog()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error displaying summary: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("Master summary file not found: $masterSummaryPath", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Help button shows a message box with instructions
$helpButton.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "CSV File Requirements:" + [Environment]::NewLine +
        "--------------------------" + [Environment]::NewLine +
        "The CSV file (default: Retro.csv) must be placed in the same folder as this script." + [Environment]::NewLine +
        "It should have the following columns:" + [Environment]::NewLine +
        "  - Site ID" + [Environment]::NewLine +
        "  - StorageAccount" + [Environment]::NewLine +
        "  - AzureContainer (the original container from which the data was copied)" + [Environment]::NewLine +
        "  - ActiveContainer (the destination container to copy files to)" + [Environment]::NewLine +
        "  - SAS Token" + [Environment]::NewLine + [Environment]::NewLine +
        "How to Use This GUI:" + [Environment]::NewLine +
        "--------------------------" + [Environment]::NewLine +
        "1. The list box displays available migrations from the CSV file." + [Environment]::NewLine +
        "2. Enter the desired Tag Name and Tag Value to apply to the retrospectively copied files." + [Environment]::NewLine +
        "3. Select one or more migrations and click 'Retrospective Copy' to process the selected records," + [Environment]::NewLine +
        "   or click 'Run All' to process every migration in the CSV." + [Environment]::NewLine +
        "4. The output log and progress bar will update as the operation proceeds." + [Environment]::NewLine +
        "5. Click 'View Summary' to see a summary of the operations." + [Environment]::NewLine +
        "6. Click 'Exit' to close the application.",
        "Help"
    )
})

# Exit button
$exitButton.Add_Click({ $form.Close() })

# Cancel button (attempts to kill the current AzCopy process)
$cancelButton.Add_Click({
    if ($global:azCopyProcess -ne $null -and -not $global:azCopyProcess.HasExited) {
        $global:azCopyProcess.Kill()
        $outputBox.AppendText("Operation cancelled by user." + [Environment]::NewLine)
    }
    $cancelButton.Enabled = $false
})

# Show the form
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
