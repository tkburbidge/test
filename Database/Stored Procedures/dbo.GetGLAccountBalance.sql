SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 30, 2012
-- Description:	Gets the balance of a GLAccount as of a certain date
-- =============================================
CREATE PROCEDURE [dbo].[GetGLAccountBalance] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@glAccountID uniqueidentifier = null,
	@accountingBasis nvarchar(10) = null,
	@date datetime = null,
	@propertyIDs guidcollection readonly
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	
	SELECT SUM(je.Amount)
		FROM JournalEntry je
			INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID			
			INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
		WHERE t.AccountID = @accountID
		  AND je.GLAccountID = @glAccountID
		  AND t.TransactionDate <= @date
		  AND je.AccountingBasis = @accountingBasis
		  AND je.AccountingBookID IS NULL
		  --AND (((SELECT COUNT(*) FROM #PropertyIDs) = 0) OR (t.PropertyID IN (SELECT PropertyID FROM #PropertyIDs)))
END
GO
