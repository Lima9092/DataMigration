# Function to check if the AzureAD or AzureAD.Standard.Preview module is installed and import the appropriate one
function Ensure-AzureADModule {
    # Determine the system architecture
    if ([System.Environment]::Is64BitProcess) {
        $architecture = "64-bit"
    } else {
        $architecture = "32-bit"
    }
    $outputTextbox.AppendText("Running on $architecture architecture.`n")
 
    # Try to import AzureAD module if available and compatible
    if (Get-Module -ListAvailable -Name AzureAD) {
        try {
            Import-Module AzureAD
            $outputTextbox.AppendText("AzureAD module imported successfully.`n")
            return
        } catch {
            $outputTextbox.AppendText("AzureAD module is not compatible with this architecture. Trying AzureAD.Standard.Preview...`n")
        }
    }
 
    # Try to import or install AzureAD.Standard.Preview module if AzureAD is not compatible
    if (-not (Get-Module -ListAvailable -Name AzureAD.Standard.Preview)) {
        $outputTextbox.AppendText("AzureAD.Standard.Preview module not found. Installing...`n")
        try {
            Install-Module -Name AzureAD.Standard.Preview -Force -AllowClobber -Scope CurrentUser
            $outputTextbox.AppendText("AzureAD.Standard.Preview module installed successfully.`n")
        } catch {
            $outputTextbox.AppendText("Failed to install AzureAD.Standard.Preview module. Please check your internet connection and try again.`n")
            exit
        }
    }
 
    try {
        Import-Module AzureAD.Standard.Preview
        $outputTextbox.AppendText("AzureAD.Standard.Preview module imported successfully.`n")
    } catch {
        $outputTextbox.AppendText("Failed to import any AzureAD module. Exiting...`n")
        exit
    }
}
 
# Add the necessary .NET types for manipulating the console window
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
 
        [DllImport("kernel32.dll", ExactSpelling = true)]
        public static extern IntPtr GetConsoleWindow();
    }
"@
 
# Minimize the PowerShell console window
$consoleWindow = [Win32]::GetConsoleWindow()
[void][Win32]::ShowWindow($consoleWindow, 6) # 6 = SW_MINIMIZE
 
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
 
# Create the Form
$form = New-Object system.Windows.Forms.Form
$form.Text = "Password Reset Tool"
$form.Size = New-Object System.Drawing.Size(500, 500)
$form.StartPosition = "CenterScreen"
 
# Create a Label for Site ID
$siteIdLabel = New-Object system.Windows.Forms.Label
$siteIdLabel.Location = New-Object System.Drawing.Point(10, 20)
$siteIdLabel.Size = New-Object System.Drawing.Size(120, 20)
$siteIdLabel.Text = "Site ID (3 characters):"
$form.Controls.Add($siteIdLabel)
 
# Create a TextBox for Site ID
$siteIdTextbox = New-Object system.Windows.Forms.TextBox
$siteIdTextbox.Location = New-Object System.Drawing.Point(150, 20)
$siteIdTextbox.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($siteIdTextbox)
 
# Create a Button to Select CSV File
$csvButton = New-Object system.Windows.Forms.Button
$csvButton.Location = New-Object System.Drawing.Point(10, 60)
$csvButton.Size = New-Object System.Drawing.Size(120, 30)
$csvButton.Text = "Select CSV File"
$form.Controls.Add($csvButton)
 
# Create a Label to Display Selected File
$fileLabel = New-Object system.Windows.Forms.Label
$fileLabel.Location = New-Object System.Drawing.Point(150, 65)
$fileLabel.Size = New-Object System.Drawing.Size(300, 20)
$form.Controls.Add($fileLabel)
 
# Create a Textbox for Output
$outputTextbox = New-Object system.Windows.Forms.TextBox
$outputTextbox.Location = New-Object System.Drawing.Point(10, 100)
$outputTextbox.Size = New-Object System.Drawing.Size(460, 300)
$outputTextbox.Multiline = $true
$outputTextbox.ScrollBars = "Vertical"
$outputTextbox.ReadOnly = $true
$form.Controls.Add($outputTextbox)
 
