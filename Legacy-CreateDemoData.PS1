<#
.SYNOPSIS
This script recursively creates folders and subfolders, generates dummy files in each folder, and sets NTFS permissions at a specified level.

.DESCRIPTION
The script prompts the user for input parameters to define the number of root folders, recursion levels, subfolders per level, the level at which to change permissions, and the user account for permission changes. It then creates the folder structure, generates dummy files in each folder, and sets NTFS permissions for the specified user account at the specified recursion level.

.EXAMPLE
PS> .\CreateFoldersAndSetPermissions.ps1
  This command runs the script and prompts the user for input parameters to create the folder structure and set permissions.

.NOTES
The script performs the following actions:
1. Prompts the user for the number of root folders, recursion levels, subfolders per level, the level at which to change permissions, and the user account for permission changes.
2. Recursively creates folders and subfolders based on the input parameters.
3. Creates a dummy file named "DummyFile.txt" in each folder with the content "This is a dummy file".
4. Sets NTFS permissions for the specified user account at the specified recursion level.

.AUTHOR
Lee Jolley

.DATE
31/05/2024

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

# Function to create folders and subfolders recursively
function Create-Folders {
    param (
        [string]$basePath,
        [int]$levels,
        [int]$foldersPerLevel
    )

    if ($levels -le 0) {
        return
    }

    for ($i = 0; $i -lt $foldersPerLevel; $i++) {
        $folderPath = Join-Path -Path $basePath -ChildPath ("Folder" + $i)
        New-Item -ItemType Directory -Path $folderPath | Out-Null
        
        # Creating a dummy file in each folder
        $filePath = Join-Path -Path $folderPath -ChildPath "DummyFile.txt"
        New-Item -ItemType File -Path $filePath -Value "This is a dummy file" | Out-Null
        
        # Recursively create subfolders
        Create-Folders -basePath $folderPath -levels ($levels - 1) -foldersPerLevel $foldersPerLevel
    }
}

# Prompt user for input parameters
$rootFolders = Read-Host "Enter the number of root folders"
$recursionLevels = Read-Host "Enter the number of recursion levels for subfolders"
$subFolders = Read-Host "Enter the number of subfolders per level"
$changePermLevel = Read-Host "Enter the recursion level at which to change permissions"
$userAccount = Read-Host "Enter the user account for changing permissions"

# Main logic to create folders and set permissions
for ($j = 0; $j -lt $rootFolders; $j++) {
    $rootPath = Join-Path -Path $PWD -ChildPath ("RootFolder" + $j)
    New-Item -ItemType Directory -Path $rootPath | Out-Null
    Create-Folders -basePath $rootPath -levels $recursionLevels -foldersPerLevel $subFolders
    
    # Change permissions at the specified level
    if ($changePermLevel -le $recursionLevels) {
        $foldersToChange = Get-ChildItem -Path $rootPath -Recurse -Depth $changePermLevel | Where-Object { $_.PSIsContainer }
        foreach ($folder in $foldersToChange) {
            # Adding permission to the specified user
            $acl = Get-Acl -Path $folder.FullName
            $permission = "$userAccount", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $folder.FullName -AclObject $acl
        }
    }
}

Write-Host "Folders created and permissions set where specified."
