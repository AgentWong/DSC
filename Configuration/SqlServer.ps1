Configuration SQLInstall
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration, SqlServerDsc, NetworkingDsc
    Node EDEN-SQL-01
    {
        WindowsFeature NetFramework45 {
            Name   = 'NET-Framework-45-Core'
            Ensure = 'Present'
        }
        SqlSetup InstallDefaultInstance {
            InstanceName        = 'MSSQLSERVER'
            Features            = 'SQLENGINE'
            SourcePath          = '\\FILESHARE\Share\Software\SqlServer2019'
            SQLSysAdminAccounts = @('Administrators')
            DependsOn           = '[WindowsFeature]NetFramework45'
        }
        SqlProtocol EnableTcp {
            InstanceName = 'MSSQLSERVER'
            ProtocolName = 'TcpIp'
            Enabled      = $true
            KeepAlive    = 20000
            DependsOn      = '[SqlSetup]InstallDefaultInstance'
        }
        SqlProtocolTcpIp AllowRemote {
            InstanceName   = 'MSSQLSERVER'
            IpAddressGroup = 'IPAll'
            TcpPort        = '1433'
            DependsOn      = '[SqlProtocol]EnableTcp'
        }
        Service SqlBrowser {
            Name        = 'SQLBROWSER'
            Ensure      = 'Present'
            StartupType = 'Automatic'
            State       = 'Running'
            DependsOn   = '[SqlSetup]InstallDefaultInstance'
        }
        Firewall RemoteSql {
            Name      = 'SQLPORT'
            Ensure    = 'Present'
            Direction = 'Inbound'
            Protocol  = 'TCP'
            LocalPort = '1433'
            Enabled   = 'True'
            Profile   = 'Domain'
            DependsOn = '[SqlSetup]InstallDefaultInstance'
        }
    }
}