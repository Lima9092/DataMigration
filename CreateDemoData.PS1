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
