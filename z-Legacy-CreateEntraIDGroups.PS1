<#
.SYNOPSIS
This script creates Entra ID (Azure AD) groups based on entries from a CSV file.

.DESCRIPTION
The script reads a specified CSV file to create Entra ID groups. For each entry in the CSV, it creates three groups:
- <Entry>-StudentShareContributor
- <Entry>-StudentShareReader
- <Entry>-TeacherShareContributor

.PARAMETERS
-csvFilePath
  The path to the CSV file containing the entries for which groups will be created. This parameter is required.

.EXAMPLE
PS> .\CreateEntraIDGroups.ps1 -csvFilePath "C:\path\to\your\shares.csv"
  This command runs the script and creates the Entra ID groups based on the entries in the specified CSV file.

.NOTES
Before running this script, ensure you have the necessary permissions to create groups in Azure AD and that you are connected to your Azure account using `Connect-AzAccount`.

.AUTHOR
Lee Jolley

.DATE
31/5/2024

.USE RIGHTS POLICY
This script is provided under an open use policy. You are free to use, modify, and distribute this script in your own projects under the following conditions:
1. This policy text and credit to the original author must be retained in any versions or derivatives of the script.
2. Any improvements or modifications to this script should ideally be shared back with the community or made publicly available.
3. This script is provided "as is," without warranty of any kind, express or implied. In no event shall the author be liable for any claim, damages, or other liability arising from its use.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$csvFilePath
)

# Connect to Azure AD
Connect-AzAccount

# Import the CSV file
$entries = Import-Csv -Path $csvFilePath

# Create Entra ID groups
foreach ($entry in $entries) {
    $variable = $entry.ColumnA
    $studentShareContributor = "$variable-StudentShareContributor"
    $studentShareReader = "$variable-StudentShareReader"
    $teacherShareContributor = "$variable-TeacherShareContributor"

    New-AzADGroup -DisplayName $studentShareContributor -MailNickname $studentShareContributor -SecurityEnabled $true
    New-AzADGroup -DisplayName $studentShareReader -MailNickname $studentShareReader -SecurityEnabled $true
    New-AzADGroup -DisplayName $teacherShareContributor -MailNickname $teacherShareContributor -SecurityEnabled $true
}
