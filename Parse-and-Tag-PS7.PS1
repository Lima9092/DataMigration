<#
.SYNOPSIS
This script tags blobs in an Azure Blob storage container using AzCopy. This script runs copy jobs in parallel and requires PowerShell 7 to do so.

.DESCRIPTION
The script constructs the container URL using the provided storage account, container name, and SAS token. It retrieves a list of all blobs in the container and processes each blob in parallel to set a specified tag. The script logs the start and end times, as well as the duration of the operation, and captures details of the blob tagging process.

.PARAMETERS
-sasToken
The SAS token providing access to the Azure Blob container. This parameter is required.

-containerName
The name of the Azure Blob container. This parameter is required.

-storageAccountName
The name of the Azure Storage account. This parameter is required.

-tagValue
The tag value to be set on each blob. This parameter is required.

-maxRetries
The maximum number of retries for setting the blob tag. Default is 3.

-maxParallelJobs
The maximum number of parallel jobs for processing blobs. Default is 10.

.EXAMPLE
PS> .\BlobTaggingScript.PS1
This command runs the script and tags blobs in the specified Azure Blob container, logging the details of the operation.

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
    - $sasToken: Your SAS token providing access to the Azure Blob container.
    - $containerName: The name of your Azure Blob container.
    - $storageAccountName: The name of your Azure Storage account.
    - $tagValue: The tag value to be set on each blob.
    - $maxRetries: (Optional) The maximum number of retries for setting the blob tag. Default is 3.
    - $maxParallelJobs: (Optional) The maximum number of parallel jobs for processing blobs. Default is 10.
#>

# SAS token, container name, and tag value
$sasToken = "SASToken"
$containerName = "Container"
$storageAccountName = "StorageAccount"
$tagValue = "Tag=Value"
$maxRetries = 3
$maxParallelJobs = 10

# Function to list all blobs in the container
function Get-AllBlobs {
    param (
        [string]$containerUrl,
        [string]$sasToken
    )

    Write-Host "Listing all blobs in container: $containerUrl"

    $containerUrlWithSas = "${containerUrl}?${sasToken}"
    $command = "azcopy list `"$containerUrlWithSas`""
    Write-Host "Executing command: $command"
    
    try {
        $output = Invoke-Expression -Command $command
        Write-Host "AzCopy command executed successfully."
        Write-Host "Raw output: $output"
        
        # Parse blob names from AzCopy output
        $blobs = $output -split '\r\n' | ForEach-Object { 
            if ($_ -match '^(.*?)\s*;\s*Content Length:') {
                $matches[1].Trim()
            }
        } | Where-Object { $_ -ne '' }
        
        Write-Host "Parsed blobs: $($blobs -join ', ')"
    }
    catch {
        Write-Host "Error executing AzCopy command: $_"
        return $null
    }

    Write-Host "Total blobs found: $($blobs.Count)"
    return $blobs
}

# Main script execution
$startTime = Get-Date
Write-Host "Script started at $startTime."
Write-Host "Storage Account: $storageAccountName"
Write-Host "Container: $containerName"

# Get the list of all blobs
$containerUrl = "https://${storageAccountName}.blob.core.windows.net/$containerName"
Write-Host "Container URL: $containerUrl"

$blobs = Get-AllBlobs -containerUrl $containerUrl -sasToken $sasToken

if ($null -eq $blobs -or $blobs.Count -eq 0) {
    Write-Host "No blobs found or error occurred. Exiting script."
    exit
}

# Create log file
$logFileName = "BlobTaggingLog_$((Get-Date).ToString('yyyy-MM-dd_HH-mm')).csv"
$logFile = Join-Path -Path $PSScriptRoot -ChildPath $logFileName
"DateTime,BlobName,Status,ErrorMessage" | Out-File -FilePath $logFile

$totalBlobs = $blobs.Count
$currentBlobIndex = 0
$jobs = @()

# Process each blob in parallel using jobs
foreach ($blobName in $blobs) {
    if ($jobs.Count -ge $maxParallelJobs) {
        $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
        Start-Sleep -Seconds 1
    }

    $jobs += Start-Job -ScriptBlock {
        param (
            $blobName,
            $containerUrl,
            $sasToken,
            $tagValue,
            $maxRetries,
            $logFile,
            $totalBlobs,
            $currentBlobIndex
        )
        
        function Set-BlobTag {
            param (
                [string]$blobName,
                [string]$containerUrl,
                [string]$sasToken,
                [string]$tagValue,
                [int]$maxRetries,
                [string]$logFile
            )

            $blobUrl = "${containerUrl}/${blobName}?${sasToken}"
            $command = "azcopy set-properties `"$blobUrl`" --blob-tags=`"$tagValue`""
            $success = $false
            $errorMessage = ""
            for ($retry = 0; $retry -lt $maxRetries; $retry++) {
                Write-Host ("Attempt {0} to tag blob: {1}" -f ($retry + 1), $blobName)
                try {
                    $output = Invoke-Expression -Command $command
                    if ($output -notmatch "failed") {
                        Write-Host ("Successfully tagged blob: {0}" -f $blobName)
                        $success = $true
                        Add-Content -Path $logFile -Value "$((Get-Date).ToString('yyyy-MM-dd HH:mm')),$blobName,Success"
                        break
                    } else {
                        Write-Host ("Failed to tag blob: {0}. Error: {1}" -f $blobName, $output)
                        $errorMessage = $output
                    }
                } catch {
                    Write-Host ("Failed to tag blob: {0}. Exception: {1}" -f $blobName, $_.Exception.Message)
                    $errorMessage = $_.Exception.Message
                }
                Start-Sleep -Seconds 2  # Add a small delay before retrying
            }
            if (-not $success) {
                Write-Host ("Failed to set tags for blob: {0} after {1} retries" -f $blobName, $maxRetries)
                Add-Content -Path $logFile -Value "$((Get-Date).ToString('yyyy-MM-dd HH:mm')),$blobName,Failed,$errorMessage"
            }
        }
        
        Write-Host ("Processing blob {0} of {1}: {2}" -f $currentBlobIndex, $totalBlobs, $blobName)
        Set-BlobTag -blobName $blobName -containerUrl $containerUrl -sasToken $sasToken -tagValue $tagValue -maxRetries $maxRetries -logFile $logFile
    } -ArgumentList $blobName, $containerUrl, $sasToken, $tagValue, $maxRetries, $logFile, $totalBlobs, $currentBlobIndex

    $currentBlobIndex++
}

# Wait for all jobs to complete
$jobs | ForEach-Object { 
    $_ | Wait-Job
    $_ | Receive-Job
    $_ | Remove-Job
}

$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "Script completed successfully at $endTime."
Write-Host "Total duration: $($duration.Hours) hours, $($duration.Minutes) minutes, $($duration.Seconds) seconds."

# Append start, end, and duration times to log file
"Start Time,$startTime" | Add-Content -Path $logFile
"End Time,$endTime" | Add-Content -Path $logFile
"Duration,$($duration.Hours) hours, $($duration.Minutes) minutes, $($duration.Seconds) seconds" | Add-Content -Path $logFile
