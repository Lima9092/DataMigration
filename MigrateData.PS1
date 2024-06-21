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
