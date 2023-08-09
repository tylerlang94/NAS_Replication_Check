# This looks complicated but its not
# It just compares the hashes of two file
# to see if they matc, proof that replication is working
# the file mts.replication_test

# It does have some fancy stuff to avoid issue if access isn't
# working AND avoid double runs, or filling the host with log files

# RMM alerting is going to read the CC_output to be sure
# it is never more then 24 hours old.

# Cool off gets use our window we WANT to know when replication
# is work, lets adjustment for perhaps 1 failed replication
# job that then next round gets files

# THIS IS A GENERAL TEST - THAT SOME LEVEL OF REPLICATION IS COMPLETEING

# STILL NEED TO FIGURE OUT A WAY TO READ ALERTS FROM NAS

#The Check file needs to be at least this old.
$AlertCoolOffMinutes=1200

$CheckTime=Get-Date

$output_str=$null
$CC_output="path\to\outputlog"
$nas_cast_file="\\path\to\nas\file"
$nas_check_file="\\path\to\nas\file"
$CompanyName = "CompanyName"
# Creates the event Source if it doesn't exist
if ([System.Diagnostics.EventLog]::SourceExists($CompanyName) -eq $False) {
    New-EventLog -LogName Application -Source $ComputerName
}

function Write-EventLog10000 {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)]
        [string]$Message
    )
    Write-EventLog -LogName Application -Source $CompanyName -EventId 10000 -EntryType Information -Message $Message
}

function Write-EventLog10001 {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)]
        [string]$Message
    )
    Write-EventLog -LogName Application -Source $CompanyName -EventId 10001 -EntryType Information -Message $Message
}

# We should always have access to both NAS files, let check them out and alert if not
try {
    $nas_cast_file_acces = Test-Path -Path $nas_cast_file -PathType Leaf
    write-host Access to Boise NAS, $nas_cast_file_acces
} catch {
    Write-EventLog10001 -Message "Unable to access NAS at ip1. This may be a network or permissions issue."
}

try {
    $nas_check_file_access = Test-Path -Path $nas_check_file -PathType Leaf
    write-host Access to MSP NAS, $nas_check_file_access
} catch {
        Write-EventLog10001 -Message "Unable to access NAS at ip2. This may be a network or permissions issue."
}


if ( $nas_check_file_access -AND $nas_cast_file_acces ) {

    write-host "File access to both test files exist, proceeding"

    # Let see if we are inside the cool off window
    write-host $AlertCoolOffMinutes
    ((Get-Date) - (Get-ChildItem -Path $nas_cast_file).LastWriteTime).TotalMinutes

    if ((((Get-Date) - (Get-ChildItem -Path $nas_cast_file).LastWriteTime).TotalMinutes) -gt $AlertCoolOffMinutes) {

        # Check if hash match, we are outside the cool down window
    
        If ((Get-FileHash $nas_cast_file).hash -eq (Get-FileHash $nas_check_file).hash) {
        
            $output_str = "Replication is working, hashes match"
            Write-host $output_str
            write-host "Randomizing far side file"
            Get-Random | Out-File $nas_cast_file
            Write-EventLog10000 -Message "Replication is working. The Hashes at both ends match. Randomizing the Far side complete"

        } else {
                
            $output_str = "Replication NOT working, hashes are different"
            Write-host $output_str
            Write-EventLog10001 -Message "Replication is not working, the hashes are different"

        }

    } else {

        $output_str = "still inside the cool off window, exiting"
        write-host $output_str
        Write-EventLog10000 -Message "Still inside the cool off windows"
    }
   
} else {

    $output_str = "NOT able to access test files, exiting"
    write-host $output_str
    Write-EventLog10001 -Message "Not able to access the files exiting"
}

$output_str = $CheckTime.ToString() + " : " + $output_str
$output_str | Out-File $CC_output


# Check 24 hours stale backup
# need alert if hasnt completed in 24 hours