# Create an OpenFileDialog
$openFileDialog = New-Object system.Windows.Forms.OpenFileDialog
$openFileDialog.Filter = "CSV files (*.csv)|*.csv"
$openFileDialog.InitialDirectory = Get-Location
 
# Add Click Event for CSV Button
$csvButton.Add_Click({
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $fileLabel.Text = $openFileDialog.FileName
        $outputTextbox.AppendText("Selected CSV File: $($fileLabel.Text)`n")
    }
})
 
# Create a Button to Start the Process
$startButton = New-Object system.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(10, 420)
$startButton.Size = New-Object System.Drawing.Size(120, 30)
$startButton.Text = "Start"
$form.Controls.Add($startButton)
 
# Create a Help Button
$helpButton = New-Object system.Windows.Forms.Button
$helpButton.Location = New-Object System.Drawing.Point(350, 420)
$helpButton.Size = New-Object System.Drawing.Size(120, 30)
$helpButton.Text = "Help"
$form.Controls.Add($helpButton)
 
# Create an Exit Button
$exitButton = New-Object system.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(180, 420)
$exitButton.Size = New-Object System.Drawing.Size(120, 30)
$exitButton.Text = "Exit"
$form.Controls.Add($exitButton)
 
# Add Click Event for Help Button
$helpButton.Add_Click({
    $helpMessage = "Password Reset Tool Help:`n`n" +
                   "1. Site ID: Enter a 3-character Site ID for identification purposes.`n" +
                   "2. Select CSV File: Click the 'Select CSV File' button to choose the CSV file containing the UserIDs to be processed.`n" +
                   "   The CSV file must contain a single column of User IDs without any headers.`n" +
                   "3. Start: Click the 'Start' button to begin the process. The tool will reset passwords for the first occurrence of each User ID in Azure AD.`n" +
                   "   - If a User ID appears more than once in the CSV file, the password will only be reset for the first occurrence. Subsequent duplicates will be logged with a 'Duplicate' status.`n" +
                   "   - If the password does not meet Azure AD complexity requirements, the tool will log a 'Password Complexity Error' for that user.`n" +
                   "   - The final results, including any errors or duplicate entries, will be saved in a CSV file in the same directory as the input file.`n" +
                   "4. Output: The output box in the tool will display the progress and any errors encountered during the process. The final results will also be saved as a CSV file."
    [System.Windows.Forms.MessageBox]::Show($helpMessage, "Help")
})
 
# Add Click Event for Exit Button
$exitButton.Add_Click({
    $form.Close()
})
 
