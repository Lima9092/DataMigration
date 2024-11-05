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
$form.Text = "User Group Management Tool"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"

# Create a Label for Site ID
$siteIdLabel = New-Object system.Windows.Forms.Label
$siteIdLabel.Location = New-Object System.Drawing.Point(10, 20)
$siteIdLabel.Size = New-Object System.Drawing.Size(150, 20)
$siteIdLabel.Text = "Site ID (3 characters):"
$form.Controls.Add($siteIdLabel)

# Create a TextBox for Site ID
$siteIdTextbox = New-Object system.Windows.Forms.TextBox
$siteIdTextbox.Location = New-Object System.Drawing.Point(170, 20)
$siteIdTextbox.Size = New-Object System.Drawing.Size(60, 20)
$form.Controls.Add($siteIdTextbox)

# Create a GroupBox for Users section
$usersGroupBox = New-Object system.Windows.Forms.GroupBox
$usersGroupBox.Text = "Users"
$usersGroupBox.Location = New-Object System.Drawing.Point(10, 60)
$usersGroupBox.Size = New-Object System.Drawing.Size(300, 250)
$form.Controls.Add($usersGroupBox)

# Create a Button to Select Users CSV File within Users GroupBox
$usersCsvButton = New-Object system.Windows.Forms.Button
$usersCsvButton.Location = New-Object System.Drawing.Point(10, 20)
$usersCsvButton.Size = New-Object System.Drawing.Size(120, 30)
$usersCsvButton.Text = "Select Users CSV"
$usersGroupBox.Controls.Add($usersCsvButton)

# Create a Label to Display Selected Users File within Users GroupBox
$usersFileLabel = New-Object system.Windows.Forms.Label
$usersFileLabel.Location = New-Object System.Drawing.Point(10, 60)
$usersFileLabel.Size = New-Object System.Drawing.Size(280, 20)
$usersFileLabel.Text = "Selected File: users.csv"
$usersGroupBox.Controls.Add($usersFileLabel)

# Create a ListBox to Display Users within Users GroupBox
$usersListBox = New-Object system.Windows.Forms.ListBox
$usersListBox.Location = New-Object System.Drawing.Point(10, 90)
$usersListBox.Size = New-Object System.Drawing.Size(280, 140)
$usersListBox.HorizontalScrollbar = $true
$usersGroupBox.Controls.Add($usersListBox)

# Create a GroupBox for Groups section
$groupsGroupBox = New-Object system.Windows.Forms.GroupBox
$groupsGroupBox.Text = "Groups"
$groupsGroupBox.Location = New-Object System.Drawing.Point(330, 60)
$groupsGroupBox.Size = New-Object System.Drawing.Size(300, 250)
$form.Controls.Add($groupsGroupBox)

# Create a Button to Select Groups CSV File within Groups GroupBox
$groupsCsvButton = New-Object system.Windows.Forms.Button
$groupsCsvButton.Location = New-Object System.Drawing.Point(10, 20)
$groupsCsvButton.Size = New-Object System.Drawing.Size(120, 30)
$groupsCsvButton.Text = "Select Groups CSV"
$groupsGroupBox.Controls.Add($groupsCsvButton)

# Create a Label to Display Selected Groups File within Groups GroupBox
$groupsFileLabel = New-Object system.Windows.Forms.Label
$groupsFileLabel.Location = New-Object System.Drawing.Point(10, 60)
$groupsFileLabel.Size = New-Object System.Drawing.Size(280, 20)
$groupsFileLabel.Text = "Selected File: groups.csv"
$groupsGroupBox.Controls.Add($groupsFileLabel)

# Create a ListBox to Display Groups within Groups GroupBox
$groupsListBox = New-Object system.Windows.Forms.ListBox
$groupsListBox.Location = New-Object System.Drawing.Point(10, 90)
$groupsListBox.Size = New-Object System.Drawing.Size(280, 140)
$groupsListBox.SelectionMode = "MultiExtended"
$groupsListBox.HorizontalScrollbar = $true
$groupsGroupBox.Controls.Add($groupsListBox)

# Create Buttons for Add/Remove Users to/from Groups in a single row
$addSelectedButton = New-Object system.Windows.Forms.Button
$addSelectedButton.Location = New-Object System.Drawing.Point(10, 330)
$addSelectedButton.Size = New-Object System.Drawing.Size(180, 30)
$addSelectedButton.Text = "Add Users to Selected Groups"
$addSelectedButton.Enabled = $false
$form.Controls.Add($addSelectedButton)

$addAllButton = New-Object system.Windows.Forms.Button
$addAllButton.Location = New-Object System.Drawing.Point(200, 330)
$addAllButton.Size = New-Object System.Drawing.Size(180, 30)
$addAllButton.Text = "Add Users to All Groups"
$addAllButton.Enabled = $false
$form.Controls.Add($addAllButton)

