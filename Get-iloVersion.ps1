Function Get-iloVersion {
    $iloVersionObject = get-wmiObject -class win32_bios | format-List -property embeddedcontroller*
    $iloVersionString = ($iloVersionObject | Format-Table | Out-String)
    $iloVersion = ""

    $iloVersionString = $iloVersionString.trim()
    $iloVersionArray = $iloVersionString.Split("`r`n")

    foreach ($line in $iloVersionArray)
    {

        if ( $line -like 'EmbeddedControllerMajorVersion*' ) { $tempString = $line; $tempString = $tempString.replace(" ","").replace("EmbeddedControllerMajorVersion:",""); $iloVersion+="$tempString."}
        elseif ($line -like 'EmbeddedControllerMinorVersion*' ) 
        {
            $tempString = $line
            $tempString = $tempString.replace(" ","").replace("EmbeddedControllerMinorVersion:","")
            if($tempString.Length -lt 2)
            {
                $tempString = "0$tempString"
            }
            $iloVersion+=$tempString
        }
    }

    return $iloVersion
}

try
{
    Get-iloVersion
}
catch
{
    write-host "KO"
}