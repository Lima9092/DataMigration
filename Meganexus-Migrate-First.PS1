# Minimize the PowerShell command prompt
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

# Meganexus Migration GUI: First Run
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$global:azCopyProcess = $null
$global:currentRunLogFiles = @()
$global:currentRunSummaries = @()
$global:csvPath = ".\Meganexus-Migrations.csv" # CSV file path
$global:masterSummaryPath = ".\Meganexus-Master-Summary.csv" # Master summary CSV file path

# Helper function to extract values from log content
function Get-LogValue {
    param (
        [string]$content,
        [string]$pattern,
        [string]$default = "N/A"
    )
    $match = [regex]::Match($content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $default
}

# Function to execute AzCopy for a given migration
function Run-AzCopy {
    param (
        $siteId,
        $name,
        $source,
        $storageAccount,
        $container,
        $sasToken,
        $tagName,
        $tagValue
    )
    
    try {
        $currentDateTime = Get-Date -Format "ddMMyy-HHmm"
        $destination = "https://$storageAccount.blob.core.windows.net/$container"
        $fullDestination = "$destination`?$sasToken"

        # Set AzCopy log location per SiteID
        $logFolder = Join-Path -Path $PSScriptRoot -ChildPath "Logs\$siteId\AZ-VerboseLogs"
        if (-not (Test-Path $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
        }
        $env:AZCOPY_LOG_LOCATION = $logFolder

        $azCopyArgs = @(
            "cp",
            "`"$source/*`"",
            "`"$fullDestination`"",
            "--recursive",
            "--blob-tags=`"$tagName=$tagValue`"",
            "--log-level=INFO"
        )
        $outputBox.AppendText("Executing AzCopy..." + [Environment]::NewLine)
        $outputBox.AppendText("azcopy $($azCopyArgs -join ' ')" + [Environment]::NewLine)

        $startTime = Get-Date
        $azCopyOutput = & azcopy $azCopyArgs 2>&1
        $endTime = Get-Date

        $outputBox.AppendText($azCopyOutput + [Environment]::NewLine)

        # Extract JobID from the output
        $jobId = [regex]::Match($azCopyOutput, "Job ([a-f0-9-]+) has started").Groups[1].Value

        # Calculate duration
        $duration = ($endTime - $startTime).TotalMinutes

        # Extract other information from the output
        $totalFiles = [regex]::Match($azCopyOutput, "Number of File Transfers: (\d+)").Groups[1].Value
        $totalTransfers = [regex]::Match($azCopyOutput, "Total Number of Transfers: (\d+)").Groups[1].Value
        $finalJobStatus = [regex]::Match($azCopyOutput, "Final Job Status: (\w+)").Groups[1].Value

        # Create a summary object
        $summary = [PSCustomObject]@{
            SiteID            = $siteId
            JobName           = $name
            JobId             = $jobId
            Source            = $source
            Destination       = $container
            MigrationType     = "First Run"
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

        $outputBox.AppendText("AzCopy job completed." + [Environment]::NewLine)
    }
    catch {
        $errorMessage = "Error executing AzCopy: $_"
        $outputBox.AppendText($errorMessage + [Environment]::NewLine)
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Function for logging
function Summarize-Logs {
    try {
        $outputBox.AppendText("Entering Summarize-Logs function." + [Environment]::NewLine)
        if ($global:currentRunSummaries.Count -eq 0) {
            $outputBox.AppendText("No AzCopy operations found for the current run." + [Environment]::NewLine)
            return
        }

        $currentDateTime = Get-Date -Format "ddMMyy-HHmm"
        $logsFolder = Join-Path $PSScriptRoot "Logs"
        if (-not (Test-Path $logsFolder)) {
            $outputBox.AppendText("Creating logs directory at: $logsFolder" + [Environment]::NewLine)
            New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
        }

        $summaryFileName = "AZ-Sync-Summary-$currentDateTime.csv"

        # Group summaries by Site ID
        $groupedSummaries = $global:currentRunSummaries | Group-Object -Property SiteID

        foreach ($group in $groupedSummaries) {
            $siteId = $group.Name
            $sitePath = Join-Path $logsFolder $siteId
            if (-not (Test-Path $sitePath)) {
                $outputBox.AppendText("Creating site directory at: $sitePath" + [Environment]::NewLine)
                New-Item -ItemType Directory -Path $sitePath -Force | Out-Null
            }
            $summaryPath = Join-Path $sitePath $summaryFileName
            $outputBox.AppendText("Saving site summary to: $summaryPath" + [Environment]::NewLine)
            $group.Group | Export-Csv -Path $summaryPath -NoTypeInformation
            $outputBox.AppendText("Detailed summary for Site ID $siteId saved to $summaryPath" + [Environment]::NewLine)
        }

        # Append to master summary CSV in the root folder
        $masterSummaryPath = Join-Path $PSScriptRoot "Meganexus-Master-Summary.csv"
        if (-not (Test-Path $masterSummaryPath)) {
            $outputBox.AppendText("Master summary file does not exist. Creating a new one." + [Environment]::NewLine)
            $emptyMasterSummary = @"
SiteID,LogFileName,JobName,JobId,Source,Destination,MigrationType,StartDate,StartTime,EndDate,EndTime,Duration (Mins),TotalFiles,TotalTransfers,FinalJobStatus
"@
            $emptyMasterSummary | Out-File -FilePath $masterSummaryPath -Encoding UTF8
            $existingMasterSummary = @()
        } else {
            $outputBox.AppendText("Master summary file exists at $masterSummaryPath" + [Environment]::NewLine)
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
            $outputBox.AppendText("Appending $($newEntries.Count) new entries to master summary." + [Environment]::NewLine)
            $newEntries | Export-Csv -Path $masterSummaryPath -NoTypeInformation -Append
            $outputBox.AppendText("$($newEntries.Count) new entries appended to $masterSummaryPath" + [Environment]::NewLine)
        } else {
            $outputBox.AppendText("No new entries to append to master summary." + [Environment]::NewLine)
        }

        # Display a brief summary in the output box
        foreach ($item in $global:currentRunSummaries) {
            $outputBox.AppendText("Site ID: $($item.SiteID)" + [Environment]::NewLine)
            $outputBox.AppendText("Job Name: $($item.JobName)" + [Environment]::NewLine)
            $outputBox.AppendText("  Job ID: $($item.JobId)" + [Environment]::NewLine)
            $outputBox.AppendText("  Source: $($item.Source)" + [Environment]::NewLine)
            $outputBox.AppendText("  Destination: $($item.Destination)" + [Environment]::NewLine)
            $outputBox.AppendText("  Migration Type: $($item.MigrationType)" + [Environment]::NewLine)
            $outputBox.AppendText("  Start: $($item.StartDate) $($item.StartTime)" + [Environment]::NewLine)
            $outputBox.AppendText("  End: $($item.EndDate) $($item.EndTime)" + [Environment]::NewLine)
            $outputBox.AppendText("  Duration (Mins): $($item.'Duration (Mins)')" + [Environment]::NewLine)
            $outputBox.AppendText("  Files: Total=$($item.TotalFiles), Transferred=$($item.TotalTransfers)" + [Environment]::NewLine)
            $outputBox.AppendText("  Final Job Status: $($item.FinalJobStatus)" + [Environment]::NewLine)
            $outputBox.AppendText([Environment]::NewLine)
            if ($item.ErrorMessages) {
                $outputBox.AppendText("Errors:" + [Environment]::NewLine)
                foreach ($error in $item.ErrorMessages) {
                    $outputBox.AppendText("  - $error" + [Environment]::NewLine)
                }
            }
            $outputBox.AppendText("========================================" + [Environment]::NewLine + [Environment]::NewLine)
            $outputBox.ScrollToCaret()
        }

        $outputBox.AppendText("Exiting Summarize-Logs function." + [Environment]::NewLine)
    } catch {
        $errorMessage = "Error in Summarize-Logs: $_"
        $outputBox.AppendText($errorMessage + [Environment]::NewLine)
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Create main form
$form = New-Object system.Windows.Forms.Form
$form.Text = "Meganexus Migration: First Run"
$form.Size = New-Object System.Drawing.Size(620,600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Create ListBox with vertical and horizontal scrolling
$migrationListBox = New-Object System.Windows.Forms.ListBox
$migrationListBox.SelectionMode = "MultiExtended"
$migrationListBox.HorizontalScrollbar = $true  # Enable horizontal scrolling
$migrationListBox.Location = New-Object System.Drawing.Point(20, 20)
$migrationListBox.Size = New-Object System.Drawing.Size(560, 150)
$form.Controls.Add($migrationListBox)

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

$scheduledStartCheckBox = New-Object System.Windows.Forms.CheckBox
$scheduledStartCheckBox.Text = "Scheduled Start"
$scheduledStartCheckBox.Location = New-Object System.Drawing.Point(350, 180) # Inline with Tag Name and Tag Value
$scheduledStartCheckBox.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($scheduledStartCheckBox)

$startTimeLabel = New-Object System.Windows.Forms.Label
$startTimeLabel.Text = "Start Time:"
$startTimeLabel.Location = New-Object System.Drawing.Point(350, 210) # Inline with Tag Name and Tag Value
$startTimeLabel.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($startTimeLabel)

$startTimeBox = New-Object System.Windows.Forms.TextBox
$startTimeBox.Text = "18:00"
$startTimeBox.Location = New-Object System.Drawing.Point(450, 210) # Next to the Start Time label
$startTimeBox.Size = New-Object System.Drawing.Size(100, 20)
$startTimeBox.Enabled = $false
$form.Controls.Add($startTimeBox)

$scheduledStartCheckBox.Add_CheckedChanged({
    $startTimeBox.Enabled = $scheduledStartCheckBox.Checked
})

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Size = New-Object System.Drawing.Size(560,200)
$outputBox.Location = New-Object System.Drawing.Point(20,240)
$outputBox.ReadOnly = $true
$form.Controls.Add($outputBox)

$runButton = New-Object System.Windows.Forms.Button
$runButton.Location = New-Object System.Drawing.Point(20,450)
$runButton.Size = New-Object System.Drawing.Size(100,30)
$runButton.Text = "Run"
$form.Controls.Add($runButton)

$runAllButton = New-Object System.Windows.Forms.Button
$runAllButton.Location = New-Object System.Drawing.Point(130,450)
$runAllButton.Size = New-Object System.Drawing.Size(100,30)
$runAllButton.Text = "Run All"
$form.Controls.Add($runAllButton)

$viewSummaryButton = New-Object System.Windows.Forms.Button
$viewSummaryButton.Location = New-Object System.Drawing.Point(240,450)
$viewSummaryButton.Size = New-Object System.Drawing.Size(100,30)
$viewSummaryButton.Text = "View Summary"
$form.Controls.Add($viewSummaryButton)

$helpButton = New-Object System.Windows.Forms.Button
$helpButton.Location = New-Object System.Drawing.Point(350,450)
$helpButton.Size = New-Object System.Drawing.Size(100,30)
$helpButton.Text = "Help"
$form.Controls.Add($helpButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(460,450)
$exitButton.Size = New-Object System.Drawing.Size(100,30)
$exitButton.Text = "Exit"
$form.Controls.Add($exitButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(20,490)
$cancelButton.Size = New-Object System.Drawing.Size(100,30)
$cancelButton.Text = "Cancel"
$cancelButton.Enabled = $false
$form.Controls.Add($cancelButton)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(130,490)
$progressBar.Size = New-Object System.Drawing.Size(450,30)
$form.Controls.Add($progressBar)

# Load CSV data
try {
    # Check for Meganexus-Migrations.csv
    $migrations = Import-Csv $global:csvPath
    foreach ($migration in $migrations) {
        $migrationListBox.Items.Add("Site ID: $($migration.'Site ID'), Name: $($migration.Name), Source: $($migration.Source), Destination: $($migration.Container)")
    }
}
catch {
    [System.Windows.Forms.MessageBox]::Show("Error loading CSV file: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

# Check if the master summary file exists; if not, create an empty one
if (-not (Test-Path $global:masterSummaryPath)) {
    try {
        # Create an empty master summary CSV file with the necessary headers
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

# Function to wait until the scheduled start time
function Wait-ForScheduledStart {
    param (
        [string]$scheduledTime
    )

    $currentDateTime = Get-Date
    $scheduledDateTime = [datetime]::ParseExact($scheduledTime, "HH:mm", $null)

    if ($scheduledDateTime -lt $currentDateTime) {
        # If the scheduled time is in the past for today, set it to tomorrow
        $scheduledDateTime = $scheduledDateTime.AddDays(1)
    }

    $waitTime = $scheduledDateTime - $currentDateTime

    if ($waitTime.TotalSeconds -gt 0) {
        $outputBox.AppendText("Waiting for scheduled start time: $scheduledTime" + [Environment]::NewLine)
        Start-Sleep -Seconds $waitTime.TotalSeconds
        $outputBox.AppendText("Scheduled start time reached: $scheduledTime" + [Environment]::NewLine)
    }
}

$runButton.Add_Click({
    if ($migrationListBox.SelectedIndices.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one migration from the list.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    if ($scheduledStartCheckBox.Checked) {
        Wait-ForScheduledStart -scheduledTime $startTimeBox.Text
    }

    $cancelButton.Enabled = $true
    $progressBar.Value = 0
    $progressBar.Maximum = $migrationListBox.SelectedIndices.Count
    $global:currentRunSummaries = @()

    foreach ($index in $migrationListBox.SelectedIndices) {
        $selectedMigration = $migrations[$index]
        Run-AzCopy -siteId $selectedMigration.'Site ID' -name $selectedMigration.Name -source $selectedMigration.Source -storageAccount $selectedMigration.StorageAccount -container $selectedMigration.Container -sasToken $selectedMigration.'SAS Token' -tagName $tagNameBox.Text -tagValue $tagValueBox.Text
        $progressBar.Value += 1
        [System.Windows.Forms.Application]::DoEvents()
    }

    $cancelButton.Enabled = $false
    Summarize-Logs
})

$runAllButton.Add_Click({
    if ($scheduledStartCheckBox.Checked) {
        Wait-ForScheduledStart -scheduledTime $startTimeBox.Text
    }

    $cancelButton.Enabled = $true
    $progressBar.Value = 0
    $progressBar.Maximum = $migrations.Count
    $global:currentRunSummaries = @()

    foreach ($migration in $migrations) {
        Run-AzCopy -siteId $migration.'Site ID' -name $migration.Name -source $migration.Source -storageAccount $migration.StorageAccount -container $migration.Container -sasToken $migration.'SAS Token' -tagName $tagNameBox.Text -tagValue $tagValueBox.Text
        $progressBar.Value += 1
        [System.Windows.Forms.Application]::DoEvents()
    }

    $cancelButton.Enabled = $false
    Summarize-Logs
})

$viewSummaryButton.Add_Click({
    $masterSummaryPath = Join-Path $PSScriptRoot "Meganexus-Master-Summary.csv"
    if (Test-Path $masterSummaryPath) {
        try {
            # Read the CSV file
            $csvData = Import-Csv $masterSummaryPath
            
            if ($csvData.Count -eq 0) {
                throw "The CSV file is empty."
            }

            # Create a new form for displaying the summary
            $summaryForm = New-Object System.Windows.Forms.Form
            $summaryForm.Text = "Meganexus Master Summary"
            $summaryForm.Size = New-Object System.Drawing.Size(1000,600)
            $summaryForm.StartPosition = "CenterScreen"

            # Create a DataGridView to display the summary content
            $dataGridView = New-Object System.Windows.Forms.DataGridView
            $dataGridView.Dock = "Fill"
            $dataGridView.AllowUserToAddRows = $false
            $dataGridView.AllowUserToDeleteRows = $false
            $dataGridView.ReadOnly = $true
            $dataGridView.AutoSizeColumnsMode = "Fill"
            $dataGridView.ColumnHeadersHeightSizeMode = "AutoSize"
            $dataGridView.AutoGenerateColumns = $true

            # Add the DataGridView to the form
            $summaryForm.Controls.Add($dataGridView)

            # Attempt to set the DataSource
            $dataGridView.DataSource = [System.Collections.ArrayList]::new($csvData)

            # If DataSource method doesn't work, manually add columns and rows
            if ($dataGridView.Rows.Count -eq 0) {
                # Add columns
                foreach ($property in $csvData[0].PSObject.Properties) {
                    $dataGridView.Columns.Add($property.Name, $property.Name)
                }

                # Add rows
                foreach ($row in $csvData) {
                    $dataGridView.Rows.Add($row.PSObject.Properties.Value)
                }
            }

            # Show row count for debugging
            $rowCountLabel = New-Object System.Windows.Forms.Label
            $rowCountLabel.Text = "Rows: $($dataGridView.Rows.Count)"
            $rowCountLabel.Dock = "Top"
            $summaryForm.Controls.Add($rowCountLabel)

            # Show the form
            $summaryForm.ShowDialog()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error loading or displaying CSV data: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("Master summary file not found: $masterSummaryPath", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$helpButton.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "CSV File Requirements:" + [Environment]::NewLine +
        "--------------------------" + [Environment]::NewLine +
        "The CSV file should be named 'Meganexus-Migrations.csv' and placed in the same directory as this script." + [Environment]::NewLine +
        "It should have the following columns:" + [Environment]::NewLine +
        "1. Site ID: The unique identifier for the site." + [Environment]::NewLine +
        "2. Name: A unique name for the migration." + [Environment]::NewLine +
        "3. Source: The source path of the file share." + [Environment]::NewLine +
        "4. StorageAccount: The name of the Azure Storage account." + [Environment]::NewLine +
        "5. Container: The name of the container in the Azure Storage account." + [Environment]::NewLine +
        "6. SAS Token: The Shared Access Signature (SAS) token for the container." + [Environment]::NewLine + [Environment]::NewLine +
        "How the GUI Works:" + [Environment]::NewLine +
        "--------------------------" + [Environment]::NewLine +
        "1. The list box displays all the available migrations from the CSV file." + [Environment]::NewLine +
        "2. Enter the Tag Name and Tag Value to be applied to the migrated files." + [Environment]::NewLine +
        "3. Select one or more migrations from the list and click 'Run' to start the migration(s)." + [Environment]::NewLine +
        "4. To run all migrations in sequence, click 'Run All'." + [Environment]::NewLine +
        "5. The log output will be displayed in the text box below the list." + [Environment]::NewLine +
        "6. Click 'View Summary' to see details of the completed migrations." + [Environment]::NewLine +
        "7. Use the 'Cancel' button to stop the current operation." + [Environment]::NewLine +
        "8. The progress bar shows the overall progress of the operation." + [Environment]::NewLine +
        "9. Click 'Exit' to close the application." + [Environment]::NewLine +
        "10. Verbose logs are saved in the 'Logs\<SiteID>\AZ-VerboseLogs' subfolder." + [Environment]::NewLine +
        "11. A summary log is created as 'AZ-FirstRun-[DateTime].csv' in the 'Logs' folder." + [Environment]::NewLine +
        "12. A master summary is maintained in 'Meganexus-Master-Summary.csv' in the script directory.",
        "Help"
    )
})

$exitButton.Add_Click({ $form.Close() })

$cancelButton.Add_Click({
    if ($global:azCopyProcess -ne $null -and -not $global:azCopyProcess.HasExited) {
        $global:azCopyProcess.Kill()
        $outputBox.AppendText("Operation cancelled by user." + [Environment]::NewLine)
    }
    $cancelButton.Enabled = $false
})

# Show the form
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
