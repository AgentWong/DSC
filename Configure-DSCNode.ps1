[DSCLocalConfigurationManager()]
configuration Configure-DSCClientNode
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

    $DecryptionKey = (Invoke-Command -ComputerName $NodeName -ScriptBlock { Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { 
        ($_.PrivateKey.KeyExchangeAlgorithm) -and ( $_.Verify()) } }).Thumbprint

    Node $NodeName
    {
        Settings {
            ConfigurationMode  = 'ApplyAndAutoCorrect'
            RefreshMode        = 'Pull'
            RebootNodeIfNeeded = $true
            CertificateID = $DecryptionKey
        }

        ConfigurationRepositoryWeb PullSrv {
            ServerURL          = "https://$ServerName`:8080/PSDSCPullServer.svc" # notice it is https
            RegistrationKey    = $RegistrationKey
            ConfigurationNames = @('ClientConfig')
        }

        ReportServerWeb PullSrv {
            ServerURL       = "https://$ServerName`:8080/PSDSCPullServer.svc" # notice it is https
            RegistrationKey = $RegistrationKey
        }
    }
}