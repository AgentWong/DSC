[DSCLocalConfigurationManager()]
configuration DSCClientNodeConfiguration
{
    param
    (
        [ValidateNotNullOrEmpty()]
        [string] $NodeName = 'localhost',

        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey, #same as the one used to set up pull server in previous configuration

        [ValidateNotNullOrEmpty()]
        [string] $ServerName = 'localhost' #node name of the pull server, same as $NodeName used in previous configuration
    )

    Node $NodeName
    {
        Settings {
            RefreshMode          = 'Pull'
            ConfigurationMode    = 'ApplyAndAutoCorrect'
            ConfigurationModeFrequencyMins = '30'
            RebootNodeIfNeeded   = $true
            AllowModuleOverwrite = $true
            ActionAfterReboot = 'ContinueConfiguration'
        }

        ConfigurationRepositoryWeb PullSrv {
            ServerURL          = "https://$ServerName`:8080/PSDSCPullServer.svc" # notice it is https
            RegistrationKey    = $RegistrationKey
            ConfigurationNames = @($NodeName)
        }

        ReportServerWeb PullSrv {
            ServerURL       = "https://$ServerName`:8080/PSDSCPullServer.svc" # notice it is https
            RegistrationKey = $RegistrationKey
        }
    }
}