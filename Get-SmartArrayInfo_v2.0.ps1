#Controle et création de la clé supervision si nécessaire$check_regkey = Get-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\GenApi\Supervision" -ErrorAction SilentlyContinue
if (!$check_regkey) {
                    New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\GenApi\Supervision" | Out-Null
                    }

$check_regkey = Get-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\GenApi\Supervision\ControllerInfo" -ErrorAction SilentlyContinue
if (!$check_regkey) {
                    New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\GenApi\Supervision\ControllerInfo" | Out-Null
                    }

$RegLogPath = "HKLM:\SOFTWARE\GenApi\Supervision\SmartArrayInfo"

$check_ControllerFirmwareVersion = Get-ItemProperty -Path $RegLogPath -Name ControllerFirmwareVersion -ErrorAction SilentlyContinue
if (!$check_ControllerFirmwareVersion) {
                            New-ItemProperty -Path $RegLogPath -Name ControllerFirmwareVersion -PropertyType String | Out-Null
                            }

$check_PhysicalDiskDetail = Get-ItemProperty -Path $RegLogPath -Name PhysicalDiskDetail -ErrorAction SilentlyContinue
if (!$check_PhysicalDiskDetail) {
                            New-ItemProperty -Path $RegLogPath -Name PhysicalDiskDetail -PropertyType String | Out-Null
                            }

$check_NumberOfActiveController = Get-ItemProperty -Path $RegLogPath -Name NumberOfActiveController -ErrorAction SilentlyContinue
if (!$check_NumberOfActiveController) {
                            New-ItemProperty -Path $RegLogPath -Name NumberOfActiveController -PropertyType String | Out-Null
                            }

$check_MediaErrors = Get-ItemProperty -Path $RegLogPath -Name MediaErrors -ErrorAction SilentlyContinue
if (!$check_MediaErrors) {
                            New-ItemProperty -Path $RegLogPath -Name MediaErrors -PropertyType String | Out-Null
                            }

# Function #

#Get-Storage-Executable-Path : Controle de la présence de l'outils SSACLI
#Get-SlotNumber : Récupère le numéro de Slot utilisé par le Controller 
#Count-Controller : Compte les controlleurs actifs
#Read-HPControllerFirmware : Récupération des information sur le Controller
#Read-HPDiskModelNumber : Récupération des information sur les disques physiques
#Get-MediaErrors : Controle de la présence de "Unrecoverable Media Errors" sur les unités logiques


