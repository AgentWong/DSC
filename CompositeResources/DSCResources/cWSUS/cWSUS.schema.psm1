<#
This configuration sets optimized settings according to official Microsoft documentation on WSUS Best Practices
and WSUS Maintenance Guide.
#>

Configuration cWSUS {

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xWebAdministration
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
            $ncl = @'
            -- Create custom index in tbLocalizedPropertyForRevision
            USE [SUSDB]
            
            CREATE NONCLUSTERED INDEX [nclLocalizedPropertyID] ON [dbo].[tbLocalizedPropertyForRevision]
            (
                 [LocalizedPropertyID] ASC
            )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
            
            -- Create custom index in tbRevisionSupersedesUpdate
            CREATE NONCLUSTERED INDEX [nclSupercededUpdateID] ON [dbo].[tbRevisionSupersedesUpdate]
            (
                 [SupersededUpdateID] ASC
            )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
'@

            $pkey = @'
USE [SUSDB]
GO

/****** Object:  StoredProcedure [dbo].[spDeleteUpdate]    Script Date: 11/2/2020 8:55:02 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

 
ALTER PROCEDURE [dbo].[spDeleteUpdate]
    @localUpdateID int
AS
SET NOCOUNT ON
BEGIN TRANSACTION
SAVE TRANSACTION DeleteUpdate
DECLARE @retcode INT
DECLARE @revisionID INT
DECLARE @revisionList TABLE(RevisionID INT PRIMARY KEY)
INSERT INTO @revisionList (RevisionID)
    SELECT r.RevisionID FROM dbo.tbRevision r
        WHERE r.LocalUpdateID = @localUpdateID
IF EXISTS (SELECT b.RevisionID FROM dbo.tbBundleDependency b WHERE b.BundledRevisionID IN (SELECT RevisionID FROM @revisionList))
   OR EXISTS (SELECT p.RevisionID FROM dbo.tbPrerequisiteDependency p WHERE p.PrerequisiteRevisionID IN (SELECT RevisionID FROM @revisionList))
BEGIN
    RAISERROR('spDeleteUpdate got error: cannot delete update as it is still referenced by other update(s)', 16, -1)
    ROLLBACK TRANSACTION DeleteUpdate
    COMMIT TRANSACTION
    RETURN(1)
END
INSERT INTO @revisionList (RevisionID)
    SELECT DISTINCT b.BundledRevisionID FROM dbo.tbBundleDependency b
        INNER JOIN dbo.tbRevision r ON r.RevisionID = b.RevisionID
        INNER JOIN dbo.tbProperty p ON p.RevisionID = b.BundledRevisionID
        WHERE r.LocalUpdateID = @localUpdateID
            AND p.ExplicitlyDeployable = 0
IF EXISTS (SELECT IsLocallyPublished FROM dbo.tbUpdate WHERE LocalUpdateID = @localUpdateID AND IsLocallyPublished = 1)
BEGIN
    INSERT INTO @revisionList (RevisionID)
        SELECT DISTINCT pd.PrerequisiteRevisionID FROM dbo.tbPrerequisiteDependency pd
            INNER JOIN dbo.tbUpdate u ON pd.PrerequisiteLocalUpdateID = u.LocalUpdateID
            INNER JOIN dbo.tbProperty p ON pd.PrerequisiteRevisionID = p.RevisionID
            WHERE u.IsLocallyPublished = 1 AND p.UpdateType = 'Category'
END
DECLARE #cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT t.RevisionID FROM @revisionList t ORDER BY t.RevisionID DESC
OPEN #cur
FETCH #cur INTO @revisionID
WHILE (@@ERROR=0 AND @@FETCH_STATUS=0)
BEGIN
    IF EXISTS (SELECT b.RevisionID FROM dbo.tbBundleDependency b WHERE b.BundledRevisionID = @revisionID
                   AND b.RevisionID NOT IN (SELECT RevisionID FROM @revisionList))
       OR EXISTS (SELECT p.RevisionID FROM dbo.tbPrerequisiteDependency p WHERE p.PrerequisiteRevisionID = @revisionID
                      AND p.RevisionID NOT IN (SELECT RevisionID FROM @revisionList))
    BEGIN
        DELETE FROM @revisionList WHERE RevisionID = @revisionID
        IF (@@ERROR <> 0)
        BEGIN
            RAISERROR('Deleting disqualified revision from temp table failed', 16, -1)
            GOTO Error
        END
    END
    FETCH NEXT FROM #cur INTO @revisionID
END
IF (@@ERROR <> 0)
BEGIN
    RAISERROR('Fetching a cursor to value a revision', 16, -1)
    GOTO Error
END
CLOSE #cur
DEALLOCATE #cur
DECLARE #cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT t.RevisionID FROM @revisionList t ORDER BY t.RevisionID DESC
OPEN #cur
FETCH #cur INTO @revisionID
WHILE (@@ERROR=0 AND @@FETCH_STATUS=0)
BEGIN
    EXEC @retcode = dbo.spDeleteRevision @revisionID
    IF @@ERROR <> 0 OR @retcode <> 0
    BEGIN
        RAISERROR('spDeleteUpdate got error from spDeleteRevision', 16, -1)
        GOTO Error
    END
    FETCH NEXT FROM #cur INTO @revisionID
END
IF (@@ERROR <> 0)
BEGIN
    RAISERROR('Fetching a cursor to delete a revision', 16, -1)
    GOTO Error
END
CLOSE #cur
DEALLOCATE #cur
COMMIT TRANSACTION
RETURN(0)
Error:
    CLOSE #cur
    DEALLOCATE #cur
    IF (@@TRANCOUNT > 0)
    BEGIN
        ROLLBACK TRANSACTION DeleteUpdate
        COMMIT TRANSACTION
    END
    RETURN(1)
GO
'@
            $Instance = '\\.\pipe\MICROSOFT##WID\tsql\query'
            try {
                Invoke-SqlCmd -ServerInstance $Instance -Database 'SUSDB' `
                    -Query $ncl
                Invoke-SqlCmd -ServerInstance $Instance -Database 'SUSDB' `
                    -Query $pkey
            }
            catch {
                Write-Error $_.Exception.Message
            }
        }
        #DependsOn  = '[UpdateServicesServer]WSUSSetup'
    }
    xWebAppPool wsuspool {
        Name                      = 'WsusPool'
        State                     = 'Started'
        queueLength               = '2000'
        idleTimeout               = (New-TimeSpan -Minutes 0).ToString()
        pingingEnabled            = $false
        restartPrivateMemoryLimit = '0'
        restartTimeLimit          = (New-TimeSpan -Minutes 0).ToString()
        #DependsOn                 = '[UpdateServicesServer]WSUSSetup'
    }
}
