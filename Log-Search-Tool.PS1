Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Log Search Tool"
$form.Size = New-Object System.Drawing.Size(800,600)
$form.StartPosition = "CenterScreen"

# Create and add controls
$lblKeywords = New-Object System.Windows.Forms.Label
$lblKeywords.Location = New-Object System.Drawing.Point(10,20)
$lblKeywords.Size = New-Object System.Drawing.Size(100,20)
$lblKeywords.Text = "Keywords:"
$form.Controls.Add($lblKeywords)

$txtKeywords = New-Object System.Windows.Forms.TextBox
$txtKeywords.Location = New-Object System.Drawing.Point(120,20)
$txtKeywords.Size = New-Object System.Drawing.Size(300,20)
$form.Controls.Add($txtKeywords)

$lblDateRange = New-Object System.Windows.Forms.Label
$lblDateRange.Location = New-Object System.Drawing.Point(10,50)
$lblDateRange.Size = New-Object System.Drawing.Size(100,20)
$lblDateRange.Text = "Date Range:"
$form.Controls.Add($lblDateRange)

$dtpStart = New-Object System.Windows.Forms.DateTimePicker
$dtpStart.Location = New-Object System.Drawing.Point(120,50)
$dtpStart.Size = New-Object System.Drawing.Size(140,20)
$form.Controls.Add($dtpStart)

$lblTo = New-Object System.Windows.Forms.Label
$lblTo.Location = New-Object System.Drawing.Point(270,50)
$lblTo.Size = New-Object System.Drawing.Size(30,20)
$lblTo.Text = "to"
$form.Controls.Add($lblTo)

$dtpEnd = New-Object System.Windows.Forms.DateTimePicker
$dtpEnd.Location = New-Object System.Drawing.Point(310,50)
$dtpEnd.Size = New-Object System.Drawing.Size(140,20)
$form.Controls.Add($dtpEnd)

$chkAllDates = New-Object System.Windows.Forms.CheckBox
$chkAllDates.Location = New-Object System.Drawing.Point(460,50)
$chkAllDates.Size = New-Object System.Drawing.Size(100,20)
$chkAllDates.Text = "All Dates"
$form.Controls.Add($chkAllDates)

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Location = New-Object System.Drawing.Point(10,80)
$lblFolder.Size = New-Object System.Drawing.Size(100,20)
$lblFolder.Text = "Log Folder:"
$form.Controls.Add($lblFolder)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(120,80)
$txtFolder.Size = New-Object System.Drawing.Size(300,20)
$txtFolder.Text = ".\Logs\VerboseLogs"
$form.Controls.Add($txtFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(430,80)
$btnBrowse.Size = New-Object System.Drawing.Size(100,20)
$btnBrowse.Text = "Browse"
$form.Controls.Add($btnBrowse)

$btnSearch = New-Object System.Windows.Forms.Button
$btnSearch.Location = New-Object System.Drawing.Point(570,20)
$btnSearch.Size = New-Object System.Drawing.Size(100,80)
$btnSearch.Text = "Search"
$form.Controls.Add($btnSearch)

$lstResults = New-Object System.Windows.Forms.ListView
$lstResults.Location = New-Object System.Drawing.Point(10,110)
$lstResults.Size = New-Object System.Drawing.Size(760,410)
$lstResults.View = [System.Windows.Forms.View]::Details
$lstResults.FullRowSelect = $true
$lstResults.Columns.Add("Log File", 150)
$lstResults.Columns.Add("Date", 100)
$lstResults.Columns.Add("Content", 490)
$form.Controls.Add($lstResults)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Location = New-Object System.Drawing.Point(10,530)
$btnSave.Size = New-Object System.Drawing.Size(100,30)
$btnSave.Text = "Save to CSV"
$form.Controls.Add($btnSave)

# Event handlers
$btnBrowse.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the folder containing log files"
    $folderBrowser.SelectedPath = $txtFolder.Text

    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtFolder.Text = $folderBrowser.SelectedPath
    }
})