# Add Click Event for Start Button
$startButton.Add_Click({
    $siteId = $siteIdTextbox.Text
    $filePath = $fileLabel.Text
    if ($siteId.Length -ne 3) {
        [System.Windows.Forms.MessageBox]::Show("Site ID must be 3 characters long.")
        return
    }
    if (-not (Test-Path $filePath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid CSV file.")
        return
    }
 
    $outputTextbox.AppendText("Starting process...`n")
    # Ensure AzureAD or AzureAD.Standard.Preview module is installed and imported
    Ensure-AzureADModule
    # Import the CSV File without headers, assuming a single column of User IDs
    $users = Import-Csv -Path $filePath -Header "UserID"
    $outputTextbox.AppendText("Imported CSV file with $($users.Count) users.`n")
 
    # Connect to Azure AD
    $outputTextbox.AppendText("Connecting to Azure AD...`n")
    try {
        Connect-AzureAD
        $outputTextbox.AppendText("Connected to Azure AD successfully.`n")
    } catch {
        $outputTextbox.AppendText("Failed to connect to Azure AD: $_`n")
        return
    }
 
    # Create an array to store the results
    $results = @()
    # Create a hash table to track processed users
    $processedUserIds = @{}
 
    # Password generation function
    function Generate-Password($firstName, $surname) {
        # Ensure firstName and surname are not null or empty
        if ([string]::IsNullOrEmpty($firstName)) {
            $firstName = "X"
        }
        if ([string]::IsNullOrEmpty($surname)) {
            $surname = "xxx"
        }
        # Capital first initial
        $firstInitial = $firstName.Substring(0,1).ToUpper()
        # First 3 letters of surname in lowercase
        if ($surname.Length -ge 3) {
            $surnamePart = $surname.Substring(0,3).ToLower()
        } else {
            # If surname is less than 3 letters, pad with 'x'
            $surnamePart = $surname.ToLower().PadRight(3, 'x')
        }
        # Date in DDMM format
        $datePart = (Get-Date).ToString("ddMM")
        # Add '!'
        $specialChar = "!"
        # Build the password
        $password = $firstInitial + $surnamePart + $datePart + $specialChar
        return $password
    }
 
    # Loop through each user and reset the password or mark as duplicate
    foreach ($user in $users) {
        $userId = $user.UserID
        $status = "Account Not Found"
        $dateTimeNow = Get-Date
 
        if ($processedUserIds.ContainsKey($userId)) {
            # Handle duplicates
            $status = "Duplicate"
            $outputTextbox.AppendText("Duplicate found: $userId - Marking as Duplicate.`n")
 
            # Add the duplicate to the results array without changing the password
            $results += [PSCustomObject]@{
                "Site ID"   = $siteId
                "First Name" = ""
                "Surname"   = ""
                "UserID"    = $userId
                "Password"  = ""
                "Status"    = $status
                "Date"      = $dateTimeNow.ToString("dd/MM/yyyy")
                "Time"      = $dateTimeNow.ToString("HH:mm:ss")
            }
        } else {
            try {
                # Query Azure AD for user details
                $aadUser = Get-AzureADUser -ObjectId $userId
 
                if ($aadUser) {
                    # Determine if the account is enabled or disabled
                    $accountStatus = if ($aadUser.AccountEnabled) { "Enabled" } else { "Disabled" }
 
                    # Generate a unique password
                    $password = Generate-Password
 
                    # Create a secure string for the password
                    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
 
                    # Reset the user's password
                    Set-AzureADUserPassword -ObjectId $userId -Password $securePassword
 
                    # Update status to account status
                    $status = $accountStatus
 
                    # Add the user details to the results array
                    $results += [PSCustomObject]@{
                        "Site ID"   = $siteId
                        "First Name" = $aadUser.GivenName
                        "Surname"   = $aadUser.Surname
                        "UserID"    = $userId
                        "Password"  = $password
                        "Status"    = $status
                        "Date"      = $dateTimeNow.ToString("dd/MM/yyyy")
                        "Time"      = $dateTimeNow.ToString("HH:mm:ss")
                    }
 
                    # Update the output textbox
                    $outputTextbox.AppendText("Processed: $userId - Status: $status`n")
 
                    # Mark this user ID as processed
                    $processedUserIds[$userId] = $true
                }
            } catch {
                if ($_.Exception.Message -like "*password does not comply with password complexity requirements*") {
                    $status = "Password Complexity Error"
                    $outputTextbox.AppendText("Error: $userId - Password Complexity Error: $_`n")
                } else {
                    $status = "Account Not Found"
                    $outputTextbox.AppendText("Error: $userId - Status: Account Not Found`n")
                }
 
                # If an error occurs, log the UserID with the corresponding status
                $results += [PSCustomObject]@{
                    "Site ID"   = $siteId
                    "First Name" = ""
                    "Surname"   = ""
                    "UserID"    = $userId
                    "Password"  = ""
                    "Status"    = $status
                    "Date"      = $dateTimeNow.ToString("dd/MM/yyyy")
                    "Time"      = $dateTimeNow.ToString("HH:mm:ss")
                }
            }
        }
    }
 
    # Create a timestamp
    $timestamp = Get-Date -Format "ddMMyy-HHmm"
 
    # Export the results to a CSV file in the working directory
    $workingDirectory = Get-Location
    $exportFilePath = "$workingDirectory\$siteId-Passwords-$timestamp.csv"
    $results | Export-Csv -Path $exportFilePath -NoTypeInformation
 
    $outputTextbox.AppendText("Passwords have been reset and saved to $exportFilePath`n")
})
 
# Show the Form
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
 
# Restore the PowerShell console window when the form is closed
[Win32]::ShowWindowAsync($consoleWindow, 9) # 9 = SW_RESTORE
