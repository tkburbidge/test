SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 28, 2012
-- Description:	Gets the data for the BankDepositDetail Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_BNKACCT_BankDepositDetails] 
	-- Add the parameters for the stored procedure here
	@batchID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #Payments (
		PaymentID			uniqueidentifier		not null,
		Reference			nvarchar(50)			not null,
		[Date]				date					null,
		Unit				nvarchar(20)			null,
		PaddedUnit			nvarchar(100)			null,
		PropertyID			uniqueidentifier		null,
		PropertyName		nvarchar(50)			null,
		Name				nvarchar(1000)			null,
		[Description]		nvarchar(500)			null,
		PaymentMethod		nvarchar(200)			null,
		TransactionType		nvarchar(25)			null,
		Amount				money					null,
		Alteration			bit						null)
		
	CREATE TABLE #Applications (
		PaymentID					uniqueidentifier		not null,
		ObjectID					uniqueidentifier		null,
		ApplicationDate				date					null,
		ChargeLedgerItemTypeName	nvarchar(50)			null,
		ChargeDescription			nvarchar(1000)			null,
		ApplicationAmount			money					null)

	INSERT INTO #Payments
		SELECT DISTINCT
				py.PaymentID AS 'PaymentID',
				py.ReferenceNumber AS 'Reference',
				py.Date AS 'Date',
				u.Number AS 'Unit',
				u.PaddedNumber,
				prop.PropertyID,
				prop.Name AS 'PropertyName',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Name',	
				py.[Description] AS 'Description',
				py.[Type] AS 'PaymentMethod',
				tt.Name AS 'TransactionType',
				py.Amount AS 'Amount',
				CASE
					WHEN (py.Reversed = 1 AND (py.ReversedReason IN ('Non-Sufficient Funds', 'Credit Card Recapture'))) THEN CAST(0 AS BIT)
					WHEN (py.Amount < 0 AND t.Origin = 'H') THEN CAST(0 AS BIT) -- Housing adjustments
					WHEN (py.Amount < 0) THEN CAST(1 AS BIT)
					ELSE py.Reversed END AS 'Alteration'		
			FROM Payment py
				INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN Property prop ON t.PropertyID = prop.PropertyID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID  AND (tt.Name IN ('Payment', 'Deposit'))
				INNER JOIN UnitLeaseGroup ulg ON py.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			WHERE py.BatchID = @batchID
			  AND t.LedgerItemTypeID IS NOT NULL
			  AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
								FROM Lease  
								INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
								WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
								ORDER BY Ordering.OrderBy)
									 
		UNION
		
		SELECT DISTINCT
				py.PaymentID AS 'PaymentID',
				py.ReferenceNumber AS 'Reference',
				py.Date AS 'Date',
				null AS 'Unit',
				null,
				prop.PropertyID,
				prop.Name,
				CASE
					WHEN (p.PersonID IS NOT NULL) THEN p.PreferredName + ' ' + p.LastName
					WHEN (woita.WOITAccountID IS NOT NULL) THEN woita.Name
					END AS 'Name',	
				py.Description AS 'Description',
				py.[Type] AS 'PaymentMethod',
				tt.Name AS 'TransactionType',
				py.Amount AS 'Amount',
				CASE
					WHEN (py.Reversed = 1 AND (py.ReversedReason IN ('Non-Sufficient Funds', 'Credit Card Recapture'))) THEN CAST(0 AS BIT)
					WHEN (py.Amount < 0 AND t.Origin = 'H') THEN CAST(0 AS BIT)
					WHEN (py.Amount < 0) THEN CAST(1 AS BIT)
					ELSE py.Reversed END AS 'Alteration'		
			FROM Payment py
				INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN Property prop ON t.PropertyID = prop.PropertyID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID  AND (tt.Name IN ('Payment', 'Deposit'))
				LEFT JOIN Person p ON t.ObjectID = p.PersonID
				LEFT JOIN WOITAccount woita ON t.ObjectID = woita.WOITAccountID
			WHERE py.BatchID = @batchID
			  AND tt.[Group] NOT IN ('Lease')
					
	INSERT #Applications
		SELECT	--DISTINCT 
				#pay.PaymentID,
				ta.ObjectID AS 'ObjectID',
				ta.TransactionDate AS 'ApplicationDate',
				CASE
					-- If the origin is 'T' then it was a transferred payment and we want to report is as such
					WHEN (ta.Origin = 'T') THEN 'Transferred'
					-- If a deposit and the LedgerItemType is null then set the name to the applied Ledger Item Type
					WHEN ((tta.Name = 'Deposit') AND (lit.Name IS NULL)) THEN lita.Name					
					-- Report prepayments
					WHEN (tta.Name = 'Payment') AND (ta.AppliesToTransactionID IS NULL) THEN 'Prepayment'
					-- Show balance transfers
					WHEN (tta.Name IN ('Balance Transfer Deposit', 'Balance Transfer Payment')) THEN 'Balance Transfer'
					-- Show deposit applications
					WHEN (tta.Name IN ('Deposit Applied to Balance', 'Deposit Applied to Deposit')) THEN 'Deposit Application'
					ELSE lit.Name END AS 'ChargeLedgerItemTypeName',
				t.[Description] AS 'ChargeDescription',
				ta.Amount AS 'ApplicationAmount'
			FROM Payment pay
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] ta ON pt.TransactionID = ta.TransactionID
				INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name NOT IN ('Prepayment', 'Balance Transfer Payment', 'Deposit Applied to Balance')
				LEFT JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
				LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN LedgerItemType lita ON ta.LedgerItemTypeID = lita.LedgerItemTypeID
				INNER JOIN #Payments #pay ON pay.PaymentID = #pay.PaymentID
			WHERE #pay.Alteration = 0
				AND tar.TransactionID IS NULL
				AND ta.ReversesTransactionID IS NULL
				--AND ta.Amount > 0
				
	-- Get payment refunds						 		
	INSERT #Applications
		SELECT
			#pay.PaymentID,
			pr.ObjectID,
			pr.TransactionDate,
			'Payment Refund',
			'Payment Refund',
			-pr.Amount
		FROM Payment pay
			INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] ta ON pt.TransactionID = ta.TransactionID
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID --AND tta.Name IN ('Prepayment')
			INNER JOIN [Transaction] pr ON pr.AppliesToTransactionID = ta.TransactionID
			INNER JOIN [TransactionType] prta on prta.TransactionTypeID = pr.TransactionTypeID AND prta.Name = 'Payment Refund'
			LEFT JOIN [Transaction] prrt ON prrt.ReversesTransactionID = pr.TransactionID
			INNER JOIN #Payments #pay ON pay.PaymentID = #pay.PaymentID			
		WHERE #pay.Alteration = 0
			AND prrt.TransactionID IS NULL			
						 		
	SELECT * FROM #Payments order by PaddedUnit
	--SELECT * FROM #Applications order by PaymentID
	SELECT	#pay.PaymentID AS 'PaymentID',
			#pay.Reference AS 'Reference',
			#pay.[Date] AS 'PaymentDate',
			#pay.TransactionType AS 'TransactionType',
			u.Number AS 'Unit',
			#pay.Name AS 'Name',
			#pay.[Description] AS 'Description',
			#pay.PaymentMethod AS 'PaymentMethod',
			#pay.Amount AS 'PaymentAmount',
			#app.ApplicationDate AS 'ApplicationDate',
			#app.ChargeLedgerItemTypeName AS 'ChargeLedgerItemTypeName',
			#app.ChargeDescription AS 'ChargeDescription',
			#app.ApplicationAmount AS 'ApplicationAmount',
			ISNULL(u.PaddedNumber, '') AS 'PaddedUnit',
			ISNULL(u.PaddedNumber, '') + CAST(#pay.PaymentID AS nvarchar(40)) AS 'PaddedUnitPaymentID'
		FROM #Payments #pay
			INNER JOIN #Applications #app ON #pay.PaymentID = #app.PaymentID
			LEFT JOIN UnitLeaseGroup ulg ON #app.ObjectID = ulg.UnitLeaseGroupID
			LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
		ORDER BY PaddedUnit				
END
GO