$btnSearch.Add_Click({
    $lstResults.Items.Clear()
    $keywords = $txtKeywords.Text -split ',' | ForEach-Object { $_.Trim() }
    $startDate = $dtpStart.Value.Date
    $endDate = $dtpEnd.Value.Date.AddDays(1).AddSeconds(-1)
    $useAllDates = $chkAllDates.Checked

    $logPath = $txtFolder.Text
    $logFiles = Get-ChildItem -Path $logPath -Include *.log, *.csv -Recurse

    foreach ($file in $logFiles) {
        if ($file.Name -match '(\d{6}-\d{4})') {
            try {
                $fileDate = [DateTime]::ParseExact($matches[1], "ddMMyy-HHmm", $null)
                if (-not $useAllDates -and ($fileDate -lt $startDate -or $fileDate -gt $endDate)) {
                    continue
                }

                $content = Get-Content $file.FullName
                $currentEntry = ""
                foreach ($line in $content) {
                    if ($line -match '^\s*(Source|Dest|New Dir|\*EXTRA Dir|\s+\d+)\s*:') {
                        if ($currentEntry -ne "") {
                            $matchFound = $false
                            if ($keywords.Count -eq 0) {
                                $matchFound = $true
                            } else {
                                foreach ($keyword in $keywords) {
                                    if ($currentEntry -match $keyword) {
                                        $matchFound = $true
                                        break
                                    }
                                }
                            }
                            if ($matchFound) {
                                $item = New-Object System.Windows.Forms.ListViewItem($file.Name)
                                $item.SubItems.Add($fileDate.ToString("yyyy-MM-dd HH:mm"))
                                $item.SubItems.Add($currentEntry.Trim())
                                $lstResults.Items.Add($item)
                            }
                        }
                        $currentEntry = $line
                    } else {
                        $currentEntry += " " + $line
                    }
                }
                # Add the last entry
                if ($currentEntry -ne "") {
                    $matchFound = $false
                    if ($keywords.Count -eq 0) {
                        $matchFound = $true
                    } else {
                        foreach ($keyword in $keywords) {
                            if ($currentEntry -match $keyword) {
                                $matchFound = $true
                                break
                            }
                        }
                    }
                    if ($matchFound) {
                        $item = New-Object System.Windows.Forms.ListViewItem($file.Name)
                        $item.SubItems.Add($fileDate.ToString("yyyy-MM-dd HH:mm"))
                        $item.SubItems.Add($currentEntry.Trim())
                        $lstResults.Items.Add($item)
                    }
                }
            } catch {
                Write-Host "Error processing file: $($file.Name). Error: $_"
            }
        } else {
            Write-Host "Filename does not match expected format: $($file.Name)"
        }
    }
})

$btnSave.Add_Click({
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV Files (*.csv)|*.csv"
    $saveFileDialog.Title = "Save Results"
    $saveFileDialog.ShowDialog()

    if ($saveFileDialog.FileName -ne "") {
        $results = @()
        foreach ($item in $lstResults.Items) {
            $results += [PSCustomObject]@{
                LogFile = $item.Text
                Date = $item.SubItems[1].Text
                Content = $item.SubItems[2].Text -replace "`r`n", " " -replace "`n", " " -replace '"', '""'
            }
        }
        $results | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation -Encoding UTF8
    }
})

$chkAllDates.Add_CheckedChanged({
    $dtpStart.Enabled = -not $chkAllDates.Checked
    $dtpEnd.Enabled = -not $chkAllDates.Checked
})

# Resize event handler
$form.Add_Resize({
    $lstResults.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 20), ($form.ClientSize.Height - 150))
    $btnSave.Location = New-Object System.Drawing.Point(10, ($form.ClientSize.Height - 40))
})

# Show the form
$form.ShowDialog()
