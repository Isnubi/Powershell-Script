# =======================================================
#
# NAME: GetPortStatusViaCsvImport.ps1
# AUTHOR: GAMBART Louis
# DATE: 24/01/2022
# VERSION 1.12
#
# =======================================================
#
# CHANGELOG
#
# 24/01/2022 -  1.12 : Add information messages in the import and export selection
#
# 17/01/2022 - 1.11 : Add import file and export directory selection
#
# 12/01/2022 - 1.1 : Add function / Add category / Code refactoring
#
# 30/12/2021 - 1.04 : Add information messages during the course of the script
#
# 22/12/2021 - 1.03 : Add verification for the "\" at the end of the export path / Add default export path / Add a test-path on the import CSV file / Add a check for the export path user entry
#
# 16/12/2021 - 1.02 : Add the hostname and the reference "Port-Statut" in the export path
#
# 13/12/2021 - 1.01 : Translate the script to english / rename variables
#
# 10/12/2021 - 1.0
#
# =======================================================



# ======================== VARIABLES ========================

# Get the date to time-stamp the export file
$date = Get-Date -Format ddMMyyyy_HHmmss 

# Get the name of the host
$hostname = $env:COMPUTERNAME


<#-------------UNUSED-------------
# Default export path
$DefaultCsvExportPath = "C:\temp\"

# Retrieve the paths desired by the user
$CsvImportPath = Read-Host "`n Write the path to your import CSV file (ex: c:\temp\import.csv) :"
$CsvExportPath = Read-Host "`n Write where you want to export the results of the script (by default: c:\temp\) :"
_____________UNUSED_____________#>


# ======================== FUNCTIONS ========================

Add-Type -AssemblyName System.Windows.Forms


<#-------------UNUSED-------------
function CheckCsvImportPath {
    [CmdletBinding()]
    param(
        #param
        [Parameter(Mandatory=$true)]
        [string]$ImportPath
    )
    #code
    if(Test-Path $ImportPath){

        Write-Information "`n The CSV import file path is valid." -InformationAction Continue
        ExportPathProcess -ExportPath $CsvExportPath
    }else{

        Write-Information -MessageData "`n The import CSV file path is invalid." -InformationAction Continue
    }
}
_____________UNUSED_____________#>


function ExportPathProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ExportPath
    )

    <#-------------UNUSED-------------
    # Check if the user enter a custom path : if not, we use the default export path
    if($ExportPath -lt "1"){

        $ExportPath = $DefaultCsvExportPath
    }

    # Verification of the export path : did it end with \
    if($ExportPath.EndsWith("\")){

        $ExportPath = $ExportPath + $hostname + "_Port-Statut_" + $date + ".csv"
    }
    else{

        # If not, we add the \ after the export path
        $ExportPath = $ExportPath + "\" + $hostname + "_Port-Statut_" + $date + ".csv"
    }
    _____________UNUSED_____________#>

    $ExportPath = $ExportPath + "\" + $hostname + "_Port-Statut_" + $date + ".csv"

    Write-Information -MessageData "`n Creation of the export CSV file" -InformationAction Continue
    # We create the export CSV file and its header line
    New-Item -ItemType File -Path $ExportPath   
    Add-Content -Path $ExportPath -Value "Port number;State;PID;Service"

    Write-Information -MessageData "`n Export CSV file have been created`n" -InformationAction Continue

    CsvProcess -FileToProcess $CsvImportPath
}


function CsvProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileToProcess
    )
    # Import port list via CSV file
    $CsvFile = Import-Csv -Path $FileToProcess

    Write-Information -MessageData "`n Process of the port list in progress" -InformationAction Continue

    foreach ($Element in $CsvFile) # Go through the list of ports
    {
        $portNumber = $Element.Port # We get the port number
        $portSpecifications = get-nettcpconnection | Select-Object localPort,state,@{Name="ProcessID";Expression={(Get-Process -Id $_.OwningProcess).Id}},@{Name="ProcessName";Expression={(Get-Process -Id $_.OwningProcess).ProcessName}} | Where-Object {$_.localPort -eq $portNumber} # We get the TCPConnection informations (the port number, its state, the PID and the name of the associated service)
        $portState = $portSpecifications.State 
        $processPID = $portSpecifications.ProcessID
        $processName = $portSpecifications.ProcessName
        if($null -eq $portState){ # Port non used

            #Write-Host "Port $portNumber is available"
            Add-Content -Path $ExportPath -Value "$portNumber;Available;;"
        }
        else{ # Port used

            #Write-Host "The port $portNumber is used by" $portSpecification.ProcessName "("$portSpecification.ProcessID") and has for state" $portSpecification.State
            Add-Content -Path $ExportPath -Value "$portNumber;Busy;$processPID;$processName"
        }
    }
}


function ImportCsvSelector {
    [CmdletBinding()]
    param()
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.InitialDirectory= 'MyComputer'
    $FileBrowser.Filter = 'Fichier CSV (*.csv)|*.csv'
    $FileBrowser.Title = "Select your CSV import file"

    Write-Information -MessageData "Select your CSV import file." -InformationAction Continue
    $null = $FileBrowser.ShowDialog()
    $FilePath = $FileBrowser.FileName
    Write-Host "`n Import file selected : $FilePath`n`n"
    return $FilePath
}

function ExportDirectorySelector {
    [CmdletBinding()]
    param()
    $DirectoryBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $DirectoryBrowser.RootFolder = 'MyComputer'
    $DirectoryBrowser.Description = "Select your CSV export directory"

    Write-Information -MessageData "Select your CSV export directory." -InformationAction Continue
    $null = $DirectoryBrowser.ShowDialog()
    $DirectoryPath = $DirectoryBrowser.SelectedPath
    Write-Host "`n Export directory selected : $DirectoryPath`n"
    return $DirectoryPath
}



# ======================== SCRIPT =========

Write-Information -MessageData "`nScript is starting.`n" -InformationAction Continue

$CsvImportPath = ImportCsvSelector
$CsvExportPath = ExportDirectorySelector

<#-------------UNUSED-------------
#CheckCsvImportPath -ImportPath $CsvImportPath
_____________UNUSED_____________#>

ExportPathProcess -ExportPath $CsvExportPath

Write-Information -MessageData "`n End of the script" -InformationAction Continue