$removeSelectedButton = New-Object system.Windows.Forms.Button
$removeSelectedButton.Location = New-Object System.Drawing.Point(390, 330)
$removeSelectedButton.Size = New-Object System.Drawing.Size(180, 30)
$removeSelectedButton.Text = "Remove Users from Selected Groups"
$removeSelectedButton.Enabled = $false
$form.Controls.Add($removeSelectedButton)

$removeAllButton = New-Object system.Windows.Forms.Button
$removeAllButton.Location = New-Object System.Drawing.Point(580, 330)
$removeAllButton.Size = New-Object System.Drawing.Size(180, 30)
$removeAllButton.Text = "Remove Users from All Groups"
$removeAllButton.Enabled = $false
$form.Controls.Add($removeAllButton)

# Create a Textbox for Output
$outputTextbox = New-Object system.Windows.Forms.TextBox
$outputTextbox.Location = New-Object System.Drawing.Point(10, 370)
$outputTextbox.Size = New-Object System.Drawing.Size(760, 140)
$outputTextbox.Multiline = $true
$outputTextbox.ScrollBars = "Vertical"
$outputTextbox.ReadOnly = $true
$form.Controls.Add($outputTextbox)

# Create Exit and Help buttons
$exitButton = New-Object system.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(600, 530)
$exitButton.Size = New-Object System.Drawing.Size(80, 30)
$exitButton.Text = "Exit"
$form.Controls.Add($exitButton)

$helpButton = New-Object system.Windows.Forms.Button
$helpButton.Location = New-Object System.Drawing.Point(690, 530)
$helpButton.Size = New-Object System.Drawing.Size(80, 30)
$helpButton.Text = "Help"
$form.Controls.Add($helpButton)

# Create an OpenFileDialog
$openFileDialog = New-Object system.Windows.Forms.OpenFileDialog
$openFileDialog.Filter = "CSV files (*.csv)|*.csv"
$openFileDialog.InitialDirectory = Get-Location

# Variables to store users and groups
$script:users = @()
$script:groups = @()

# Add Click Event for Users CSV Button
$usersCsvButton.Add_Click({
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $usersFileLabel.Text = $openFileDialog.FileName
        $outputTextbox.AppendText("Selected Users CSV File: $($usersFileLabel.Text)`n")
        $script:users = Import-Csv -Path $usersFileLabel.Text -Header "UserID"
        $outputTextbox.AppendText("Imported Users CSV with $($script:users.Count) users.`n")

        # Populate the users listbox
        $usersListBox.Items.Clear()
        foreach ($user in $script:users) {
            $usersListBox.Items.Add($user.UserID)
        }
    }
})

# Add Click Event for Groups CSV Button
$groupsCsvButton.Add_Click({
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $groupsFileLabel.Text = $openFileDialog.FileName
        $outputTextbox.AppendText("Selected Groups CSV File: $($groupsFileLabel.Text)`n")
        $script:groups = Import-Csv -Path $groupsFileLabel.Text -Header "GroupName"
        $outputTextbox.AppendText("Imported Groups CSV with $($script:groups.Count) groups.`n")
        $groupsListBox.Items.Clear()
        foreach ($group in $script:groups) {
            $groupsListBox.Items.Add($group.GroupName)
        }
        $addSelectedButton.Enabled = $true
        $addAllButton.Enabled = $true
        $removeSelectedButton.Enabled = $true
        $removeAllButton.Enabled = $true
    }
})


# Add Click Event for Help Button
$helpButton.Add_Click({
    $helpMessage = "User Group Management Tool Help:`n`n" +
                   "1. Site ID: Enter a 3-character Site ID for identification purposes.`n" +
                   "2. Select Users CSV: Click to choose the CSV file containing the UserIDs to be processed.`n" +
                   "   The CSV file must contain a single column of User IDs without any headers.`n" +
                   "3. Users List: The loaded users will be displayed in the listbox below.`n" +
                   "4. Select Groups CSV: Click to choose the CSV file containing the Group Names.`n" +
                   "   The CSV file must contain a single column of Group Names without any headers.`n" +
                   "5. Add/Remove Users to/from Groups:`n" +
                   "   - Use the buttons to add or remove users to/from selected or all groups.`n" +
                   "   - The output box will display the progress and any errors encountered.`n" +
                   "   - The final results, including any errors or entries not found, will be saved in a CSV file in the same directory as the input files.`n" +
                   "6. Output: The output box displays the progress and any errors encountered during the process. The final results are also saved as a CSV file."
    [System.Windows.Forms.MessageBox]::Show($helpMessage, "Help")
})

# Add Click Event for Exit Button
$exitButton.Add_Click({
    $form.Close()
})

# Function to connect to Azure AD
function Connect-ToAzureAD {
    $outputTextbox.AppendText("Connecting to Azure AD...`n")
    try {
        Connect-AzureAD
        $outputTextbox.AppendText("Connected to Azure AD successfully.`n")
    } catch {
        $outputTextbox.AppendText("Failed to connect to Azure AD: $_`n")
        return $false
    }
    return $true
}

