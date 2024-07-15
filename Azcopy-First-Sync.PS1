<#
.SYNOPSIS
This script performs an initial copy of data from a file share or Azure Blob storage container to another Azure Blob storage container using AzCopy, applying specified blob tags during the copy process.

.DESCRIPTION
The script constructs the source and destination URLs using the provided SAS tokens. It sets up a custom log file and directory for AzCopy logs, then executes the AzCopy copy command. The script logs the start and end times, as well as the duration of the operation, and captures details of the copy process. This is typically used as an initial copy in a data migration that tags the blobs at the same time as copying.

.PARAMETERS
-source
The source path or URL of the Azure Blob storage container or file share, with a wildcard at the end to avoid recreating the source root folder in the destination. This parameter is required.

-destination
The destination URL of the Azure Blob storage container. This parameter is required.

-blobTags
The tags to be applied to the copied blobs. This parameter is required.

.EXAMPLE
PS> .\Azcopy-First-Sync.PS1
This command runs the script and copies blobs from the specified source container or file share to the destination container, logging the details of the operation.

.NOTES
Before running this script, ensure you have the necessary permissions to access the Azure Blob storage containers and that AzCopy is installed and available in your PATH.


.ACCOMPANYING SCRIPTS
- Azcopy-Delta-Sync.PS1: Used to migrate deltas in the data.
- Parse-And-Tag.PS1: Used to parse log files and tag data.

.AUTHOR
Lee Jolley

.DATE
02/07/2024

.USE RIGHTS POLICY
This script is provided under an open use policy. You are free to use, modify, and distribute this script in your own projects under the following conditions:

    1. This policy text and credit to the original author must be retained in any versions or derivatives of the script.
    2. Any improvements or modifications to this script should ideally be shared back with the community or made publicly available.
    3. This script is provided “as is,” without warranty of any kind, express or implied. In no event shall the author be liable for any claim, damages, or other liability arising from its use.

# VARIABLES TO UPDATE
Before running the script, ensure to update the following variables to match your environment:
    - $source: The source URL of the Azure Blob storage container or file share, with a wildcard at the end to avoid recreating the source root folder in the destination.
    - $destination: The destination URL of the Azure Blob storage container.
    - $blobTags: The tags to be applied to the copied blobs.
#>

[string]$source = "https://<storageaccount>.blob.core.windows.net/<container>/*?<SASToken>"
[string]$destination = "https://<storageaccount>.blob.core.windows.net/<container>/<folder>?<SASToken>"
[string]$blobTags = "Tag=Value"

# Get current directory
$currentDir = (Get-Location).Path

# Replace backslashes with underscores in the source path for the log file name
$sourceContainer = "source_to_sitea"

# Generate log file name without seconds and with .log extension
$currentDateTime = (Get-Date).ToString("yyyy-MM-dd_HH-mm")
$customLogFile = "$currentDir\AzCopyCustomLog_${sourceContainer}_$currentDateTime.log"

# Set environment variable for AzCopy log location
$logDirectory = "$currentDir\AzCopyLogs"
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}
$env:AZCOPY_LOG_LOCATION = $logDirectory

# Initialize logging variables
$startDate = Get-Date -Format "dd MMMM yyyy"
$startTime = Get-Date -Format "HH:mm:ss"

# Execute AzCopy copy command and log output
Write-Host "Executing AzCopy copy command..."
$azCopyArgs = @(
    "cp",
    $source,
    $destination,
    "--blob-tags=$blobTags",
    "--log-level=INFO",
    "--recursive"
)
Write-Host "azcopy $($azCopyArgs -join ' ')"

try {
    $azCopyOutput = & azcopy $azCopyArgs 2>&1 | Tee-Object -FilePath $customLogFile
    # Log the raw output for debugging
    $azCopyOutput | Out-File -FilePath "$customLogFile.raw" -Append
}
catch {
    Write-Host "Error executing AzCopy: $_"
    $_ | Out-File -FilePath $customLogFile -Append
    exit 1
}

# Capture end time and calculate duration
$endDate = Get-Date -Format "dd MMMM yyyy"
$endTime = Get-Date -Format "HH:mm:ss"
$startDateTime = [datetime]::ParseExact("$startDate $startTime", "dd MMMM yyyy HH:mm:ss", $null)
$endDateTime = [datetime]::ParseExact("$endDate $endTime", "dd MMMM yyyy HH:mm:ss", $null)
$duration = ($endDateTime - $startDateTime).ToString("hh\:mm\:ss")

# Function to safely extract information using regex
function Get-RegexMatch {
    param (
        [string]$Text,
        [string]$Pattern,
        [string]$DefaultValue = "N/A"
    )
    $match = [regex]::Match($Text, $Pattern)
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $DefaultValue
}

# Extract information from AzCopy output
$totalFiles = Get-RegexMatch -Text $azCopyOutput -Pattern "Files\s+count:\s+(\d+)"
$totalDirs = Get-RegexMatch -Text $azCopyOutput -Pattern "Folders\s+count:\s+(\d+)"
$totalBytes = Get-RegexMatch -Text $azCopyOutput -Pattern "Total Bytes\s+processed:\s+([\d,]+)" -DefaultValue "0"
$totalBytes = $totalBytes -replace ",", ""
$speedMBps = Get-RegexMatch -Text $azCopyOutput -Pattern "Throughput\s+\(MB/s\):\s+([\d\.]+)"
$speedGBperHour = if ($totalBytes -ne "N/A" -and $totalBytes -ne "0") {
    [math]::Round(([long]$totalBytes / 1GB) / ($endDateTime - $startDateTime).TotalHours, 2)
} else { "N/A" }
$failed = Get-RegexMatch -Text $azCopyOutput -Pattern "Failed Transfers:\s+(\d+)"
$skipped = Get-RegexMatch -Text $azCopyOutput -Pattern "Skipped Transfers:\s+(\d+)"

# Append summary information to the log
$summaryInfo = @"
Started : $startDate $startTime
Ended : $endDate $endTime
Duration : $duration
Options : azcopy $($azCopyArgs -join ' ')
Files : $totalFiles
Dirs : $totalDirs
Bytes : $totalBytes
Speed : $speedMBps MB/s ($speedGBperHour GB/hour)
Failed : $failed
Skipped : $skipped
"@

Add-Content -Path $customLogFile -Value $summaryInfo

# Check if AzCopy copy was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "Copy completed successfully."
} else {
    Write-Host "Copy failed. Check the custom log for details: $customLogFile"
    exit 1
}

Write-Host "Using custom log file: $customLogFile"
Write-Host "Raw output log file: $customLogFile.raw"

# Clean up environment variable
Remove-Item Env:AZCOPY_LOG_LOCATION
