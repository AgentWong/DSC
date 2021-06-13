configuration DscWebServiceConfiguration
{
    param
    (
        [string[]]$NodeName = 'localhost',

        [ValidateNotNullOrEmpty()]
        [string] $SqlServer, #Try a FQDN.

        [ValidateNotNullOrEmpty()]
        [string] $certificateThumbPrint,

        [Parameter(HelpMessage = 'This should be a string with enough entropy (randomness) to protect the registration of clients to the pull server.  We will use new GUID by default.')]
        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey = (New-Guid)   # A guid that clients use to initiate conversation with pull server
    )

    Import-DSCResource -ModuleName PSDesiredStateConfiguration
    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Import-DSCResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName ComputerManagementDsc

    Node $NodeName
    {
        WindowsFeature DSCServiceFeature {
            Ensure = 'Present'
            Name   = 'DSC-Service'
        }
        File PullServerFiles {
            DestinationPath = 'c:\PullServer'
            Ensure          = 'Present'
            Type            = 'Directory'
            Force           = $true
        }
        File ScriptsDirectory {
            DestinationPath = 'c:\Scripts'
            Ensure          = 'Present'
            Type            = 'Directory'
            Force           = $true
        }
        xDscWebService PSDSCPullServer {
            Ensure                   = 'Present'
            EndpointName             = 'PSDSCPullServer'
            Port                     = 8080
            PhysicalPath             = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer"
            CertificateThumbPrint    = $certificateThumbPrint
            ModulePath               = 'c:\PullServer\Modules'
            ConfigurationPath        = 'c:\PullServer\Configuration'
            State                    = 'Started'
            RegistrationKeyPath      = 'c:\PullServer'
            UseSecurityBestPractices = $true
            Enable32BitAppOnWin64    = $false
            SqlProvider              = $true
            SqlConnectionString      = "Provider=SQLOLEDB.1;Integrated Security=SSPI;Initial Catalog=master;Persist Security Info=False;Data Source=$SqlServer;Database=DSC"
            DependsOn                = '[WindowsFeature]DSCServiceFeature', '[File]PullServerFiles'
        }
        PendingReboot DSCPostReboot {
            Name = 'DSCPostReboot'
            DependsOn = '[xDscWebService]PSDSCPullServer'
        }
        xWebsite StopDefaultSite {
            Ensure       = 'Present'
            Name         = 'Default Web Site'
            State        = 'Stopped'
            PhysicalPath = 'C:\inetpub\wwwroot'
            DependsOn    = '[WindowsFeature]DSCServiceFeature'
        }

        File RegistrationKeyFile {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = 'C:\PullServer\RegistrationKeys.txt'
            Contents        = $RegistrationKey
            DependsOn       = '[File]PullServerFiles'
        }
        Environment PSModulePath {
            Ensure    = 'Present'
            Name      = 'PSModulePath'
            Value     = 'C:\PullServer\Modules;C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
            DependsOn = '[xDscWebService]PSDSCPullServer'
        }
    }
}