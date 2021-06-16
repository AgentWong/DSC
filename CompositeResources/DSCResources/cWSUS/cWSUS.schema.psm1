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
        ContentDir = $ContentDir
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
                return @{ 'Result' = "$true" }
            }
            else {
                return @{ 'Result' = "$false" }
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
