# Improved Robocopy Migration GUI Script

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$global:robocopyProcess = $null
$global:logFiles = @()
$global:csvPath = ".\migrations.csv" # Adjust path as necessary

# Function to validate time format
function Is-ValidTimeFormat {
    param ($time)
    return $time -match '^\d{4}$' -and [int]$time.Substring(0,2) -in 0..23 -and [int]$time.Substring(2,2) -in 0..59
}

# Function to execute Robocopy for a given migration
function Run-Robocopy {
    param (
        $source,
        $destination,
        $startTime,
        $endTime
    )
    
    try {
        $currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $sourceFormatted = $source -replace "[:\\]", "-"
        $destinationFormatted = $destination -replace "[:\\]", "-"
        $logFile = "robocopy_${sourceFormatted}_${destinationFormatted}_${currentDateTime}.log"

        $robocopyArgs = "`"$source`" `"$destination`" /E /COPY:DAT /MIR /RH:$startTime-$endTime /DCOPY:DAT /R:10 /W:5 /V /LOG:`"$logFile`" /TEE"
        $outputBox.AppendText("Executing Robocopy..." + [Environment]::NewLine)
        $outputBox.AppendText("robocopy $robocopyArgs" + [Environment]::NewLine)

        $global:robocopyProcess = Start-Process robocopy -ArgumentList $robocopyArgs -NoNewWindow -PassThru

        $global:robocopyProcess.WaitForExit()

        $global:logFiles += $logFile
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error executing Robocopy: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Summarize-Logs {
    $summaries = @()
    foreach ($logFile in $global:logFiles) {
        if (Test-Path $logFile) {
            $logContent = Get-Content $logFile
            
            # Initialize variables
            $logFileName = [System.IO.Path]::GetFileName($logFile)
            $startDate = $startTime = $endDate = $endTime = $command = ""
            $duration = $null
            $totalFiles = $totalDirs = $totalBytes = 0
            $failed = $skipped = 0
            $errorMessages = @()
            $speedBytesPerSec = $speedMBps = $speedGBperHour = 0

            foreach ($line in $logContent) {
                # Extract start time and date
                if ($line -match "^  Started : (\d{2} \w+ \d{4}) (\d{2}:\d{2}:\d{2})") {
                    $startDate = $matches[1]
                    $startTime = $matches[2]
                }
                
                # Extract end time and date
                if ($line -match "^   Ended : (\d{2} \w+ \d{4}) (\d{2}:\d{2}:\d{2})") {
                    $endDate = $matches[1]
                    $endTime = $matches[2]
                }
                
                # Extract command used
                if ($line -match "^  Options : (.+)") {
                    $command = $matches[1]
                }
                
                # Extract total files copied and skipped
                if ($line -match "^\s*Files\s+:\s+\d+\s+(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+") {
                    $totalFiles = [int]$matches[1]
                    $skippedFiles = [int]$matches[2]
                }
                
                # Extract total directories copied and skipped
                if ($line -match "^\s*Dirs\s+:\s+\d+\s+(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+") {
                    $totalDirs = [int]$matches[1]
                    $skippedDirs = [int]$matches[2]
                }
                
                # Extract total bytes copied
                if ($line -match "^\s*Bytes\s+:\s+([\d.]+ [kKmMgG])\s+([\d.]+ [kKmMgG])\s+\d+\s+\d+\s+\d+\s+\d+") {
                    $totalBytes = $matches[2]
                    # Convert size to GB
                    if ($totalBytes -match "([\d.]+) ([kKmMgG])") {
                        $size = [decimal]$matches[1]
                        switch ($matches[2].ToUpper()) {
                            "K" { $totalBytes = $size / 1MB }
                            "M" { $totalBytes = $size / 1GB }
                            "G" { $totalBytes = $size }
                        }
                    }
                }
                
                # Extract error messages
                if ($line -match "^\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} ERROR \d+ \((0x[\da-fA-F]+)\) (.+)") {
                    $errorMessages += "$($matches[1]) $($matches[2])"
                }
                
                # Extract speed in Bytes/sec
                if ($line -match "^\s*Speed\s*:\s*([\d,]+) Bytes/sec") {
                    $speedBytesPerSec = [int]($matches[1] -replace ",", "")
                }
                
                # Extract total failed from the summary section
                if ($line -match "^\s*Dirs\s+:\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\d+") {
                    $failedDirs = [int]$matches[1]
                }
                if ($line -match "^\s*Files\s+:\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\d+") {
                    $failedFiles = [int]$matches[1]
                }
            }

            # Calculate total skipped and failed
            $skipped = $skippedFiles + $skippedDirs
            $failed = $failedDirs + $failedFiles

            # Calculate duration
            if ($startDate -ne "" -and $endDate -ne "" -and $startTime -ne "" -and $endTime -ne "") {
                $startDateTime = [datetime]::ParseExact("$startDate $startTime", "dd MMMM yyyy HH:mm:ss", $null)
                $endDateTime = [datetime]::ParseExact("$endDate $endTime", "dd MMMM yyyy HH:mm:ss", $null)
                $duration = ($endDateTime - $startDateTime).ToString("hh\:mm\:ss")
                
                # Calculate speeds if duration is available
                if ($speedBytesPerSec -gt 0) {
                    $speedMBps = [math]::Round($speedBytesPerSec * 8 / 1MB, 2)  # Convert Bytes/sec to Mbps
                    $totalDurationHours = ($endDateTime - $startDateTime).TotalHours
                    $speedGBperHour = [math]::Round($totalBytes / $totalDurationHours, 2)  # GB per hour
                }
            }

            # Create a summary object
            $summary = [PSCustomObject]@{
                LogFileName    = $logFileName
                Command        = $command
                StartDate      = $startDate
                StartTime      = $startTime
                EndDate        = $endDate
                EndTime        = $endTime
                Duration       = $duration
                TotalFiles     = $totalFiles
                TotalDirs      = $totalDirs
                TotalSizeGB    = [math]::Round($totalBytes, 2)
                Skipped        = $skipped
                Failed         = $failed
                SpeedMbps      = $speedMBps
                SpeedGBperHour = $speedGBperHour
                ErrorMessages  = $errorMessages -join "; "
            }

            $summaries += $summary
        }
        else {
            Write-Host "Log file not found: $logFile"
        }
    }
    
    if ($summaries.Count -eq 0) {
        $outputBox.AppendText("No log files found to summarize." + [Environment]::NewLine)
    } else {
        $outputBox.AppendText("Summary of Robocopy operations:" + [Environment]::NewLine)
        
        $currentDateTime = Get-Date -Format "dd-MM-yy-HH-mm"
        $summaryPath = ".\Migration-Summary-$currentDateTime.csv"
        $summaries | Export-Csv -Path $summaryPath -NoTypeInformation
        $outputBox.AppendText("Detailed summary saved to $summaryPath" + [Environment]::NewLine)

        # Display a brief summary in the output box
        foreach ($item in $summaries) {
            $outputBox.AppendText("Log: $($item.LogFileName)" + [Environment]::NewLine)
            $outputBox.AppendText("  Start: $($item.StartDate) $($item.StartTime), End: $($item.EndDate) $($item.EndTime)" + [Environment]::NewLine)
            $outputBox.AppendText("  Duration: $($item.Duration)" + [Environment]::NewLine)
            $outputBox.AppendText("  Files: Total=$($item.TotalFiles), Skipped=$($item.Skipped), Failed=$($item.Failed)" + [Environment]::NewLine)
            $outputBox.AppendText("  Total Size: $($item.TotalSizeGB) GB" + [Environment]::NewLine)
            $outputBox.AppendText("  Speed: $($item.SpeedMbps) Mbps, $($item.SpeedGBperHour) GB/hour" + [Environment]::NewLine)
            if ($item.ErrorMessages) {
                $outputBox.AppendText("  Errors: $($item.ErrorMessages)" + [Environment]::NewLine)
            }
            $outputBox.AppendText([Environment]::NewLine)
        }

        return $summaries
    }
}

# Create main form
$form = New-Object system.Windows.Forms.Form
$form.Text = "Robocopy Migration"
$form.Size = New-Object System.Drawing.Size(600,650)

# Create controls
$migrationListBox = New-Object System.Windows.Forms.ListBox
$migrationListBox.SelectionMode = "MultiExtended"
$migrationListBox.Location = New-Object System.Drawing.Point(20,20)
$migrationListBox.Size = New-Object System.Drawing.Size(540,150)
$form.Controls.Add($migrationListBox)

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Size = New-Object System.Drawing.Size(540,150)
$outputBox.Location = New-Object System.Drawing.Point(20,330)
$outputBox.ReadOnly = $true
$form.Controls.Add($outputBox)

$startTimeLabel = New-Object System.Windows.Forms.Label
$startTimeLabel.Text = "Start Time (HHmm):"
$startTimeLabel.Location = New-Object System.Drawing.Point(20,180)
$form.Controls.Add($startTimeLabel)

$startTimeBox = New-Object System.Windows.Forms.TextBox
$startTimeBox.Text = "1900"  # Default value
$startTimeBox.Location = New-Object System.Drawing.Point(150,180)
$form.Controls.Add($startTimeBox)

$endTimeLabel = New-Object System.Windows.Forms.Label
$endTimeLabel.Text = "End Time (HHmm):"
$endTimeLabel.Location = New-Object System.Drawing.Point(20,210)
$form.Controls.Add($endTimeLabel)

$endTimeBox = New-Object System.Windows.Forms.TextBox
$endTimeBox.Text = "0700"  # Default value
$endTimeBox.Location = New-Object System.Drawing.Point(150,210)
$form.Controls.Add($endTimeBox)

$runButton = New-Object System.Windows.Forms.Button
$runButton.Location = New-Object System.Drawing.Point(20,500)
$runButton.Size = New-Object System.Drawing.Size(100,40)
$runButton.Text = "Run"
$form.Controls.Add($runButton)

$runAllButton = New-Object System.Windows.Forms.Button
$runAllButton.Location = New-Object System.Drawing.Point(130,500)
$runAllButton.Size = New-Object System.Drawing.Size(100,40)
$runAllButton.Text = "Run All"
$form.Controls.Add($runAllButton)

$viewSummaryButton = New-Object System.Windows.Forms.Button
$viewSummaryButton.Location = New-Object System.Drawing.Point(240,500)
$viewSummaryButton.Size = New-Object System.Drawing.Size(100,40)
$viewSummaryButton.Text = "View Summary"
$form.Controls.Add($viewSummaryButton)

$helpButton = New-Object System.Windows.Forms.Button
$helpButton.Location = New-Object System.Drawing.Point(350,500)
$helpButton.Size = New-Object System.Drawing.Size(100,40)
$helpButton.Text = "Help"
$form.Controls.Add($helpButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(460,500)
$exitButton.Size = New-Object System.Drawing.Size(100,40)
$exitButton.Text = "Exit"
$form.Controls.Add($exitButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(20,550)
$cancelButton.Size = New-Object System.Drawing.Size(100,40)
$cancelButton.Text = "Cancel"
$cancelButton.Enabled = $false
$form.Controls.Add($cancelButton)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(130,550)
$progressBar.Size = New-Object System.Drawing.Size(430,40)
$form.Controls.Add($progressBar)

# Load CSV data
try {
    $migrations = Import-Csv $global:csvPath
    foreach ($migration in $migrations) {
        $migrationListBox.Items.Add("Source: $($migration.Source), Destination: $($migration.Destination)")
    }
}
catch {
    [System.Windows.Forms.MessageBox]::Show("Error loading CSV file: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

# Button click event handlers
$runButton.Add_Click({
    $startTime = $startTimeBox.Text
    $endTime = $endTimeBox.Text

    if (-not (Is-ValidTimeFormat $startTime) -or -not (Is-ValidTimeFormat $endTime)) {
        [System.Windows.Forms.MessageBox]::Show("Invalid time format. Please use HHmm format.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    if ($migrationListBox.SelectedIndices.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one migration from the list.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $cancelButton.Enabled = $true
    $progressBar.Value = 0
    $progressBar.Maximum = $migrationListBox.SelectedIndices.Count

    foreach ($index in $migrationListBox.SelectedIndices) {
        $selectedMigration = $migrations[$index]
        Run-Robocopy -source $selectedMigration.Source -destination $selectedMigration.Destination -startTime $startTime -endTime $endTime
        $progressBar.Value += 1
        [System.Windows.Forms.Application]::DoEvents()
    }

    $cancelButton.Enabled = $false
    Summarize-Logs | Out-Null
})

$runAllButton.Add_Click({
    $startTime = $startTimeBox.Text
    $endTime = $endTimeBox.Text

    if (-not (Is-ValidTimeFormat $startTime) -or -not (Is-ValidTimeFormat $endTime)) {
        [System.Windows.Forms.MessageBox]::Show("Invalid time format. Please use HHmm format.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $cancelButton.Enabled = $true
    $progressBar.Value = 0
    $progressBar.Maximum = $migrations.Count

    foreach ($migration in $migrations) {
        Run-Robocopy -source $migration.Source -destination $migration.Destination -startTime $startTime -endTime $endTime
        $progressBar.Value += 1
        [System.Windows.Forms.Application]::DoEvents()
    }

    $cancelButton.Enabled = $false
    Summarize-Logs | Out-Null
})

$viewSummaryButton.Add_Click({
    $summaries = Summarize-Logs
    if ($summaries) {
        $summaryForm = New-Object system.Windows.Forms.Form
        $summaryForm.Text = "Migration Summary"
        $summaryForm.Size = New-Object System.Drawing.Size(800,600)
        
        $summaryBox = New-Object System.Windows.Forms.TextBox
        $summaryBox.Multiline = $true
        $summaryBox.ScrollBars = "Vertical"
        $summaryBox.Size = New-Object System.Drawing.Size(760,500)
        $summaryBox.Location = New-Object System.Drawing.Point(20,20)
        $summaryBox.Font = New-Object System.Drawing.Font("Consolas", 10)
        
        $summaryText = "Migration Summary:`r`n`r`n"
        foreach ($summary in $summaries) {
            $summaryText += "Log File: $($summary.LogFileName)`r`n"
            $summaryText += "Command: $($summary.Command)`r`n"
            $summaryText += "Started: $($summary.StartDate) $($summary.StartTime)`r`n"
            $summaryText += "Ended: $($summary.EndDate) $($summary.EndTime)`r`n"
            $summaryText += "Duration: $($summary.Duration)`r`n"
            $summaryText += "Files: Total=$($summary.TotalFiles), Dirs: Total=$($summary.TotalDirs)`r`n"
            $summaryText += "Total Size: $($summary.TotalSizeGB) GB`r`n"
            $summaryText += "Skipped: $($summary.Skipped), Failed: $($summary.Failed)`r`n"
            $summaryText += "Speed: $($summary.SpeedMbps) Mbps, $($summary.SpeedGBperHour) GB/hour`r`n"
            if ($summary.ErrorMessages) {
                $summaryText += "Errors: $($summary.ErrorMessages)`r`n"
            }
            $summaryText += "`r`n"
        }
        $summaryBox.Text = $summaryText
        $summaryForm.Controls.Add($summaryBox)

        $copyButton = New-Object System.Windows.Forms.Button
        $copyButton.Text = "Copy"
        $copyButton.Location = New-Object System.Drawing.Point(20,530)
        $copyButton.Size = New-Object System.Drawing.Size(100,40)
        $summaryForm.Controls.Add($copyButton)

        $copyButton.Add_Click({
            $summaryBox.SelectAll()
            $summaryBox.Copy()
            [System.Windows.Forms.MessageBox]::Show("Summary copied to clipboard.", "Copied")
        })

        $summaryForm.Add_Shown({$summaryForm.Activate()})
        [void]$summaryForm.ShowDialog()
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("No summary available to display.", "No Summary")
    }
})

$helpButton.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "CSV File Requirements:" + [Environment]::NewLine +
        "--------------------------" + [Environment]::NewLine +
        "The CSV file should be named 'migrations.csv' and placed in the same directory as this script." + [Environment]::NewLine +
        "It should have the following columns:" + [Environment]::NewLine +
        "1. Source: The path to the source directory (e.g., C:\scripts\source)." + [Environment]::NewLine +
        "2. Destination: The path to the destination directory (e.g., C:\scripts\destination)." + [Environment]::NewLine + [Environment]::NewLine +
        "How the GUI Works:" + [Environment]::NewLine +
        "--------------------------" + [Environment]::NewLine +
        "1. The list box displays all the available migrations from the CSV file." + [Environment]::NewLine +
        "2. Set the Start Time and End Time for the Robocopy operation (HHmm format)." + [Environment]::NewLine +
        "3. Select one or more migrations from the list and click 'Run' to start the migration(s)." + [Environment]::NewLine +
        "4. To run all migrations in sequence, click 'Run All'." + [Environment]::NewLine +
        "5. The log output will be displayed in the text box below the list." + [Environment]::NewLine +
        "6. Click 'View Summary' to see any errors or issues in the migrations." + [Environment]::NewLine +
        "7. The summary can be copied using the 'Copy' button." + [Environment]::NewLine +
        "8. Use the 'Cancel' button to stop the current operation." + [Environment]::NewLine +
        "9. The progress bar shows the overall progress of the operation." + [Environment]::NewLine +
        "10. Click 'Exit' to close the application.",
        "Help"
    )
})

$exitButton.Add_Click({ $form.Close() })

$cancelButton.Add_Click({
    if ($global:robocopyProcess -ne $null -and -not $global:robocopyProcess.HasExited) {
        $global:robocopyProcess.Kill()
        $outputBox.AppendText("Operation cancelled by user." + [Environment]::NewLine)
    }
    $cancelButton.Enabled = $false
})

# Run the form
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
