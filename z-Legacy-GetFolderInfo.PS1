<#
.SYNOPSIS
This script analyzes a specified folder structure, providing details about the number of files, folder size in MB, and NTFS permissions.

.DESCRIPTION
The script allows specifying a folder path and the desired depth of recursion either via command-line parameters or interactively. It includes an option to consider hidden and system files in the analysis. The script produces a CSV file containing the number of files, the size of each folder in megabytes, and NTFS permissions for each folder, with permissions being pipe-separated.

.PARAMETERS
-FolderPath
  The path to the directory that you want to analyze. If not provided as a command-line argument, the script will prompt for it.
-RecurseDepth
  The number of folder levels to recurse through. Default is 3 if not specified.
-IncludeHiddenSystem
  A switch to include hidden and system files in the analysis. If not specified, these files will be excluded.
-RecurseAll
  A switch to recurse through all folders regardless of depth.
-NoStats
  A switch to skip file count and size statistics, listing only folder names.
-IncludeExtensionSummary
  A switch to include a summary of file extensions in a separate CSV file.

.EXAMPLE
PS> .\GetFolderInfo.ps1
  This command runs the script and prompts for the folder path, recursion depth, and whether to include hidden and system files.

.EXAMPLE
PS> .\GetFolderInfo.ps1 -FolderPath "C:\Your\Directory" -RecurseDepth 5 -IncludeHiddenSystem
  This command runs the script for the specified folder path and recursion depth, including hidden and system files in the analysis.

.EXAMPLE
PS> .\GetFolderInfo.ps1 -FolderPath "C:\Your\Directory" -NoStats
  This command runs the script for the specified folder path and lists only the folder names up to the default recursion depth without calculating file counts and sizes.

.NOTES
The script outputs a CSV file in the same location as the specified folder path. The file is named 'FolderStructure.csv'. If the -IncludeExtensionSummary switch is used, a separate CSV file named 'FolderStructure.extensions.csv' is also created.

.AUTHOR
Lee Jolley, UK

.DATE
21/06/2024

.USE RIGHTS POLICY
This script is provided under an open use policy by Lee Jolley. You are free to use, modify, 
and distribute this script in your own projects, whether personal, commercial, or 
educational, under the following conditions:
1. This policy text and credit to the original author (Lee Jolley) must be retained in any 
   versions or derivatives of the script.
2. Any improvements or modifications to this script should ideally be shared back 
   with the community or made publicly available, although this is encouraged but not mandatory.
3. This script is provided "as is," without warranty of any kind, express or implied. 
   In no event shall the author be liable for any claim, damages, or other liability 
   arising from its use.
#>

param(
    [string]$FolderPath,                  # Path to the directory to analyze
    [switch]$IncludeHiddenSystem,         # Switch to include hidden and system files
    [int]$RecurseDepth = 3,               # Depth of recursion
    [switch]$RecurseAll,                  # Switch to recurse all folders regardless of depth
    [switch]$NoStats,                     # Switch to skip file count and size stats
    [switch]$IncludeExtensionSummary      # Switch to include file extension summary
)

$global:TotalFolderSizeMB = 0
$global:TotalFileCount = 0
$global:Results = @()
$global:ExtensionSummary = @{}

function Get-FolderInfo {
    param(
        [string]$Path,
        [int]$Depth,
        [bool]$IncludeHidden,
        [bool]$CalculateStats
    )

    if ($Depth -le 0) {
        return
    }

    $getChildrenParams = @{
        Path = $Path
        Force = $IncludeHidden
        ErrorAction = 'SilentlyContinue'
    }

    $items = $null
    $errors = @()
    try {
        $items = Get-ChildItem @getChildrenParams
    } catch {
        $errors += $_.Exception.Message
    }

    if ($items -eq $null) {
        return
    }

    $directories = $items | Where-Object { $_.PSIsContainer }
    $files = $items | Where-Object { -not $_.PSIsContainer }

    $totalSizeBytes = 0
    $fileCount = 0
    $totalSizeMB = 0

    if ($CalculateStats -and $files) {
        $totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
        $fileCount = $files.Count
        $totalSizeMB = [math]::Round($totalSizeBytes / 1MB, 2)
        $global:TotalFolderSizeMB += $totalSizeMB
        $global:TotalFileCount += $fileCount

        if ($IncludeExtensionSummary) {
            foreach ($file in $files) {
                $ext = $file.Extension.ToLower()
                if ($global:ExtensionSummary.ContainsKey($ext)) {
                    $global:ExtensionSummary[$ext] += 1
                } else {
                    $global:ExtensionSummary[$ext] = 1
                }
            }
        }
    }

    $permissions = ""
    try {
        $acl = Get-Acl -Path $Path -ErrorAction SilentlyContinue
        $permissionsArray = $acl.Access | ForEach-Object {
            "$($_.IdentityReference.Value):$($_.FileSystemRights);$($_.AccessControlType)"
        }
    } catch {
        $errors += $_.Exception.Message
    }

    $info = [PSCustomObject]@{
        Path          = $Path
        FileCount     = $fileCount
        FolderSizeMB  = $totalSizeMB
        Errors        = ($errors -join '; ')
        Permissions   = ($permissionsArray -join '| ')
    }

    $global:Results += $info

    foreach ($dir in $directories) {
        Get-FolderInfo -Path $dir.FullName -Depth ($Depth - 1) -IncludeHidden $IncludeHidden -CalculateStats $CalculateStats
    }
}

