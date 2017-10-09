SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 30, 2013
-- Description:	Gets information for a given posted ChargeDistribution
-- =============================================
CREATE PROCEDURE [dbo].[GetPostedChargeDistributionInfo] 
	-- Add the parameters for the stored procedure here
	@chargeDistributionID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT  cd.Name AS 'ChargeDistributionName',
			cd.PostingDate,
			p.PropertyID,
			p.Name AS 'PropertyName',
			cd.BuildingIDs,
			(SELECT SUM(BilledAmount)
				FROM [ChargeDistributionDetail]
				WHERE ChargeDistributionDetailID = cdd.ChargeDistributionDetailID) AS 'BilledAmount',
			(SELECT SUM(BilledAmount)
				FROM [ChargeDistributionDetail]
				WHERE ChargeDistributionDetailID = cdd.ChargeDistributionDetailID) AS 'DistributedAmount',
			cdd.[Description],
			v.CompanyName AS 'VendorName',
			(SELECT SUM(Amount)
				FROM [Transaction] 
				WHERE PostingBatchID = cdd.PostingBatchID) AS 'SumOfChargesPosted',
			(SELECT COUNT(*)
				FROM [Transaction] 
				WHERE PostingBatchID = cdd.PostingBatchID) AS 'TotalTransactionsPosted',
			cdd.[ChargeDistributionDetailID],
			cd.DocumentID
		FROM ChargeDistribution cd 
			INNER JOIN ChargeDistributionDetail cdd ON cd.ChargeDistributionID = cdd.ChargeDistributionID
			INNER JOIN Property p ON cd.PropertyID = p.PropertyID
			LEFT JOIN Vendor v ON cdd.VendorID = v.VendorID
		WHERE cd.ChargeDistributionID = @chargeDistributionID
		ORDER BY cdd.[OrderBy]
			
END
GO
