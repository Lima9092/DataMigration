# Connect to Azure
Connect-AzAccount

# Import the CSV file
$csvFilePath = "path\to\your\shares.csv"  # Update with your CSV file path
$entries = Import-Csv -Path $csvFilePath

# Azure storage account credentials
$resourceGroupName = "your_resource_group_name"  # Update with your resource group name
$storageAccountName = "your_storage_account_name"  # Update with your storage account name

# Create Azure File Shares and set permissions
foreach ($entry in $entries) {
    $variable = $entry.ColumnA
    $studentShare = "$variable-StudentShare"
    $teacherShare = "$variable-TeacherShare"

    # Create file shares
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
