SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetPreviousCertifications] 
	-- Add the parameters for the stored procedure here
	@accountID BIGINT = 0,
	@unitLeaseGroupIDs GuidCollection READONLY,
	@date DATETIME = null,
	@certificationIDs GuidCollection READONLY,
	@types StringCollection READONLY,
	@completedOnly BIT = 0,
	@hasSubmissionItem BIT = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE  #LinkTable(
		BaseID UNIQUEIDENTIFIER,
		CertID UNIQUEIDENTIFIER
	)
	
	INSERT #LinkTable
	SELECT Value, null FROM @certificationIDs
	
	CREATE TABLE  #cert(
		certificationID UNIQUEIDENTIFIER
	)
	CREATE TABLE  #usedIDs(
		certificationID UNIQUEIDENTIFIER
	)
	
	DECLARE @certificationID UNIQUEIDENTIFIER = (SELECT TOP 1 BaseID FROM #LinkTable WHERE CertID is null)
	DECLARE @certificationGroupID UNIQUEIDENTIFIER

	WHILE @certificationID IS NOT NULL
	BEGIN
		SELECT @certificationGroupID = (SELECT TOP 1 c.CertificationGroupID
											FROM Certification c
											WHERE c.CertificationID = @certificationID)

			INSERT #cert EXEC GetPreviousCertification @accountID, null, @certificationID, @types, @completedOnly, 0, @certificationGroupID
			
			update #LinkTable set CertID = (select * from #cert)
			INSERT #usedIDs VALUES(@certificationID)
			DELETE FROM #cert
			
			SET @certificationID = (SELECT TOP 1 BaseID FROM #LinkTable WHERE BaseID NOT IN (SELECT * FROM #usedIDs))
	END

	INSERT #LinkTable
	SELECT Value, null FROM @unitLeaseGroupIDs

	DECLARE @unitLeaseGroupID UNIQUEIDENTIFIER = (SELECT TOP 1 BaseID FROM #LinkTable WHERE BaseID NOT IN (SELECT * FROM #usedIDs))
	
	WHILE @unitLeaseGroupID IS NOT NULL
	BEGIN
			INSERT #cert EXEC GetPreviousCertification @accountID, @unitLeaseGroupID, @date, null, @types, @completedOnly, @hasSubmissionItem
			
			update #LinkTable set CertID = (select * from #cert)
			INSERT #usedIDs VALUES(@unitLeaseGroupID)

			DELETE FROM #cert

			SET @unitLeaseGroupID = (SELECT TOP 1 BaseID FROM #LinkTable WHERE BaseID NOT IN (SELECT * FROM #usedIDs))
	END

			SELECT l.BaseID, c.* FROM #LinkTable l 
			JOIN Certification c on l.CertID = c.CertificationID


END
GO
