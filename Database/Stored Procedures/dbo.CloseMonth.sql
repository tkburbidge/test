SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 2, 2012
-- Description:	Closes the given month for the property & resets the current property accounting period to the next not closed period sequentially
-- =============================================
CREATE PROCEDURE [dbo].[CloseMonth] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@propertyAccountingPeriodID uniqueidentifier = null
AS
	DECLARE @updateCount int
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DELETE PropertyAccountingPeriodUserSecurityRolePermission
	WHERE AccountID = @accountID
		AND PropertyAccountingPeriodID = @propertyAccountingPeriodID

	INSERT Budget
		SELECT NEWID(), @accountID, GLAccountID, @propertyAccountingPeriodID, null, null, null, null, null
			FROM GLAccount
			WHERE AccountID = @accountID
				AND (GLAccountID NOT IN (SELECT GLAccountID 
											FROM Budget
											WHERE AccountID = @accountID
												AND PropertyAccountingPeriodID = @propertyAccountingPeriodID))

	UPDATE Budget SET NetMonthlyTotalAccrual = 0, NetMonthlyTotalCash = 0 WHERE PropertyAccountingPeriodID = @propertyAccountingPeriodID
	
	UPDATE Budget SET NetMonthlyTotalAccrual = 
		(SELECT ISNULL(SUM(je.Amount), 0)
			FROM JournalEntry je
				INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = @propertyAccountingPeriodID
				--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID				
			WHERE je.GLAccountID = Budget.GLAccountID
			  AND Budget.PropertyAccountingPeriodID = @propertyAccountingPeriodID
			  AND t.PropertyID = @propertyID
			  -- Don't include closing the year entries
			  AND t.Origin NOT IN ('Y', 'E')
			  AND je.AccountingBasis = 'Accrual'
			  AND je.AccountingBookID IS NULL
			  --AND t.TransactionDate >= ap.StartDate
			  --AND t.TransactionDate <= ap.EndDate)
			  AND t.TransactionDate >= pap.StartDate
			  AND t.TransactionDate <= pap.EndDate)
	WHERE Budget.PropertyAccountingPeriodID = @propertyAccountingPeriodID
			  
	UPDATE Budget SET NetMonthlyTotalCash =
		(SELECT ISNULL(SUM(je.Amount), 0)
			FROM JournalEntry je
				INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = @propertyAccountingPeriodID
				--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID				
			WHERE je.GLAccountID = Budget.GLAccountID
			  AND Budget.PropertyAccountingPeriodID = @propertyAccountingPeriodID
			  AND t.PropertyID = @propertyID
			  -- Don't include closing the year entries
			  AND t.Origin NOT IN ('Y', 'E')
			  AND je.AccountingBasis = 'Cash'
			  AND je.AccountingBookID IS NULL
			  --AND t.TransactionDate >= ap.StartDate
			  --AND t.TransactionDate <= ap.EndDate)
			  AND t.TransactionDate >= pap.StartDate
			  AND t.TransactionDate <= pap.EndDate)	
	WHERE Budget.PropertyAccountingPeriodID = @propertyAccountingPeriodID			  

	--EXEC ComputeObjectsNetPeriodChange @accountID, @propertyAccountingPeriodID 
			  
	UPDATE PropertyAccountingPeriod SET Closed = 1 WHERE PropertyAccountingPeriodID = @propertyAccountingPeriodID
	
	-- Update the current property accounting period if 
	-- the current property accounting period is the one being closed
	IF ((SELECT TOP 1 CurrentPropertyAccountingPeriodID FROM Property WHERE PropertyID = @propertyID) = @propertyAccountingPeriodID)
	BEGIN
		UPDATE Property SET CurrentPropertyAccountingPeriodID = (SELECT TOP 1 pap.PropertyAccountingPeriodID
																	FROM PropertyAccountingPeriod pap				
																		--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
																	WHERE pap.PropertyID = @propertyID
																	  AND pap.AccountID = @accountID
																	  AND pap.Closed = 0
																	ORDER BY pap.EndDate)
		WHERE Property.CurrentPropertyAccountingPeriodID = @propertyAccountingPeriodID
	END

	-- Return the current accounting period name
	SELECT TOP 1 pap.EndDate 
	FROM AccountingPeriod ap
	INNER JOIN PropertyAccountingPeriod pap ON ap.AccountingPeriodID = pap.AccountingPeriodID
	WHERE pap.PropertyAccountingPeriodID = (SELECT TOP 1 CurrentPropertyAccountingPeriodID
											FROM Property
											WHERE PropertyID = @propertyID)
	
END



GO
