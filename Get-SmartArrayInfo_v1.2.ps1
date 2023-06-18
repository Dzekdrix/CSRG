#Controle et création de la clé supervision si nécessaire$check_regkey = Get-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\GenApi\Supervision" -ErrorAction SilentlyContinue
if (!$check_regkey) {
                    New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\GenApi\Supervision" | Out-Null
                    }

$check_regkey = Get-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\GenApi\Supervision\SmartArrayInfo" -ErrorAction SilentlyContinue
if (!$check_regkey) {
                    New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\GenApi\Supervision\SmartArrayInfo" | Out-Null
                    }

$RegLogPath = "HKLM:\SOFTWARE\GenApi\Supervision\SmartArrayInfo"

$check_SmartArrayFirmwareVersion = Get-ItemProperty -Path $RegLogPath -Name SmartArrayFirmwareVersion -ErrorAction SilentlyContinue
if (!$check_SmartArrayFirmwareVersion) {
                            New-ItemProperty -Path $RegLogPath -Name SmartArrayFirmwareVersion -PropertyType String | Out-Null
                            }

$check_PhysicalDiskDetail = Get-ItemProperty -Path $RegLogPath -Name PhysicalDiskDetail -ErrorAction SilentlyContinue
if (!$check_PhysicalDiskDetail) {
                            New-ItemProperty -Path $RegLogPath -Name PhysicalDiskDetail -PropertyType String | Out-Null
                            }

$check_NumberOfActiveSmartArray = Get-ItemProperty -Path $RegLogPath -Name NumberOfActiveSmartArray -ErrorAction SilentlyContinue
if (!$check_NumberOfActiveSmartArray) {
                            New-ItemProperty -Path $RegLogPath -Name NumberOfActiveSmartArray -PropertyType String | Out-Null
                            }

$check_MediaErrors = Get-ItemProperty -Path $RegLogPath -Name MediaErrors -ErrorAction SilentlyContinue
if (!$check_MediaErrors) {
                            New-ItemProperty -Path $RegLogPath -Name MediaErrors -PropertyType String | Out-Null
                            }

# Function #

#Get-Storage-Executable-Path : Controle de la présence de l'outils SSACLI
#Get-SlotNumber : Récupère le numéro de Slot utilisé par le SmartArray 
#Count-SmartArray : Compte les controlleurs actifs
#Read-HPSmartArrayFirmware : Récupération des information sur le SmartArray
#Read-HPDiskModelNumber : Récupération des information sur les disques physiques
#Get-MediaErrors : Controle de la présence de "Unrecoverable Media Errors" sur les unités logiques


Function Get-Storage-Executable-Path () {
    $programPaths = (
    	'C:\Program Files\HP\HPSSACLI\bin\hpssacli.exe',
        'C:\Program Files\HP\HPACUCLI\Bin\hpacucli.exe',
        'C:\Program Files\Compaq\HPACUCLI\Bin\hpacucli.exe',
        'C:\Program Files (x86)\HP\HPACUCLI\Bin\hpacucli.exe',
        'C:\Program Files (x86)\Compaq\HPACUCLI\Bin\hpacucli.exe',
        'c:\Program Files\Smart Storage Administrator\ssacli\bin\ssacli.exe'
    );
    
    foreach ($path in $programPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $false
}

Function Get-SlotNumber ($buffer){


	foreach ($line in $buffer)
	{     
		$line = $line.trim()

        if ($line -like "Slot:*")
            {                
            $return = $line.substring($line.length -1)
            }
       }
    return $return 
    }

Function Count-SmartArray ($buffer){

    $i = 0
	foreach ($line in $buffer)
	{     
		$line = $line.trim()

        if ($line -like "*Smart Array*")
            {                
            $i++
            }
       }
    return $i
    }

Function Read-HPSmartArrayFirmware ($buffer){


	foreach ($line in $buffer)
	{
		$line = $line.trim()


        if ($line -like "*Smart Array*")
        {
        #Write-Host $line -ForegroundColor Gray	
        $return = $return+$line+","
        } 

        if ($line -like "Firmware Version:*")
        {
        #Write-Host $line -ForegroundColor Gray	
        $return = $return+$line.Replace("Firmware Version: ","")+";"       
        } 
    }
    return $return 
    }

Function Read-HPDiskModelNumber ($buffer){


	foreach ($line in $buffer)
	{     
		$line = $line.trim()

        if ($line -like "physicaldrive *")
            {                
            $return = $return+$line+","
            }
        if ($line -like "Firmware Revision:*")
            {
            $return = $return+$line.Replace("Firmware Revision: ","")+","
            }
        if ($line -like "Serial Number:*")
            {
            $return = $return+$line.Replace("Serial Number: ","")+","
            }
        if ($line -like "Model:*")
            {
            $return = $return+$line+";"
            }
    }
    return $return 
    }

Function Get-MediaErrors  ($buffer){


	foreach ($line in $buffer)
	{     
		$line = $line.trim()

        if ($line -like "Warning: Unrecoverable Media Errors*")
            {                            
            $tampon = $tampon+$line
            }
        if ($tampon -ne $Null -and $line -notlike "Bus Interface:*"  ) 
             {
             $tampon = $tampon+$line
             }
        if ($line -like "Bus Interface:*")
            {
            break
            }
       }

    if ($tampon -like "Warning: Unrecoverable Media Errors*")
        {
        $Separteur = ": ","."
        $option = [System.StringSplitOptions]::RemoveEmptyEntries
        $LogicalDriveId = $($tampon.Split($Separteur,$option))[-1]
        $return = "Unrecoverable Media Errors;$LogicalDriveId"
        }
    else
        {
        $return = "No unrecoverable Media Errors"
        }
    return $return 
    }




## Core ###

$prg = Get-Storage-Executable-Path
$NoSSACLI = "Cannot find SSACLI"
if ($prg -eq $false) {
    #Write-Host "DOH! Cannot find ProLiant Array Configuration Utility or Smart Storage Administrator on this computer."
    Set-ItemProperty -Path $RegLogPath -Name SmartArrayFirmwareVersion -Value $NoSSACLI
    exit 3
}



#Write-Host " "

$SmartArrayDetail = & $prg 'ctrl all show detail'
$Slot = Get-SlotNumber $SmartArrayDetail
Write-host "Slot : $slot"

$NumberOfActiveSmartArray = Count-SmartArray $SmartArrayDetail
Write-host "Nombre de controlleur actif : $NumberOfActiveSmartArray"
Set-ItemProperty -Path $RegLogPath -Name NumberOfActiveSmartArray -Value $NumberOfActiveSmartArray


$SmartArrayFirmwareVersion = Read-HPSmartArrayFirmware $SmartArrayDetail

Write-Host "Contenu de la valeur de registre SmartArray :" -ForegroundColor gray
Write-Host $SmartArrayFirmwareVersion -ForegroundColor Red
Set-ItemProperty -Path $RegLogPath -Name SmartArrayFirmwareVersion -Value $SmartArrayFirmwareVersion

Write-Host " "

$DiskDetail = & $prg ctrl slot=$Slot pd all show detail
$PhysicalDiskDetail = Read-HPDiskModelNumber $DiskDetail

Write-Host "Contenu de la valeur de registre PhysicalDrive :" -ForegroundColor gray
Write-Host $PhysicalDiskDetail -ForegroundColor Red

Set-ItemProperty -Path $RegLogPath -Name PhysicalDiskDetail -Value $PhysicalDiskDetail

$MediaErrors = Get-MediaErrors $SmartArrayDetail
Set-ItemProperty -Path $RegLogPath -Name MediaErrors -Value $MediaErrors