Function Get-Storage-Executable-Path () {
    $programPaths = (
        'C:\Program Files\Hewlett Packard Enterprise\RESTful Interface Tool\ilorest.exe',
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

Function Count-Controller ($buffer){

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

Function Read-HPControllerFirmware ($buffer){


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

function get-controllers {
    param(
        [Parameter()]
        [string]$iloRestExePath = 'C:\Program Files\Hewlett Packard Enterprise\RESTful Interface Tool\ilorest.exe'
    )
    & $iloRestExePath select PCIeDevice.v1_5_0 | out-null
    $PCIDevicesJSON = & $iloRestExePath list -j 
    $PCIDevices = $PCIDevicesJSON | ConvertFrom-Json
    $controllers = @()
    $controller = New-Object -TypeName PSCustomObject
    foreach($PCIDevice in $PCIDevices)
    {
        if($PCIDevice.name -like '*MR*')
        {
            $controller =  $PCIDevice
            $controllers+= $controller
        }
    }
    return $controllers 
}

function get-disks {
    param(
        [parameter()]
        [string]$iloRestExePath = 'C:\Program Files\Hewlett Packard Enterprise\RESTful Interface Tool\ilorest.exe'
    )
    ##Recupération des disques
    & $iloRestExePath  select Drive.v1_17_0 | out-null
    $disksInfosJson = & $iloRestExePath list --json
    $disksInfosJson = [string]$disksInfosJson
    $disksInfos = ConvertFrom-Json -inputObject $disksInfosJson
    return $disksInfos
}

## Core ###
$model = wmic csproduct get name
$proliant = $false
foreach($element in $model)
{
    if($element -like '*proliant*')
    {
        $proliant = $true
    }
}
if(!$proliant){exit}


$iloRESTFul = Get-WmiObject -Class Win32_Product | where name -eq 'RESTful Interface Tool'
if($iloRestFul -eq $null)
{
    $iloRESTFulMsi = "ilorest-5.0.0.0-11.x86_64.msi"
    $iloRESTFulMsiSize = 12611584
    write-host "ILO RESTFul Tool n'est pas installé."
    write-host "On va le télécharger..."
    Invoke-WebRequest -Uri "https://fichiers.septeo.fr/index.php/s/xgqL9dmFJnr9TFe/download" -OutFile "c:\scripts\$iloRESTFulMsi "
    $file = Get-Item "c:\scripts\$iloRESTFulMsi"
    if($file.Length -eq $iloRESTFulMsiSize)
    {
        write-host "On va procéder à l'installation..." -NoNewline

        msiexec /i c:\scripts\$iloRESTFulMsi /quiet /qn /norestart /log c:\scripts\iloRestFulInstall.log
        write-host "OK"
    }
}

$prg = Get-Storage-Executable-Path
$NoSSACLI = "Cannot find SSACLI"
if ($prg -eq $false) {
    #Write-Host "DOH! Cannot find ProLiant Array Configuration Utility or Smart Storage Administrator on this computer."
    Set-ItemProperty -Path $RegLogPath -Name ControllerFirmwareVersion -Value $NoSSACLI
    exit 3
}
if($prg -like '*ilorest*')
{
    $controllers = get-controllers
    $disks = get-disks
}
#Write-Host " "

if($prg -like '*ilorest*')
{
    
    $Slot = 'NA'
}
else
{
    $ControllerDetail = & $prg 'ctrl all show detail'
    $Slot = Get-SlotNumber $ControllerDetail
}
Write-host "Slot : $slot"


if($prg -like '*ilorest*')
{
    if($controllers.count -eq $null){$NumberOfActiveController = 1}
    else{$NumberOfActiveController = $controllers.count}
}
else
{
    $NumberOfActiveController = Count-Controller $ControllerDetail  
}
Write-host "Nombre de controlleur actif : $NumberOfActiveController"
Set-ItemProperty -Path $RegLogPath -Name NumberOfActiveController -Value $NumberOfActiveController


if($prg -like '*ilorest*')
{ 
    $ControllerFirmwareVersion = ""
    foreach($controller in $controllers)
    {
        $ControllerFirmwareVersion += "$($controller.Name),$($controller.FirmwareVersion);"
    }
}
else
{
   $ControllerFirmwareVersion = Read-HPControllerFirmware $ControllerDetail 
}

Write-Host "Contenu de la valeur de registre Controller :" -ForegroundColor gray
Write-Host $ControllerFirmwareVersion -ForegroundColor Red
Set-ItemProperty -Path $RegLogPath -Name SmartArrayFirmwareVersion -Value $ControllerFirmwareVersion

Write-Host " "

if($prg -like '*ilorest*')
{ 
    $physicalDiskDetail = ""
    foreach($disk in $disks)
    {
        $locationList = $disk.PhysicalLocation.PartLocation.ServiceLabel.split(":")
        Add-Member -InputObject $disk -MemberType NoteProperty -Name "locationString" -Value ""
        $disk.locationString = ""
        foreach($element in $locationList)
        {
            if($element -like '*slot*'){continue}
            [string]$disk.locationString += "$(($element.split("="))[1]):"
        }
        $disk.locationString = $disk.locationString.substring(0, $disk.locationString.length-1)
        $physicalDiskDetail += "physicaldrive $($disk.locationString),$($disk.Revision),$($disk.SerialNumber),Model:$($disk.Model);"
    }
}
else
{
    $DiskDetail = & $prg ctrl slot=$Slot pd all show detail
    $PhysicalDiskDetail = Read-HPDiskModelNumber $DiskDetail
}

Write-Host "Contenu de la valeur de registre PhysicalDrive :" -ForegroundColor gray
Write-Host $PhysicalDiskDetail -ForegroundColor Red

Set-ItemProperty -Path $RegLogPath -Name PhysicalDiskDetail -Value $PhysicalDiskDetail

$MediaErrors = Get-MediaErrors $ControllerDetail
Set-ItemProperty -Path $RegLogPath -Name MediaErrors -Value $MediaErrors

