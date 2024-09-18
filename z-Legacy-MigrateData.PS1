<#
.SYNOPSIS
This script performs a Robocopy operation from a specified source directory to a destination directory, logging the results with a timestamped log file name.

.DESCRIPTION
The script requires a user to set the source and destination directories and define the time limits for the Robocopy operation. It then runs the Robocopy command with specified parameters and logs the results to the generated log file.

.EXAMPLE
PS> .\RunRobocopy.ps1
  Edit the Source and Destination section in the script. This command runs the script, performing the Robocopy operation from the predefined source to the destination directory, logging the output with a timestamped log file name.

.NOTES
The script sets the following Robocopy parameters:
- /E : Copies all subdirectories, including empty ones.
- /COPY:DAT : Copies Data, Attributes, and Timestamps.
- /MIR : Mirrors the directory tree, including deletions.
- /RH:1900-0700 : Specifies the time window for running the copy operation.
- /DCOPY:DAT : Copies directory Data, Attributes, and Timestamps.
- /R:10 : Retries 10 times on failed copies.
- /W:5 : Waits 5 seconds between retries.
- /V : Produces verbose output.
- /LOG : Logs the output to the specified file.
- /TEE : Writes the output to the console window and the log file.

The log file is named using the format: robocopy_<source>_<destination>_<timestamp>.log

.AUTHOR
Lee Jolley

.DATE
21/06/2024

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

# Set source and destination variables
$source = "C:\scripts\source"
$destination = "C:\scripts\destination"

# Set time limits
$startTime = "1900"
$endTime = "0700"

# Get current date and time
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm"

# Format log file name
$sourceFormatted = $source -replace "[:\\]", "-"
$destinationFormatted = $destination -replace "[:\\]", "-"
$logFile = "robocopy_${sourceFormatted}_${destinationFormatted}_${currentDateTime}.log"

# Run robocopy with the formatted log file name
Start-Process robocopy -ArgumentList "$source $destination /E /COPY:DAT /MIR /RH:$startTime-$endTime /DCOPY:DAT /R:10 /W:5 /V /LOG:`"$logFile`" /TEE" -NoNewWindow -Wait

# Display the path to the log file
Write-Output "Robocopy log: $logFile"
