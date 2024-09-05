# Minimize PowerShell window
$psWindow = (Get-Process -Id $PID).MainWindowHandle
if ($psWindow -ne [IntPtr]::Zero) {
    $ShowWindowAsync = Add-Type -MemberDefinition @"
        [DllImport("user32.dll")] 
        public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru
    $ShowWindowAsync::ShowWindowAsync($psWindow, 2) # 2 minimizes the window
}

# Load necessary assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Create the main window
$window = New-Object System.Windows.Window
$window.Title = "CSV Editor"
$window.Width = 800
$window.Height = 600
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "CanResize"
$window.WindowState = "Normal"

# Create a Grid layout to arrange the ribbon and DataGrid vertically
$mainGrid = New-Object System.Windows.Controls.Grid

# Create row definitions for the grid
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))  # Ribbon
$mainGrid.RowDefinitions[0].Height = "Auto"
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))  # DataGrid
$mainGrid.RowDefinitions[1].Height = "*"

# Create a toolbar-like area (ribbon) at the top
$ribbonPanel = New-Object System.Windows.Controls.StackPanel
$ribbonPanel.Orientation = "Horizontal"
$ribbonPanel.Height = 40
$ribbonPanel.HorizontalAlignment = "Stretch"
$ribbonPanel.VerticalAlignment = "Top"
$ribbonPanel.Margin = "0,0,0,0"

# Create buttons for the ribbon
$openFileButton = New-Object System.Windows.Controls.Button
$openFileButton.Content = "Open CSV"
$openFileButton.Width = 80
$openFileButton.Height = 30
$openFileButton.Margin = "5,5,5,5"

$saveButton = New-Object System.Windows.Controls.Button
$saveButton.Content = "Save CSV"
$saveButton.Width = 80
$saveButton.Height = 30
$saveButton.Margin = "5,5,5,5"

$copyButton = New-Object System.Windows.Controls.Button
$copyButton.Content = "Copy"
$copyButton.Width = 80
$copyButton.Height = 30
$copyButton.Margin = "5,5,5,5"

$exitButton = New-Object System.Windows.Controls.Button
$exitButton.Content = "Exit"
$exitButton.Width = 80
$exitButton.Height = 30
$exitButton.Margin = "5,5,5,5"

# Labels for stats
$linesLabel = New-Object System.Windows.Controls.TextBlock
$linesLabel.Text = "Lines: 0"
$linesLabel.Margin = "20,5,5,5"

$fileSizeLabel = New-Object System.Windows.Controls.TextBlock
$fileSizeLabel.Text = "File Size: 0 KB"
$fileSizeLabel.Margin = "20,5,5,5"

# Add buttons and stats to the ribbon
$ribbonPanel.Children.Add($openFileButton)
$ribbonPanel.Children.Add($saveButton)
$ribbonPanel.Children.Add($copyButton)
$ribbonPanel.Children.Add($exitButton)
$ribbonPanel.Children.Add($linesLabel)
$ribbonPanel.Children.Add($fileSizeLabel)

# Add ribbon to the top row of the Grid
$mainGrid.Children.Add($ribbonPanel)
[System.Windows.Controls.Grid]::SetRow($ribbonPanel, 0)

# Create a DataGrid to display and edit the CSV content
$dataGrid = New-Object System.Windows.Controls.DataGrid
$dataGrid.AutoGenerateColumns = $false  # Disable auto-generation of columns
$dataGrid.IsReadOnly = $false  # Allow editing of cells
$dataGrid.HorizontalScrollBarVisibility = "Auto"
$dataGrid.VerticalScrollBarVisibility = "Auto"
$dataGrid.CanUserResizeColumns = $true
$dataGrid.CanUserSortColumns = $true
$dataGrid.SelectionUnit = "Cell"
$dataGrid.SelectionMode = "Extended"
$dataGrid.Margin = "0,0,0,0"

# Add the DataGrid to the second row of the Grid
$mainGrid.Children.Add($dataGrid)
[System.Windows.Controls.Grid]::SetRow($dataGrid, 1)

