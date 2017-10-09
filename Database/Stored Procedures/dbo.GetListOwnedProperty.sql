SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Tony Morgan
-- Create date: 11/05/2014
-- Description:	Returns a list of properties owned and their info, given the owner's vendor id
-- =============================================
CREATE PROCEDURE  [dbo].[GetListOwnedProperty]
	-- Add the parameters for the stored procedure here
	@accountID BIGINT, 
	@vendorID UNIQUEIDENTIFIER
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT 
		p.Name AS 'Name', 
		p.PropertyID AS 'PropertyID',
		(SELECT -SUM(je.Amount)
				FROM JournalEntry je
				INNER JOIN [Transaction] t ON t.TransactionID = je.TransactionID AND t.PropertyID = vp.PropertyID
				WHERE GLAccountID = op.DistributionGLAccountID
				  AND AccountingBasis = s.DefaultAccountingBasis) AS 'DistributionBalance',
			(SELECT -SUM(je.Amount)
				FROM JournalEntry je
				INNER JOIN [Transaction] t ON t.TransactionID = je.TransactionID AND t.PropertyID = vp.PropertyID
				WHERE GLAccountID = op.EquityGLAccountID
				  AND AccountingBasis = s.DefaultAccountingBasis) AS 'EquityBalance',
			(SELECT opp1.Percentage
				FROM OwnerPropertyPercentage opp1
					INNER JOIN OwnerPropertyPercentageGroup oppg1 ON opp1.OwnerPropertyPercentageGroupID = oppg1.OwnerPropertyPercentageGroupID
				WHERE opp1.OwnerPropertyID = op.OwnerPropertyID
				  AND oppg1.OwnerPropertyPercentageGroupID = (SELECT TOP 1 OwnerPropertyPercentageGroupID 		
																  FROM OwnerPropertyPercentageGroup oppg2
																  WHERE oppg2.PropertyID = p.PropertyID
																  ORDER BY [DateCreated] DESC)) AS 'Percentage',
		op.DateInactive AS 'DateInactive'
	FROM [Owner] o 
		INNER JOIN OwnerProperty op ON op.OwnerID = o.OwnerID
		INNER JOIN VendorProperty vp ON vp.VendorPropertyID = op.VendorPropertyID
		INNER JOIN Property p ON vp.PropertyID = p.PropertyID
		INNER JOIN Settings s ON s.AccountID = @accountID
	WHERE o.VendorID = @vendorID AND o.AccountID = @accountID
END

GO
