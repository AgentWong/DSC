Configuration cWSUS {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SourcePath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $DestinationPath
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xWebAdministration
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
    File sqlserver {
        Ensure          = 'Present'
        Type            = 'Directory'
        Recurse         = $true
        SourcePath      = "$SourcePath\Modules\SqlServer"
        DestinationPath = 'C:\Program Files\WindowsPowerShell\Modules\SqlServer'
    }
    Script FirstSetup {
        GetScript  = {
            #Do Nothing.
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
                -InputFile 'G:\Scripts\nonclusteredindex.sql'
            Invoke-SqlCmd -ServerInstance $Instance -Database 'SUSDB' `
                -InputFile 'G:\Scripts\pkeyspdelete.sql'
        }
        DependsOn  = '[File]nonclusteredindex', '[File]pkeyspdelete', '[File]sqlserver'
    }
    xWebAppPool wsuspool {
        Name                      = 'WsusPool'
        State                     = 'Started'
        queueLength               = '2000'
        idleTimeout               = (New-TimeSpan -Minutes 0).ToString()
        pingingEnabled            = $false
        restartPrivateMemoryLimit = '0'
        restartTimeLimit          = (New-TimeSpan -Minutes 0).ToString()
    }
}
