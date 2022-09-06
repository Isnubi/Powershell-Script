# =======================================================
#
# NAME: PowerCLI_VM-creator.ps1
# AUTHOR: GAMBART Louis
# DATE: 07/01/2022
#
# VERSION 1.0
#
# =======================================================


Add-Type -AssemblyName System.Windows.Forms

$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory=[Environment]::GetFolderPath('Desktop')
    Filter='Fichier CSV (*.csv)|*.csv'
}


# Get current date
$date = Get-Date -Format ddMMyyyy_HHmmss


if(Get-Module -ListAvailable -Name VMWare.PowerCLI){
    Write-Information "`n The PowerCLI module is already installed. `n"  -InformationAction Continue
}
else{
    Write-Information "`n The PowerCLI module is not installed. `n"  -InformationAction Continue
    $answerInstall = Read-Host "`n Did you want to install PowerCLI module (y or n) ? `n"
    if($answerInstall -eq "y"){
        Install-Module VMware.PowerCLI -Scope CurrentUser
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore
        Write-Information "`n The PowerCLI module have been installed. `n"  -InformationAction Continue
    }else{
        Write-Information "`n End of the script. `n"  -InformationAction Continue
        Exit
    }
    
}


$CsvPath = Read-Host "`n Write where you want to export the results of the script (by default: c:\temp\) :"

# Check if the user enter a custom path : if not, we use the default export path
if($CsvPath.Length -lt "1"){
    
    if(Test-Path -path "C:\temp"){
        #path exist
    }
    else{
        New-Item -ItemType Directory -Name "temp" -Path "c:\"
    }

    # Default export path
    $CsvPath = "C:\temp\"
}

# Verification of the export path : did it end with \
if($CsvPath.EndsWith("\")){
    $CsvPath = $CsvPath + "VM-list_" + $date + ".csv"
}
else{
    
    # If not, we add the \ after the export path
    $CsvPath = $CsvPath + "\" + "VM-listt_" + $date + ".csv"
}

Write-Information -MessageData "`n Creation of the export CSV file" -InformationAction Continue

# We create the export CSV file and its header line
New-Item -ItemType File -Path $CsvPath   
Add-Content -Path $CsvPath -Value "vmname;vmhost;datastore;disksize;memorysize;numcpu;networkname;isopath;guestid" 

$answer = "y"
while($answer -ne "n"){
    Write-Information -MessageData "`n Write all the attributes to create your VM `n" -InformationAction Continue

    $VMName = Read-Host "Name of the virtual machine"
    $VMHost = Read-Host "Host of the virtual machine"

    $datastore = Read-Host "Datastore of the virtual machine (by default datastore1) :"
    if($datastore.Length -lt "1"){
        $datastore = "datastore1"
    }

    $DiskSize = Read-Host "Size of the virtual disk in gigabyte"
    $MemorySize = Read-Host "Size of the memory allocated in megabyte"
    $NumCPU = Read-Host "Number of CPU allocated :"
    
    $NetworkName = Read-Host "Name of the virtual network adapter (by default VM Network)"
    if($NetworkName.Length -lt "1"){
        $NetworkName = "VM Network"
    }

    Write-Information -MessageData "`n Select your image system file (.iso) `n" -InformationAction Continue
    $null = $FileBrowser.ShowDialog()
    $IsoPath = $FileBrowser.FileName

    $GuestID = Read-Host "Name of the OS (windows9_64Guest / windows2019srv_64Guest / debian11_64Guest)"

    Add-Content -Path $CsvPath -Value "$VMName;$VMHost;$datastore;$DiskSize;$MemorySize;$NumCPU;$NetworkName;$IsoPath;$GuestID"

    $answer = Read-Host "Did you want to add another virtual machine attributes to the CSV file ? (y or n)"
    if($answer -eq "n"){
        break
    }
}


$ImportCSV = Import-Csv -Path $CsvPath -Delimiter ";"

foreach($element in $ImportCSV){
    $C_VMName = $element.vmname
    $C_VMHost = $element.vmhost
    $C_datastore = $element.datastore
    $C_DiskSize = $element.disksize
    $C_MemorySize = $element.memorysize
    $C_NumCPU = $element.numcpu
    $C_NetworkName = $element.networkname
    $C_IsoPath = $element.isopath
    $C_GuestID = $element.guestid

    Connect-VIServer -Server $C_VMHost

    New-VM -Name $C_VMName -VMHost $C_VMHost -Datastore $C_datastore -DiskGB $C_DiskSize -MemoryMB $C_MemorySize -NumCpu $C_NumCPU -NetworkName $C_NetworkName -GuestId $C_GuestID

    Start-Sleep -Seconds 5

    Start-VM -VM $C_VMName

    Start-Sleep -Seconds 5

    New-CDDrive -VM $C_VMName -IsoPath $C_IsoPath

    Write-Information -MessageData "`n Virtual machine created `n" -InformationAction Continue

    Disconnect-VIServer -Server $C_VMHost -Confirm:$false

}

Write-Information -MessageData "`n End of the script `n" -InformationAction Continue