Function Get-biosVersion {
    $biosVersionObject = get-wmiObject -class win32_bios | format-List -property systembios*
    $biosVersionString = ($biosVersionObject | Format-Table | Out-String)
    $biosVersion = ""

    $biosVersionString = $biosVersionString.trim()
    $biosVersionArray = $biosVersionString.Split("`r`n")

    foreach ($line in $biosVersionArray)
    {

        if ( $line -like 'SystemBiosMajorVersion*') { $tempString = $line; $tempString = $tempString.replace(" ","").replace("SystemBiosMajorVersion:",""); $biosVersion+="$tempString."}
        elseif ( $line -like 'SystemBiosMinorVersion*') { $tempString = $line; $tempString = $tempString.replace(" ","").replace("SystemBiosMinorVersion:","");$biosVersion+=$tempString}
    }

    return $biosVersion
}

try
{
    Get-BiosVersion
}
catch
{
    write-host "KO"
}