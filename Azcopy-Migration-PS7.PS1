<#
.SYNOPSIS
This script synchronizes files from a specified source directory to an Azure Blob storage container using AzCopy. This script runs copy jobs in parallel and requires PowerShell 7 to do so.

.DESCRIPTION
The script constructs the destination URL using the provided storage account, container, and SAS token. It sets up a custom log file and directory for AzCopy logs, then executes the AzCopy sync command in parallel for efficiency. The script checks the success of the operation and provides log file details for troubleshooting.

.PARAMETERS
-source
The path to the source directory containing the files to be synchronized. This parameter is required.

-storageAccount
The name of the Azure Storage account. This parameter is required.

-container
The name of the Azure Blob container. This parameter is required.

-sasToken
The SAS token providing access to the Azure Blob container. This parameter is required.

-maxParallelJobs
Sets the maximum number of jobs to be run in parallel

.EXAMPLE
PS> .\Azcopy-Migration-PS7.PS1
This command runs the script and synchronizes files from the source directory to the specified Azure Blob container, logging the details of the operation.

.NOTES
Before running this script, ensure you have the necessary permissions to access the Azure Blob storage container and that AzCopy is installed and available in your PATH.

This script requires PowerShell 7 or later.

.AUTHOR
Lee Jolley

.DATE
14/07/2024

.USE RIGHTS POLICY
This script is provided under an open use policy. You are free to use, modify, and distribute this script in your own projects under the following conditions:

    1. This policy text and credit to the original author must be retained in any versions or derivatives of the script.
    2. Any improvements or modifications to this script should ideally be shared back with the community or made publicly available.
    3. This script is provided “as is,” without warranty of any kind, express or implied. In no event shall the author be liable for any claim, damages, or other liability arising from its use.

# VARIABLES TO UPDATE
Before running the script, ensure to update the following variables to match your environment:
    - $source: Path to the source directory containing the files to be synchronized.
    - $storageAccount: The name of your Azure Storage account.
    - $container: The name of your Azure Blob container.
    - $sasToken: Your SAS token providing access to the Azure Blob container.
#>

# Parameters
[string]$source = "\\Server\Share"
[string]$storageAccount = "StorageAccount"
[string]$container = "Container"
[string]$sasToken = "SAS Token"
$maxParallelJobs = 10

# Construct the destination URL
$destination = "https://$storageAccount.blob.core.windows.net/$container`?$sasToken"

# Get current directory
$currentDir = (Get-Location).Path

# Replace backslashes with underscores in the source path for the log file name
$sourceContainer = $source -replace '\\', '_'

# Generate log file name without seconds and with .log extension
$currentDateTime = (Get-Date).ToString("yyyy-MM-dd_HH-mm")
$customLogFile = "$currentDir\AzCopyCustomLog_${sourceContainer}_to_${container}_$currentDateTime.log"

# Set environment variable for AzCopy log location
$logDirectory = "$currentDir\AzCopyLogs"
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}
$env:AZCOPY_LOG_LOCATION = $logDirectory

# Initialize logging variables
$startDate = Get-Date -Format "dd MMMM yyyy"
$startTime = Get-Date -Format "HH:mm:ss"

# Execute AzCopy sync command in parallel and log output
Write-Host "Executing AzCopy sync command..."
$azCopyArgs = @(
    "sync",
    $source,
    $destination,
    "--delete-destination=true",
    "--compare-hash=md5",
    "--log-level=INFO"
)
Write-Host "azcopy $($azCopyArgs -join ' ')"

$startTime = Get-Date
$jobs = @()

for ($i = 0; $i -lt $maxParallelJobs; $i++) {
    $jobs += Start-Job -ScriptBlock {
        param ($source, $destination, $azCopyArgs, $customLogFile)
        
        try {
            $azCopyOutput = & azcopy $azCopyArgs 2>&1
            $azCopyOutput | Out-File -FilePath $customLogFile -Append
            
            # Log the raw output for debugging
            $azCopyOutput | Out-File -FilePath "$customLogFile.raw" -Append
        }
        catch {
            Write-Host "Error executing AzCopy: $_"
            $_ | Out-File -FilePath $customLogFile -Append
            exit 1
        }
    } -ArgumentList $source, $destination, $azCopyArgs, $customLogFile
}

# Wait for all jobs to complete
$jobs | ForEach-Object { 
    $_ | Wait-Job
    $_ | Receive-Job
    $_ | Remove-Job
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
$speedMBps = Get-RegexMatch -Text $azCopyOutput -Pattern "Throughput \(MB/s\):\s+([\d\.]+)"
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

# Check if AzCopy sync was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "Sync completed successfully."
} else {
    Write-Host "Sync failed. Check the custom log for details: $customLogFile"
    exit 1
}

Write-Host "Using custom log file: $customLogFile"
Write-Host "Raw output log file: $customLogFile.raw"

# Clean up environment variable
Remove-Item Env:AZCOPY_LOG_LOCATION
