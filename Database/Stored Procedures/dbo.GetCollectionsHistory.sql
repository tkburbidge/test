SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 2, 2012
-- Description:	Gets the Collections History for a given ObjectID
-- =============================================
CREATE PROCEDURE [dbo].[GetCollectionsHistory] 
	-- Add the parameters for the stored procedure here
	@unitLeaseGroupID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #CollectionDetails 
	(
		CollectionsDetailID uniqueidentifier,
		PropertyAccountingPeriodID uniqueidentifier,				
		ChargeDate date,
		Description nvarchar(250),
		AmountBilled money,
		AmountPaid money null,
		LastPaymentDate date null
	)
	
	INSERT INTO #CollectionDetails
	SELECT cdt.CollectionDetailID AS 'CollectionsDetailID', 

			pap.PropertyAccountingPeriodID,
			t.TransactionDate AS 'ChargeDate', 			
			t.[Description] AS 'Description', 
			t.Amount AS 'AmountBilled',
			(SELECT ISNULL(SUM(ta.Amount), 0)
			 FROM [Transaction] ta
			 LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
			 WHERE ta.AppliesToTransactionID = t.TransactionID
			 AND tar.TransactionID IS NULL) AS 'AmountPaid',
			(SELECT TOP 1 p.Date
			 FROM [Transaction] ta
			 LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
			 INNER JOIN PaymentTransaction pt on pt.TransactionID = ta.TransactionID
			 INNER JOIN Payment p on p.PaymentID = pt.PaymentID
			 WHERE ta.AppliesToTransactionID = t.TransactionID
				AND tar.TransactionID IS NULL
			 ORDER BY p.Date DESC) AS 'LastPaymentDate'
		FROM CollectionDetailTransaction cdt
			INNER JOIN [Transaction] t ON cdt.TransactionID = t.TransactionID
			LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID			
			--INNER JOIN [CollectionDetail] cd ON cdt.CollectionDetailID = cd.CollectionDetailID
			--INNER JOIN [AccountingPeriod] ap ON ap.AccountID = t.AccountID AND ap.StartDate <= t.TransactionDate AND ap.EndDate >= t.TransactionDate
			INNER JOIN [PropertyAccountingPeriod] pap ON t.PropertyID = pap.PropertyID AND pap.StartDate <= t.TransactionDate AND pap.EndDate >= t.TransactionDate
		WHERE t.ObjectID = @unitLeaseGroupID	  
		  AND tr.TransactionID IS NULL		 	
	
	SELECT 
		cds.CollectionsDetailID,
		--ap.EndDate AS 'PeriodEndDate',
		pap.EndDate AS 'PeriodEndDate',
		--cds.AccountingPeriodID,
		ap.AccountingPeriodID,
		ulgap.ULGAPInformationID,
		ulgap.DelinquentReason,
		cds.ChargeDate,
		cds.LastPaymentDate,
		cds.Description,
		cds.AmountBilled,
		cds.AmountPaid
	FROM	
		(SELECT 
			cd.CollectionsDetailID,

			cd.PropertyAccountingPeriodID,
			MIN(cd.ChargeDate) AS 'ChargeDate',
			cd.Description,
			SUM(cd.AmountBilled) AS 'AmountBilled',
			SUM(cd.AmountPaid) AS 'AmountPaid',
			MIN(cd.LastPaymentDate) AS 'LastPaymentDate'
		 FROM #CollectionDetails cd
	 	GROUP BY cd.CollectionsDetailID, cd.PropertyAccountingPeriodID, cd.[Description]) cds
	--INNER JOIN AccountingPeriod ap ON cds.AccountingPeriodID = ap.AccountingPeriodID
	INNER JOIN PropertyAccountingPeriod pap ON cds.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--LEFT JOIN ULGAPInformation ulgap ON ulgap.AccountingPeriodID = cds.AccountingPeriodID AND ulgap.ObjectID = @unitLeaseGroupID	
	LEFT JOIN ULGAPInformation ulgap ON ulgap.AccountingPeriodID = ap.AccountingPeriodID AND ulgap.ObjectID = @unitLeaseGroupID	
	ORDER BY cds.ChargeDate	

END



GO
