<#
This configuration sets optimized settings according to official Microsoft documentation on WSUS Best Practices
and WSUS Maintenance Guide.
#>

Configuration cWSUS {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SourcePath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $DestinationPath,
        [ValidateNotNullOrEmpty()]
        [String] $ContentDir
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xWebAdministration, UpdateServicesDsc
    WindowsFeatureSet WSUS {
        Name   = 'UpdateServices-Services', 'UpdateServices-API'
        Ensure = 'Present'
    }
    WindowsFeature WID {
        Name      = 'UpdateServices-WidDB'
        Ensure    = 'Present'
        DependsOn = '[WindowsFeatureSet]WSUS'
    }
    UpdateServicesServer WSUSSetup {
        Ensure     = 'Present'
        Languages = 'en'
        Classifications = @('E6CF1350-C01B-414D-A61F-263D14D133B4','0FA1201D-4330-4FA8-8AE9-B877473B6441','B4832BD8-E735-4761-8DAF-37F882276DAB','28BC880E-0592-4CBF-8F95-C79B17911D5F','CD5FFD1E-E932-4E3A-BF74-18BF0B1BBD83')
        Products = @('Microsoft SQL Server 2019','Microsoft SQL Server Management Studio v18','Windows 10, version 1903 and later','Windows Admin Center','Windows Admin Center','Windows Server 2019')
        ContentDir = $ContentDir
        DependsOn = '[WindowsFeature]WID'
    }
    File nonclusteredindex {
        Ensure          = 'Present'
        SourcePath      = "$SourcePath\nonclusteredindex.sql"
        DestinationPath = "$DestinationPath\nonclusteredindex.sql"
    }
    File pkeyspdelete {
        Ensure          = 'Present'
        SourcePath      = "$SourcePath\pkeyspdelete.sql"
        DestinationPath = "$DestinationPath\pkeyspdelete.sql"
    }
    Script FirstSetup {
        GetScript  = {
            $Instance = '\\.\pipe\MICROSOFT##WID\tsql\query'
            $Indexes = Invoke-SqlCmd -ServerInstance $Instance -Database 'SUSDB' `
                -Query "EXEC sp_helpindex 'dbo.tbLocalizedPropertyForRevision'"
                
            if ( $Indexes.index_name -Contains 'nclLocalizedPropertyID') {
                return @{ 'NonClusteredIndexExists' = "$true" }
            }
            else {
                return @{ 'NonClusteredIndexExists' = "$false" }
            }
        }
        TestScript = {
            $Instance = '\\.\pipe\MICROSOFT##WID\tsql\query'
            $Indexes = Invoke-SqlCmd -ServerInstance $Instance -Database 'SUSDB' `
                -Query "EXEC sp_helpindex 'dbo.tbLocalizedPropertyForRevision'"
                
            if ( $Indexes.index_name -Contains 'nclLocalizedPropertyID') {
                Write-Verbose -Message "Non-Clustered Index found, SUSDB is in the desired state."
                return $true
            }
            else {
                Write-Verbose -Message "Non-Clustered Index not found, running script to add ncl."
                return $false
            }
        }
            
        SetScript  = {
            $Instance = '\\.\pipe\MICROSOFT##WID\tsql\query'
            Invoke-SqlCmd -ServerInstance $Instance -Database 'SUSDB' `
                -InputFile "$using:DestinationPath\nonclusteredindex.sql"
            Invoke-SqlCmd -ServerInstance $Instance -Database 'SUSDB' `
                -InputFile "$using:DestinationPath\pkeyspdelete.sql"
        }
        DependsOn  = '[File]nonclusteredindex', '[File]pkeyspdelete', '[UpdateServicesServer]WSUSSetup'
    }
    xWebAppPool wsuspool {
        Name                      = 'WsusPool'
        State                     = 'Started'
        queueLength               = '2000'
        idleTimeout               = (New-TimeSpan -Minutes 0).ToString()
        pingingEnabled            = $false
        restartPrivateMemoryLimit = '0'
        restartTimeLimit          = (New-TimeSpan -Minutes 0).ToString()
        DependsOn                 = '[UpdateServicesServer]WSUSSetup'
    }
}
