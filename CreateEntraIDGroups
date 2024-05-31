# Connect to Azure AD
Connect-AzAccount

# Import the CSV file
$csvFilePath = "path\to\your\shares.csv"  # Update with your CSV file path
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
