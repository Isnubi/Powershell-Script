#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$domainName
)
#==========================================================================================
#
# SCRIPT NAME        :     Create_AD.ps1
#
# AUTHOR             :     Louis GAMBART
# CREATION DATE      :     2022.11.18
# RELEASE            :     v2.4.0
# USAGE SYNTAX       :     .\Cread_AD.ps1 -domainName "test.local""
#
# SCRIPT DESCRIPTION :     This script will create a new AD forest and a domain controller
#
#==========================================================================================

#                 - RELEASE NOTES -
# v1.0.0  2022.21.12 - Louis GAMBART - Initial version
#
#==========================================================================================


###################
#                 #
#  I - VARIABLES  #
#                 #
###################

# clear error variable
$error.clear()

# get the name of the host
[String] $hostname = $env:COMPUTERNAME


####################
#                  #
#  II - FUNCTIONS  #
#                  #
####################

function Get-Datetime {
    <#
    .SYNOPSIS
    Get the current date and time
    .DESCRIPTION
    Get the current date and time
    .INPUTS
    None
    .OUTPUTS
    System.DateTime: The current date and time
    .EXAMPLE
    Get-Datetime | Out-String
    2022-10-24 10:00:00
    #>
    [CmdletBinding()]
    [OutputType([System.DateTime])]
    param()
    begin {}
    process { return [DateTime]::Now }
    end {}
}


function Get-SystemType {
    <#
    .SYNOPSIS
    Get the system type
    .DESCRIPTION
    Get the system type
    .INPUTS
    None
    .OUTPUTS
    System.String: The system type
    .EXAMPLE
    Get-SystemType
    Server
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param()
    begin {}
    process {
        if ($PSUICulture.Name -eq "fr-FR") {
            $info = systeminfo /fo csv | ConvertFrom-Csv | Select-Object Nom*
            if ($info."Nom de l'hÃ´te" -match "^(Microsoft Windows ?(Server))") { return 'Server' }
            elseif ($info."Nom de l'hÃ´te" -match "^(Microsoft Windows ?([0-9]{1,2}))") { return 'Workstation' }
            else { return 'Unknow' }
        }
        else {
            $info = systeminfo /fo csv | ConvertFrom-Csv | Select-Object OS*
            if ($info.'OS Name' -match "^(Microsoft Windows ?(Server))") { return 'Server' }
            elseif ($info.'OS Name' -match "^(Microsoft Windows ?([0-9]{1,2}))") { return 'Workstation' }
            else { return 'Unknow' }
        }
    }
    end {}
}


function Write-Log {
    <#
    .SYNOPSIS
    Write log message in the console
    .DESCRIPTION
    Write log message in the console
    .INPUTS
    System.String: The message to write
    System.String: The log level
    .OUTPUTS
    None
    .EXAMPLE
    Write-Log "Hello world" "Verbose"
    VERBOSE: Hello world
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('Error', 'Warning', 'Information', 'Verbose', 'Debug')]
        [string]$LogLevel = 'Information'
    )
    begin {}
    process {
        switch ($LogLevel) {
            'Error' { Write-Error $Message -ErrorAction Stop }
            'Warning' { Write-Warning $Message -WarningAction Continue }
            'Information' { Write-Information $Message -InformationAction Continue }
            'Verbose' { Write-Verbose $Message -Verbose }
            'Debug' { Write-Debug $Message -Debug Continue }
            default { throw "Invalid log level: $_" }
        }
    }
    end {}
}


function Install-ADDS-Role {
    <#
    .SYNOPSIS
    Add the ADDS role
    .DESCRIPTION
    Add the ADDS role to the server
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Add-ADDS-Role
    #>
    [CmdletBinding()]
    param()
    begin {
        if (Get-WindowsFeature -Name AD-Domain-Services -ErrorAction SilentlyContinue) {
            Write-Log "The ADDS role is already installed" -LogLevel "Warning"
            return
        }
    }
    process {
        Write-Log "Add the ADDS role" "Information"
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    }
    end {
        if (!(Get-WindowsFeature -Name AD-Domain-Services -ErrorAction SilentlyContinue)) {
            Write-Log "The ADDS role was not installed" -LogLevel "Error"
            return
        }
    }
}


function Add-New-Forest {
    <#
    .SYNOPSIS
    Create a new forest
    .DESCRIPTION
    Create a new forest with the specified domain name on the domain controller
    .INPUTS
    System.String: The domain name
    .OUTPUTS
    None
    .EXAMPLE
    Create-New-Forest
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName
    )
    begin {
        Write-Log "Create a new forest" "Information"
        $domainName = $domainName
        $domainNetbiosName = $domainName.Split('.')[0]
    }
    process {
        $domainAdminPassword = ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force
        $domainAdminCreds = New-Object System.Management.Automation.PSCredential ("$domainNetbiosName\Administrator", $domainAdminPassword)
        $forestMode = "Win2016"
        $domainMode = "Win2016"
        Install-ADDSForest -DomainName $domainName -DomainNetbiosName $domainNetbiosName -ForestMode $forestMode -DomainMode $domainMode -SafeModeAdministratorPassword $domainAdminCreds -InstallDNS:$true -Force:$true
    }
    end {
        if (!(Get-ADDomain -Identity $domainName -ErrorAction SilentlyContinue)) {
            Write-Log "The forest was not created" -LogLevel "Error"
            return
        }
    }
}


############################
#                          #
#  III - SCRIPT EXECUTION  #
#                          #
############################

Write-Log "Starting script on $hostname ($(Get-SystemType)) at $(Get-Datetime)" 'Verbose'
if (Get-SystemType -eq 'Workstation') { Write-Log "This script must be run on a server" -LogLevel 'Error' }
if ($domainName -notmatch "^([a-zA-Z])([a-zA-Z0-9-]{0,66})(\.)([a-zA-Z])([a-zA-Z0-9-]{0,66})$") { Write-Log "The domain name is not properly formatted, please enter it like 'test.local'" -LogLevel "Error" }
else {
    Write-Log "Installing the ADDS role" "Information"
    Install-ADDS-Role
    Write-Log "Creating a new forest" "Information"
    Add-New-Forest -DomainName $domainName
}
Write-Log "Script completed at $(Get-Datetime)" 'Verbose'