# Set the main window content to the Grid
$window.Content = $mainGrid

# Variable to store the current file path
$currentFile = $null

# Function to open and load the CSV file directly into the DataGrid
function Open-CSVFile {
    $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
    $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
    $openFileDialog.ShowDialog() | Out-Null
    $fileName = $openFileDialog.FileName

    if ($fileName) {
        # Store the file path for saving later
        $global:currentFile = $fileName

        # Manually read the first line of the file to get the headers in order
        $csvLines = Get-Content -Path $fileName
        if ($csvLines.Count -eq 0) {
            [System.Windows.MessageBox]::Show("The file is empty!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        $headers = $csvLines[0] -split ','

        # Load the CSV into the DataGrid by converting each row into a hashtable
        $csvData = Import-Csv $fileName
        if ($csvData.Count -eq 0) {
            [System.Windows.MessageBox]::Show("The CSV file has no data!", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }

        $convertedData = @()
        foreach ($row in $csvData) {
            $hashtable = @{}
            foreach ($column in $row.PSObject.Properties) {
                $hashtable[$column.Name] = $column.Value
            }
            $convertedData += [pscustomobject]$hashtable
        }

        # Create columns explicitly in the order from the CSV file's headers
        $dataGrid.Columns.Clear()
        foreach ($header in $headers) {
            $gridColumn = New-Object System.Windows.Controls.DataGridTextColumn
            $gridColumn.Header = $header
            $gridColumn.Binding = New-Object System.Windows.Data.Binding $header
            $dataGrid.Columns.Add($gridColumn)
        }

        # Bind the converted data to the DataGrid
        $dataGrid.ItemsSource = $convertedData
        
        # Update stats
        $linesLabel.Text = "Lines: $($csvData.Count)"
        $fileSize = [math]::Round((Get-Item $fileName).Length / 1KB, 2)
        $fileSizeLabel.Text = "File Size: $fileSize KB"
    }
}

# Function to save the CSV file
function Save-CSVFile {
    if ($currentFile -ne $null) {
        # Get the data from the DataGrid
        $csvData = $dataGrid.ItemsSource

        # Convert the data back into CSV format
        $csvLines = @()
        $headers = ($csvData[0].PSObject.Properties.Name) -join ","
        $csvLines += $headers

        foreach ($row in $csvData) {
            $csvLines += ($row.PSObject.Properties.Value) -join ","
        }

        # Save the CSV back to the original file
        Set-Content -Path $currentFile -Value $csvLines
    }
}

# Copy selected data
function Copy-SelectedData {
    $selectedCells = $dataGrid.SelectedCells
    if ($selectedCells.Count -gt 0) {
        $headers = ($dataGrid.Columns | ForEach-Object { $_.Header.ToString() }) -join ","
        $copyText = $headers + "`n"

        # Process selected cells by row
        $rowDataMap = @{}
        foreach ($cell in $selectedCells) {
            # Use the unique row object itself as the key
            $rowKey = $cell.Item

            if (-not $rowDataMap.ContainsKey($rowKey)) {
                $rowDataMap[$rowKey] = @{}
            }
            $rowDataMap[$rowKey][$cell.Column.Header.ToString()] = $cell.Item.$($cell.Column.Header.ToString())
        }

        # Convert row data into CSV format
        foreach ($row in $rowDataMap.Values) {
            $rowData = @()
            foreach ($col in $dataGrid.Columns) {
                $header = $col.Header.ToString()
                $rowData += if ($row.ContainsKey($header)) { $row[$header] } else { "" }
            }
            $copyText += ($rowData -join ",") + "`n"
        }

        # Set the copied text to the clipboard
        [System.Windows.Clipboard]::SetText($copyText.TrimEnd("`n"))
    }
}

# Button click events
$openFileButton.Add_Click({ Open-CSVFile })
$saveButton.Add_Click({ Save-CSVFile })
$copyButton.Add_Click({ Copy-SelectedData })
$exitButton.Add_Click({ $window.Close() })

# Show the window
$window.ShowDialog()