function Get-AllFolderInfo {
    param(
        [string]$Path,
        [bool]$IncludeHidden
    )

    $getChildrenParams = @{
        Path = $Path
        Force = $IncludeHidden
        Recurse = $true
        ErrorAction = 'SilentlyContinue'
    }

    $items = $null
    $errors = @()
    try {
        $items = Get-ChildItem @getChildrenParams
    } catch {
        $errors += $_.Exception.Message
    }

    if ($items -eq $null) {
        return
    }

    $files = $items | Where-Object { -not $_.PSIsContainer }

    $totalSizeBytes = 0
    $fileCount = 0

    if ($files) {
        $totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
        $fileCount = $files.Count
        $totalSizeMB = [math]::Round($totalSizeBytes / 1MB, 2)
        $global:TotalFolderSizeMB += $totalSizeMB
        $global:TotalFileCount += $fileCount

        if ($IncludeExtensionSummary) {
            foreach ($item in $items) {
                $ext = $item.Extension.ToLower()
                if ($global:ExtensionSummary.ContainsKey($ext)) {
                    $global:ExtensionSummary[$ext] += 1
                } else {
                    $global:ExtensionSummary[$ext] = 1
                }
            }
        }
    }
}

# Set up the environment
if (-not $FolderPath) {
    $FolderPath = Read-Host "Please enter the path to the folder you want to analyze"
}

if (-not $PSBoundParameters.ContainsKey('IncludeHiddenSystem')) {
    $includeHiddenResponse = Read-Host "Do you want to include hidden and system files? (yes/no) (default is no)"
    $IncludeHiddenSystem = $includeHiddenResponse -eq 'yes'
}

# Get the current timestamp without seconds
$timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm")

# Sanitize the folder path for use in file names
$sanitizedFolderPath = ($FolderPath -replace '[\\/:*?"<>|]', '_').TrimEnd('_')

# Determine the CSV output paths
$csvOutputPath = Join-Path (Get-Location) "${sanitizedFolderPath}_FolderStructure_${timestamp}.csv"
$extensionSummaryPath = Join-Path (Get-Location) "${sanitizedFolderPath}_ExtensionSummary_${timestamp}.csv"

function Export-Data {
    try {
        if (-not $NoStats) {
            # Always calculate total stats by recursing all folders
            Calculate-TotalStats -Path $FolderPath -IncludeHidden $IncludeHiddenSystem

            # Capture detailed info up to the specified depth
            Get-FolderInfo -Path $FolderPath -Depth $RecurseDepth -IncludeHidden $IncludeHiddenSystem -CalculateStats $true

            $global:Results | Export-Csv -Path $csvOutputPath -NoTypeInformation -ErrorAction Stop

            $totalInfo = [PSCustomObject]@{
                Path          = "Total"
                FileCount     = $global:TotalFileCount
                FolderSizeMB  = $global:TotalFolderSizeMB
                Errors        = ""
                Permissions   = ""
            }
            $totalInfo | Export-Csv -Path $csvOutputPath -NoTypeInformation -Append -ErrorAction Stop
        } else {
            # Only capture folder names up to the specified depth
            Get-FolderInfo -Path $FolderPath -Depth $RecurseDepth -IncludeHidden $IncludeHiddenSystem -CalculateStats $false

            $global:Results | Export-Csv -Path $csvOutputPath -NoTypeInformation -ErrorAction Stop
        }

        if ($IncludeExtensionSummary) {
            $global:ExtensionSummary.GetEnumerator() | ForEach-Object {
                [PSCustomObject]@{
                    Extension = $_.Key
                    Count     = $_.Value
                }
            } | Export-Csv -Path $extensionSummaryPath -NoTypeInformation -ErrorAction Stop
            Write-Host "Extension summary CSV file has been created at $extensionSummaryPath"
        }

        Write-Host "CSV file has been created at $csvOutputPath"
    } catch {
        if ($_.Exception.Message -like "*cannot access the file*") {
            Write-Host "Error: The file $csvOutputPath is in use by another process."
            Write-Host "Please close the file and press Enter to retry."
            Read-Host
            Export-Data
        } else {
            Write-Host "An unexpected error occurred: $($_.Exception.Message)"
        }
    }
}

function Calculate-TotalStats {
    param(
        [string]$Path,
        [bool]$IncludeHidden
    )

    $getChildrenParams = @{
        Path = $Path
        Force = $IncludeHidden
        Recurse = $true
        ErrorAction = 'SilentlyContinue'
    }

    $items = $null
    try {
        $items = Get-ChildItem @getChildrenParams -File
    } catch {
        return
    }

    if ($items) {
        $totalSizeBytes = ($items | Measure-Object -Property Length -Sum).Sum
        $fileCount = $items.Count
        $totalSizeMB = [math]::Round($totalSizeBytes / 1MB, 2)
        $global:TotalFolderSizeMB += $totalSizeMB
        $global:TotalFileCount += $fileCount

        if ($IncludeExtensionSummary) {
            foreach ($item in $items) {
                $ext = $item.Extension.ToLower()
                if ($global:ExtensionSummary.ContainsKey($ext)) {
                    $global:ExtensionSummary[$ext] += 1
                } else {
                    $global:ExtensionSummary[$ext] = 1
                }
            }
        }
    }
}

# Call the export function
Export-Data
