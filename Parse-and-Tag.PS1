<#
.SYNOPSIS
This script parses custom AzCopy log files to extract blob URLs and sets tags on copied blobs, recording the actions in a CSV file. It works in conjunction with Azcopy-Migration.PS1

.DESCRIPTION
The script reads custom AzCopy log files in the current directory to extract URLs of copied and deleted blobs. It then sets a specified tag on each copied blob using AzCopy and records the actions in a CSV file. The CSV file contains entries for both copied and deleted blobs, with the log file details included in the filename for easy identification.

.PARAMETERS
-sasToken
The SAS token providing access to the Azure Blob container. This parameter is required.
-tagValue
The tag value to set on the copied blobs. This parameter is required.

.EXAMPLE
PS> .\Parse-and-Tag.PS1
This command runs the script, parses the custom AzCopy log file in the current directory, sets the specified tag on copied blobs, and generates a CSV file with the results.

.NOTES
Before running this script, ensure you have the necessary permissions to set tags on blobs in Azure Blob storage and that AzCopy is installed and available in your PATH. The SAS token requires TAG rights which can be provisioned in the Storage Explorer tool

.AUTHOR
Lee Jolley

.DATE
02/07/2024

.USE RIGHTS POLICY
This script is provided under an open use policy. You are free to use, modify, and distribute this script in your own projects under the following conditions:

	1.	This policy text and credit to the original author must be retained in any versions or derivatives of the script.
	2.	Any improvements or modifications to this script should ideally be shared back with the community or made publicly available.
	3.	This script is provided “as is,” without warranty of any kind, express or implied. In no event shall the author be liable for any claim, damages, or other liability arising from its use.
#>

# Parse-and-Tag.PS1
$sasToken = "<SASToken>"
$tagValue = "<TAG>=<Value>"

# Get the list of custom log files
$logDirectory = Get-Location
$customLogFiles = Get-ChildItem -Path $logDirectory -Filter "AzCopyCustomLog_*.log"

if ($customLogFiles.Count -eq 0) {
    Write-Host "No custom log files found."
    exit
}

# Prompt user to select a log file if multiple exist
if ($customLogFiles.Count -gt 1) {
    Write-Host "Multiple log files found:"
    for ($i = 0; $i -lt $customLogFiles.Count; $i++) {
        Write-Host "[$i] $($customLogFiles[$i].Name)"
    }
    $selectedLogIndex = Read-Host "Enter the number of the log file you want to parse"
    $customLogFile = $customLogFiles[$selectedLogIndex]
} else {
    $customLogFile = $customLogFiles[0]
}

$customLogFilePath = $customLogFile.FullName
Write-Host "Parsing custom log file: $customLogFilePath"

# Read the custom log file
$customLogContent = Get-Content -Path $customLogFilePath

# Extract AzCopy log file path
$azCopyLogFilePath = $customLogContent | Select-String -Pattern "Log file is located at: (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }

if (-not $azCopyLogFilePath) {
    Write-Host "No AzCopy log file path found in the custom log file."
    exit
}

$azCopyLogFilePath = $azCopyLogFilePath.Trim()
Write-Host "Found AzCopy log file path: $azCopyLogFilePath"
Write-Host "Using AzCopy log file: $azCopyLogFilePath"

# Read the AzCopy log file
$azCopyLogContent = Get-Content -Path $azCopyLogFilePath

# Extract URLs of copied blobs
$copiedBlobs = $azCopyLogContent | Select-String -Pattern "UPLOADSUCCESSFUL: (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }

# Extract URLs of deleted blobs
$deletedBlobs = $azCopyLogContent | Select-String -Pattern "DELETE (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }


# Initialize an array for CSV content
$csvContent = @()

foreach ($blobUrl in $copiedBlobs) {
    Write-Host "Setting tags for blob: $blobUrl"
    $blobUrlWithSas = "$blobUrl`?$sasToken"
    $command = "azcopy set-properties `"$blobUrlWithSas`" --blob-tags=`"$tagValue`""
    $output = Invoke-Expression -Command $command
    Write-Host $output
    if ($output -notmatch "failed") {
        $csvContent += [PSCustomObject]@{
            Action = "Copied"
            BlobUrl = $blobUrl
        }
    } else {
        Write-Host "Failed to set tags for blob: $blobUrl"
    }
}

foreach ($blobUrl in $deletedBlobs) {
    Write-Host "Recording deleted blob: $blobUrl"
    $csvContent += [PSCustomObject]@{
        Action = "Deleted"
        BlobUrl = $blobUrl
    }
}

# Extracting the source and destination from the custom log file name
if ($customLogFile.Name -match "AzCopyCustomLog_(.+)_to_(.+)_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2})\.log") {
    $source = $matches[1]
    $destination = $matches[2]
    $timestamp = $matches[3]
} else {
    $source = "UnknownSource"
    $destination = "UnknownDestination"
    $timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm")
}

# Output CSV file
$csvFileName = "ChangedBlobs_${source}_to_${destination}_${timestamp}.csv"
$csvFilePath = Join-Path -Path $logDirectory -ChildPath $csvFileName
$csvContent | Export-Csv -Path $csvFilePath -NoTypeInformation
Write-Host "CSV file created: $csvFilePath"

Write-Host "Script completed successfully."