# Function to process adding or removing users to/from groups
function Process-UsersGroups {
    param(
        [Parameter(Mandatory = $true)] [string]$Action, # "Add" or "Remove"
        [Parameter(Mandatory = $true)] [bool]$AllGroups
    )

    $siteId = $siteIdTextbox.Text

    if ($siteId.Length -ne 3) {
        [System.Windows.Forms.MessageBox]::Show("Site ID must be 3 characters long.")
        return
    }

    if ($script:users.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid Users CSV file.")
        return
    }

    if ($script:groups.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid Groups CSV file.")
        return
    }

    $selectedGroups = @()

    if ($AllGroups) {
        $selectedGroups = $script:groups.GroupName
    } else {
        if ($groupsListBox.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one group.")
            return
        }
        $selectedGroups = $groupsListBox.SelectedItems
    }

    $outputTextbox.AppendText("${Action} users to groups...`n")

    # Ensure AzureAD or AzureAD.Standard.Preview module is installed and imported
    Ensure-AzureADModule

    # Connect to Azure AD
    if (-not (Connect-ToAzureAD)) {
        return
    }

    # Create an array to store the results
    $results = @()

    # Loop through each user
    foreach ($user in $script:users) {
        $userId = $user.UserID
        $dateTimeNow = Get-Date
        try {
            # Get user object
            $aadUser = Get-AzureADUser -ObjectId $userId
            if (-not $aadUser) {
                throw "User Not Found"
            }
        } catch {
            $status = "User Not Found"
            $outputTextbox.AppendText("Error: $userId - $status`n")
            # Log the result
            $results += [PSCustomObject]@{
                "Site ID"    = $siteId
                "UserID"     = $userId
                "GroupName"  = ""
                "Action"     = $Action
                "Status"     = $status
                "Date"       = $dateTimeNow.ToString("dd/MM/yyyy")
                "Time"       = $dateTimeNow.ToString("HH:mm:ss")
            }
            continue
        }

        # Loop through each selected group
        foreach ($groupName in $selectedGroups) {
            try {
                # Get group object
                $aadGroup = Get-AzureADGroup -Filter "DisplayName eq '$groupName'"
                if (-not $aadGroup) {
                    throw "Group Not Found"
                }

                # Check if user is already a member of the group
                $isMember = Get-AzureADGroupMember -ObjectId $aadGroup.ObjectId -All $true | Where-Object { $_.ObjectId -eq $aadUser.ObjectId }

                if ($Action -eq "Add") {
                    if (-not $isMember) {
                        # Add user to group
                        Add-AzureADGroupMember -ObjectId $aadGroup.ObjectId -RefObjectId $aadUser.ObjectId
                        $status = "Added"
                    } else {
                        $status = "Already a member"
                    }
                } elseif ($Action -eq "Remove") {
                    if ($isMember) {
                        # Remove user from group
                        Remove-AzureADGroupMember -ObjectId $aadGroup.ObjectId -MemberId $aadUser.ObjectId
                        $status = "Removed"
                    } else {
                        $status = "Not a member"
                    }
                }
                $outputTextbox.AppendText("${Action}: $userId - Group: $groupName - $status`n")
            } catch {
                $status = $_.Exception.Message
                $outputTextbox.AppendText("Error: $userId - Group: $groupName - $status`n")
            }

            # Log the result
            $results += [PSCustomObject]@{
                "Site ID"    = $siteId
                "UserID"     = $userId
                "GroupName"  = $groupName
                "Action"     = $Action
                "Status"     = $status
                "Date"       = $dateTimeNow.ToString("dd/MM/yyyy")
                "Time"       = $dateTimeNow.ToString("HH:mm:ss")
            }
        }
    }

    # Create a timestamp
    $timestamp = Get-Date -Format "ddMMyy-HHmm"

    # Export the results to a CSV file in the working directory
    $workingDirectory = Get-Location
    $exportFilePath = "$workingDirectory\$siteId-UserGroup-$Action-$timestamp.csv"
    $results | Export-Csv -Path $exportFilePath -NoTypeInformation

    $outputTextbox.AppendText("Process completed. Results saved to $exportFilePath`n")
}

# Add Click Events for Add/Remove Buttons
$addSelectedButton.Add_Click({
    Process-UsersGroups -Action "Add" -AllGroups $false
})

$addAllButton.Add_Click({
    Process-UsersGroups -Action "Add" -AllGroups $true
})

$removeSelectedButton.Add_Click({
    Process-UsersGroups -Action "Remove" -AllGroups $false
})

$removeAllButton.Add_Click({
    Process-UsersGroups -Action "Remove" -AllGroups $true
})

# Show the Form
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

# Restore the PowerShell console window when the form is closed
[Win32]::ShowWindowAsync($consoleWindow, 9) # 9 = SW_RESTORE
