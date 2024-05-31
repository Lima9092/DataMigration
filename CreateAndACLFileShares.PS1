<#
.SYNOPSIS
This script creates Azure File Shares and applies permissions based on entries from a CSV file.

.DESCRIPTION
The script reads a specified CSV file to create Azure File Shares and apply permissions. For each entry in the CSV, it creates two shares:
- <Entry>-StudentShare
  - Grants <Entry>-StudentShareContributor group "Storage File Data SMB Share Contributor" role
  - Grants <Entry>-StudentShareReader group "Storage File Data SMB Share Reader" role
- <Entry>-TeacherShare
  - Grants <Entry>-TeacherShareContributor group "Storage File Data SMB Share Contributor" role

.PARAMETERS
-csvFilePath
  The path to the CSV file containing the entries for which shares and permissions will be created. This parameter is required.
-resourceGroupName
  The name of the resource group containing the storage account. This parameter is required.
-storageAccountName
  The name of the storage account where the shares will be created. This parameter is required.

.EXAMPLE
PS> .\CreateAndACLFileShares.ps1 -csvFilePath "C:\path\to\your\shares.csv" -resourceGroupName "YourResourceGroup" -storageAccountName "YourStorageAccount"
  This command runs the script and creates Azure File Shares with permissions based on the entries in the specified CSV file.

.NOTES
Before running this script, ensure you have the necessary permissions to create file shares and assign roles in Azure and that you are connected to your Azure account using `Connect-AzAccount`.

.AUTHOR
Lee Jolley

.DATE
31/05/2024

.USE RIGHTS POLICY
This script is provided under an open use policy. You are free to use, modify, and distribute this script in your own projects under the following conditions:
1. This policy text and credit to the original author must be retained in any versions or derivatives of the script.
2. Any improvements or modifications to this script should ideally be shared back with the community or made publicly available.
3. This script is provided "as is," without warranty of any kind, express or implied. In no event shall the author be liable for any claim, damages, or other liability arising from its use.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$csvFilePath,
    [Parameter(Mandatory = $true)]
    [string]$resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$storageAccountName
)

# Connect to Azure
Connect-AzAccount

# Import the CSV file
$entries = Import-Csv -Path $csvFilePath
$subscriptionId = (Get-AzSubscription).Id

# Create Azure File Shares and set permissions
foreach ($entry in $entries) {
    $variable = $entry.ColumnA
    $studentShare = "$variable-StudentShare"
    $teacherShare = "$variable-TeacherShare"

    # Create file shares
    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]
    New-AzStorageShare -Name $studentShare -Context $storageContext
    New-AzStorageShare -Name $teacherShare -Context $storageContext

    # Get the group object IDs
    $studentShareContributorGroup = Get-AzADGroup -SearchString "$variable-StudentShareContributor"
    $studentShareReaderGroup = Get-AzADGroup -SearchString "$variable-StudentShareReader"
    $teacherShareContributorGroup = Get-AzADGroup -SearchString "$variable-TeacherShareContributor"

    # Set permissions for StudentShare
    New-AzRoleAssignment -ObjectId $studentShareContributorGroup.Id -RoleDefinitionName "Storage File Data SMB Share Contributor" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$studentShare"
    New-AzRoleAssignment -ObjectId $studentShareReaderGroup.Id -RoleDefinitionName "Storage File Data SMB Share Reader" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$studentShare"

    # Set permissions for TeacherShare
    New-AzRoleAssignment -ObjectId $teacherShareContributorGroup.Id -RoleDefinitionName "Storage File Data SMB Share Contributor" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/fileServices/default/shares/$teacherShare"
}
