<#
.SYNOPSIS
This script synchronizes files from a specified source directory to an Azure Blob storage container using AzCopy.

.DESCRIPTION
The script constructs the destination URL using the provided storage account, container, and SAS token. It sets up a custom log file and directory for AzCopy logs, then executes the AzCopy sync command. The script checks the success of the operation and provides log file details for troubleshooting.

.PARAMETERS
-source
The path to the source directory containing the files to be synchronized. This parameter is required.
-storageAccount
The name of the Azure Storage account. This parameter is required.
-container
The name of the Azure Blob container. This parameter is required.
-sasToken
The SAS token providing access to the Azure Blob container. This parameter is required.

.EXAMPLE
PS> .\Azcopy-Delta-Sync.PS1
This command runs the script and synchronizes files from the source directory to the specified Azure Blob container, logging the details of the operation.

.NOTES
Before running this script, ensure you have the necessary permissions to access the Azure Blob storage container and that AzCopy is installed and available in your PATH.

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

# Azcopy-Migration.PS1
$source = "\\server\share"
$storageAccount = "<StorageAccount>"
$container = "<Container>"
$sasToken = "<SASToken>"

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

# Execute AzCopy sync command and log output
Write-Host "Executing AzCopy sync command..."
$azCopyCommand = @"
azcopy sync `"$source`" `"$destination`" --delete-destination=true --compare-hash=md5 --log-level=INFO > `"$customLogFile`" 2>&1
"@
Write-Host $azCopyCommand
Invoke-Expression $azCopyCommand

# Check if AzCopy sync was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "Sync completed successfully."
} else {
    Write-Host "Sync failed. Check the custom log for details: $customLogFile"
    exit 1
}

Write-Host "Using custom log file: $customLogFile"
