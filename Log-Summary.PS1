<#
.SYNOPSIS
This script processes Robocopy log files, summarizing key information such as start and end times, file and directory counts, sizes, speeds, and errors into a CSV file.

.DESCRIPTION
The script scans all .log files in the same directory, extracts details from each Robocopy log, and outputs a CSV file with the summarized information. This includes the name of the log file, start and end dates and times, duration, command used, total files and directories, total size in GB, number of skipped and failed items, copy speed in Mbps and GB/hour, and any error messages.

.EXAMPLE
PS> .\Log-Summary.ps1
  This command runs the script and processes all .log files in the current directory, outputting a CSV summary.

.NOTES
The script outputs a CSV file named 'LogSummary.csv' in the same location as the script.

.AUTHOR
Lee Jolley

.DATE
22/06/2024

.USE RIGHTS POLICY
This script is provided under an open use policy by [Your Name]. You are free to use, modify, 
and distribute this script in your own projects, whether personal, commercial, or 
educational, under the following conditions:
1. This policy text and credit to the original author ([Your Name]) must be retained in any 
   versions or derivatives of the script.
2. Any improvements or modifications to this script should ideally be shared back 
   with the community or made publicly available, although this is encouraged but not mandatory.
3. This script is provided "as is," without warranty of any kind, express or implied. 
   In no event shall the author be liable for any claim, damages, or other liability 
   arising from its use.
#>

# Define the output CSV file
$outputCsv = "LogSummary.csv"

# Create an array to hold the summary objects
$summaries = @()

# Get all .log files in the same directory as the script
$logFiles = Get-ChildItem -Path . -Filter *.log

foreach ($logFile in $logFiles) {
    # Read the contents of the log file
    $logContent = Get-Content $logFile.FullName
    
    # Initialize variables to hold parsed data
    $logFileName = $logFile.Name
    $startDate = ""
    $startTime = ""
    $endDate = ""
    $endTime = ""
    $command = ""
    $duration = ""
    $totalFiles = 0
    $totalDirs = 0
    $totalBytes = 0
    $failed = 0
    $skipped = 0
    $errorMessages = @()
    $speedBytesPerSec = 0
    $speedMBps = 0
    $speedGBperHour = 0

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
        if ($line -match "^\s*Speed\s*:\s*([\d,]+) Bytes/sec.") {
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
        StartDate      = $startDate
        StartTime      = $startTime
        EndDate        = $endDate
        EndTime        = $endTime
        Duration       = $duration
        Command        = $command
        TotalFiles     = $totalFiles
        TotalDirs      = $totalDirs
        TotalSizeGB    = [math]::Round($totalBytes, 2)
        Skipped        = $skipped
        Failed         = $failed
        SpeedMbps      = $speedMBps
        SpeedGBperHour = $speedGBperHour
        ErrorMessages  = $errorMessages -join "; "
    }

    # Add the summary object to the array
    $summaries += $summary
}

# Export the summaries to a CSV file
$summaries | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "Summary has been exported to $outputCsv"
