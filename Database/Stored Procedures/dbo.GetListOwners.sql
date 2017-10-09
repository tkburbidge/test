SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 30, 2014
-- Description:	Gets the list of owners
-- =============================================
CREATE PROCEDURE [dbo].[GetListOwners] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	v.CompanyName AS 'Name',
			op.OwnerID AS 'OwnerID',
			(SELECT -SUM(je.Amount)
				FROM JournalEntry je
				INNER JOIN [Transaction] t ON t.TransactionID = je.TransactionID AND t.PropertyID = vp.PropertyID
				WHERE GLAccountID = op.DistributionGLAccountID
				  AND AccountingBookID IS NULL
				  AND AccountingBasis = s.DefaultAccountingBasis) AS 'DistributionBalance',
			(SELECT -SUM(je.Amount)
				FROM JournalEntry je
				INNER JOIN [Transaction] t ON t.TransactionID = je.TransactionID AND t.PropertyID = vp.PropertyID
				WHERE GLAccountID = op.EquityGLAccountID
				  AND AccountingBookID IS NULL
				  AND AccountingBasis = s.DefaultAccountingBasis) AS 'EquityBalance',
			(SELECT opp1.Percentage
				FROM OwnerPropertyPercentage opp1
					INNER JOIN OwnerPropertyPercentageGroup oppg1 ON opp1.OwnerPropertyPercentageGroupID = oppg1.OwnerPropertyPercentageGroupID
				WHERE opp1.OwnerPropertyID = op.OwnerPropertyID
				  AND oppg1.OwnerPropertyPercentageGroupID = (SELECT TOP 1 OwnerPropertyPercentageGroupID		
																  FROM OwnerPropertyPercentageGroup
																  WHERE PropertyID = @propertyID
																  ORDER BY [Date] DESC, DateCreated DESC)) AS 'Percentage',
			op.DateInactive
		FROM OwnerProperty op
			INNER JOIN VendorProperty vp ON op.VendorPropertyID = vp.VendorPropertyID
			INNER JOIN Vendor v ON vp.VendorID = v.VendorID
			INNER JOIN Settings s ON s.AccountID = @accountID
		WHERE vp.PropertyID = @propertyID
			AND op.AccountID = @accountID
			AND v.IsActive = 1
			
														
														
			
		

END
GO
