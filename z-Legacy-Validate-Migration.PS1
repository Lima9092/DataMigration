<#
.SYNOPSIS
This script validates the successful migration of files by comparing the source and destination directories.

.DESCRIPTION
The script compares files in the specified source and destination directories to ensure that all files have been correctly migrated. It calculates the SHA256 hash of each file, along with checking file sizes and relative paths, to detect any discrepancies. Any differences found between the source and destination are logged and displayed.

.PARAMETERS
-None

.EXAMPLE
PS> .\Validate-Migration.ps1
  This command runs the script, compares the files in the source and destination directories, and logs the results to a file in the current directory.

.NOTES
Before running this script, ensure that the source and destination directories are accessible and contain the files you wish to compare.

.AUTHOR
Lee Jolley

.DATE
23/06/2024

.USE RIGHTS POLICY
This script is provided under an open use policy. You are free to use, modify, and distribute this script in your own projects under the following conditions:
1. This policy text and credit to the original author must be retained in any versions or derivatives of the script.
2. Any improvements or modifications to this script should ideally be shared back with the community or made publicly available.
3. This script is provided "as is," without warranty of any kind, express or implied. In no event shall the author be liable for any claim, damages, or other liability arising from its use.
#>


# Define source and destination directories
$sourceDir = "\\server\solder"
$destDir = "\\server\share"

# Get current date and time without seconds
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm"

# Format log file name
$sourceFormatted = $sourceDir -replace "[:\\]", "-"
$destinationFormatted = $destDir -replace "[:\\]", "-"
$logFile = "validation_${sourceFormatted}_${destinationFormatted}_${currentDateTime}.log"

# Function to write log
function Write-Log {
    param (
        [string]$Message
    )
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

# Start logging
Write-Log "Starting validation process"
Write-Log "Source directory: $sourceDir"
Write-Log "Destination directory: $destDir"

# Function to get file details (path, size, hash)
function Get-FileDetails {
    param (
        [string]$directory
    )
    Get-ChildItem -Path $directory -Recurse | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = $_.FullName.Substring($directory.Length)
            FullPath = $_.FullName
            Size = $_.Length
            Hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        }
    }
}

# Get details of files in source and destination directories
Write-Log "Gathering file details from source directory"
$sourceFiles = Get-FileDetails -directory $sourceDir
Write-Log "Gathering file details from destination directory"
$destFiles = Get-FileDetails -directory $destDir

# Create hashtables for quick lookup
$sourceFilesHashTable = @{}
$destFilesHashTable = @{}
$sourceFiles | ForEach-Object { $sourceFilesHashTable[$_.RelativePath] = $_ }
$destFiles | ForEach-Object { $destFilesHashTable[$_.RelativePath] = $_ }

# Compare files
$differences = @()
Write-Log "Comparing files"

# Check for files missing in destination or with different size/hash
$sourceFilesHashTable.GetEnumerator() | ForEach-Object {
    $relativePath = $_.Key
    $sourceFile = $_.Value
    if ($destFilesHashTable.ContainsKey($relativePath)) {
        $destFile = $destFilesHashTable[$relativePath]
        if ($sourceFile.Size -ne $destFile.Size -or $sourceFile.Hash -ne $destFile.Hash) {
            $differences += [PSCustomObject]@{
                RelativePath = $relativePath
                SourceSize = $sourceFile.Size
                DestSize = $destFile.Size
                SourceHash = $sourceFile.Hash
                DestHash = $destFile.Hash
                Status = "Mismatch"
            }
            Write-Log "Mismatch found: $relativePath"
        }
    } else {
        $differences += [PSCustomObject]@{
            RelativePath = $relativePath
            SourceSize = $sourceFile.Size
            DestSize = "N/A"
            SourceHash = $sourceFile.Hash
            DestHash = "N/A"
            Status = "Missing in Destination"
        }
        Write-Log "File missing in destination: $relativePath"
    }
}

# Check for files present in destination but missing in source
$destFilesHashTable.GetEnumerator() | ForEach-Object {
    $relativePath = $_.Key
    if (-not $sourceFilesHashTable.ContainsKey($relativePath)) {
        $destFile = $_.Value
        $differences += [PSCustomObject]@{
            RelativePath = $relativePath
            SourceSize = "N/A"
            DestSize = $destFile.Size
            SourceHash = "N/A"
            DestHash = $destFile.Hash
            Status = "Extra in Destination"
        }
        Write-Log "Extra file in destination: $relativePath"
    }
}

# Output the results
if ($differences.Count -eq 0) {
    $message = "No differences found. Migration successful."
    Write-Log $message
    Write-Host $message
} else {
    $message = "Total differences found: $($differences.Count)"
    Write-Log $message
    Write-Host $message
    Write-Log "Details of differences:"
    $differences | Format-Table -AutoSize | Out-String | Write-Log
    Write-Host "Details of differences:"
    $differences | Format-Table -AutoSize
}

Write-Log "Validation process completed"
