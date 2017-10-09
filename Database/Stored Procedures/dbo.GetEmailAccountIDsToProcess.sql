SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 10, 2013
-- Description:	Gets a list of accounts to check for emails to process
-- =============================================
CREATE PROCEDURE [dbo].[GetEmailAccountIDsToProcess] 
	-- Add the parameters for the stored procedure here
	@processingGuid uniqueidentifier = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #AccountsToProcess (
		Sequence int identity,
		AccountID bigint null)
		
	INSERT #AccountsToProcess
		SELECT s.AccountID
			FROM Settings s
				INNER JOIN CurrentProcessingState cps ON cps.LastEmailAccountProcessedBy = @processingGuid
			WHERE s.AccountID > cps.LastEmailAccountChecked
			ORDER BY s.AccountID
	
	IF (0 = (SELECT COUNT(*) FROM #AccountsToProcess))
	BEGIN
		INSERT #AccountsToProcess 
			SELECT AccountID FROM Settings 
			ORDER BY AccountID
	END
	ELSE
	BEGIN
		INSERT #AccountsToProcess
			SELECT s.AccountID
				FROM Settings s
					INNER JOIN CurrentProcessingState cps ON cps.LastEmailAccountProcessedBy = @processingGuid
				WHERE s.AccountID < cps.LastEmailAccountChecked
				ORDER BY s.AccountID			
	END
	
	SELECT AccountID FROM #AccountsToProcess ORDER BY Sequence
	
END
GO
