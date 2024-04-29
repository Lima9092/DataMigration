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

.EXAMPLE
PS> .\GetFolderInfo.ps1
  This command runs the script and prompts for the folder path, recursion depth, and whether to include hidden and system files.

.EXAMPLE
PS> .\GetFolderInfo.ps1 -FolderPath "C:\Your\Directory" -RecurseDepth 5 -IncludeHiddenSystem
  This command runs the script for the specified folder path and recursion depth, including hidden and system files in the analysis.

.NOTES
The script outputs a CSV file in the same location as the specified folder path. The file is named 'FolderStructure.csv'.

.AUTHOR
Lee Jolley, UK

.DATE
29/04/2024

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
    [string]$FolderPath,          # Path to the directory to analyze
    [switch]$IncludeHiddenSystem  # Switch to include hidden and system files
)

$global:TotalFolderSizeMB = 0

function Get-FolderInfo {
    param(
        [string]$Path,
        [int]$Depth,
        [bool]$IncludeHidden
    )

    if ($Depth -le 0) {
        return
    }

    $getChildrenParams = @{
        Path = $Path
        Force = $IncludeHidden
        ErrorAction = 'Stop'
    }
    $items = $null
    $errors = @()
    try {
        $items = Get-ChildItem @getChildrenParams
    } catch {
        $errors += $_.Exception.Message
    }

    $directories = $items | Where-Object { $_.PSIsContainer }
    $files = $items | Where-Object { -not $_.PSIsContainer }

    $totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
    $totalSizeMB = [math]::Round($totalSizeBytes / 1MB, 2)
    $global:TotalFolderSizeMB += $totalSizeMB

    $permissions = ""
    try {
        $acl = Get-Acl -Path $Path
        $permissionsArray = $acl.Access | ForEach-Object {
            "$($_.IdentityReference.Value):$($_.FileSystemRights);$($_.AccessControlType)"
        }
    } catch {
        $errors += $_.Exception.Message
    }

    $info = [PSCustomObject]@{
        Path          = $Path
        FileCount     = $files.Count
        FolderSizeMB  = $totalSizeMB
        Errors        = ($errors -join '; ')
        Permissions   = ($permissionsArray -join '| ')
    }

    $info

    foreach ($dir in $directories) {
        Get-FolderInfo -Path $dir.FullName -Depth ($Depth - 1) -IncludeHidden $IncludeHidden
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

$RecurseDepth = Read-Host "Please enter the number of folder levels to recurse through (default is 3)"
if ([string]::IsNullOrWhiteSpace($RecurseDepth)) {
    $RecurseDepth = 3
}

$csvOutputPath = Join-Path $PSScriptRoot "FolderStructure.csv"

function Export-Data {
    try {
        $results = Get-FolderInfo -Path $FolderPath -Depth $RecurseDepth -IncludeHidden $IncludeHiddenSystem
        $results | Export-Csv -Path $csvOutputPath -NoTypeInformation -ErrorAction Stop

        $totalInfo = [PSCustomObject]@{
            Path          = "Total"
            FileCount     = ""
            FolderSizeMB  = $global:TotalFolderSizeMB
            Errors        = ""
            Permissions   = ""
        }
        $totalInfo | Export-Csv -Path $csvOutputPath -NoTypeInformation -Append -ErrorAction Stop

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

# Call the export function
Export-Data

