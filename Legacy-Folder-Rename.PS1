<#
.SYNOPSIS
This script renames all subfolders in a specified directory with a random 6-digit number.

.DESCRIPTION
The script prompts the user for the path of the folder containing subfolders to be renamed. It confirms with the user before proceeding to rename all subfolders with a unique random 6-digit number. The script ensures that there are no naming conflicts by checking for the existence of the new name before renaming.

.PARAMETERS
-folderPath
The path to the folder containing subfolders to rename. This parameter is entered by the user during script execution.

.EXAMPLE
PS> .\RenameSubfolders.PS1
This command runs the script, prompts the user for the folder path, and renames all subfolders in the specified directory with random 6-digit numbers.

.NOTES
Before running this script, ensure you have the necessary permissions to rename the subfolders in the specified directory.

This script requires PowerShell 5.0 or later.

.AUTHOR
Lee Jolley

.DATE
14/07/2024

.USE RIGHTS POLICY
This script is provided under an open use policy. You are free to use, modify, and distribute this script in your own projects under the following conditions:

    1. This policy text and credit to the original author must be retained in any versions or derivatives of the script.
    2. Any improvements or modifications to this script should ideally be shared back with the community or made publicly available.
    3. This script is provided “as is,” without warranty of any kind, express or implied. In no event shall the author be liable for any claim, damages, or other liability arising from its use.
#>

# Prompt for the folder path
$folderPath = Read-Host -Prompt "Enter the path of the folder containing subfolders to rename"

# Confirm before proceeding
$confirmation = Read-Host -Prompt "This will rename all subfolders in $folderPath. Are you sure you want to continue? (Y/N)"
if ($confirmation -ne 'Y') {
    Write-Host "Operation cancelled."
    exit
}

# Get all subfolders
$subfolders = Get-ChildItem -Path $folderPath -Directory

# Function to generate a random 6-digit number
function Get-RandomNumber {
    return Get-Random -Minimum 100000 -Maximum 999999
}

# Rename subfolders
foreach ($folder in $subfolders) {
    $newName = Get-RandomNumber
    while (Test-Path -Path (Join-Path -Path $folderPath -ChildPath $newName)) {
        $newName = Get-RandomNumber
    }
    Rename-Item -Path $folder.FullName -NewName $newName
    Write-Host "Renamed $($folder.Name) to $newName"
}

Write-Host "All subfolders have been renamed."
