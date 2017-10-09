SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetAffordableProgramNames] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@certificationIDs GuidCollection READONLY,
	@passbookRate DECIMAL,
	@assetImputationLimit INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ProgramNames
	(
		CertificationID uniqueidentifier not null,
		ProgramName nvarchar(500) null,
	)

	INSERT INTO #ProgramNames
		SELECT	
			c.CertificationID AS 'CertificationID',
			pn.ProgramName AS 'ProgramName'
		FROM Certification c
			CROSS APPLY dbo.GetAffordableProgramName(c.CertificationID, 1, 1, null, @accountID, @passbookRate, @assetImputationLimit) pn
		WHERE c.AccountID = @accountID
			AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))
	
	SELECT * FROM #ProgramNames
END
GO
