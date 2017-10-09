SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Tony Morgan
-- Create date: 10/20/2014
-- Description:	Sets the statistic value for the GL Accounts given in each of the lists (
-- =============================================
CREATE PROCEDURE  [dbo].[UpdateGLAccountStatistics]
	-- Add the parameters for the stored procedure here
	@accountID BIGINT = 0, 
	@grossPotentialRentGLAccountIDs GuidCollection READONLY,
	@lossToLeaseGLAccountIDs GuidCollection READONLY,
	@concessionGLAccountIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		
	UPDATE gla 
	SET Statistic  = 
		CASE
			WHEN gla.GLAccountID IN (SELECT Value FROM @concessionGLAccountIDs) THEN 'C'
			WHEN gla.GLAccountID IN (SELECT Value FROM @lossToLeaseGLAccountIDs) THEN 'L'
			WHEN gla.GLAccountID IN (SELECT Value FROM @grossPotentialRentGLAccountIDs) THEN 'G'
			ELSE NULL
		END
	FROM GLAccount AS gla
	WHERE
		gla.AccountID = @accountID
END
GO
