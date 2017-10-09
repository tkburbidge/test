SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 12, 2013
-- Description:	Gets a customized Income Summary Statement
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_IncomeSummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 


	@accountingPeriodID uniqueidentifier = null,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #IncomeSummary (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		LedgerItemTypeID uniqueidentifier null,
		LedgerItemTypeName nvarchar(50) null,
		TransactionType nvarchar(50) null,
		ChargeTotal money null,
		Payments money null,
		NSFs money null,
		PriorPayments money null,
		DepositsApplied money null)

	CREATE TABLE #Trans1 (
		TransactionID uniqueidentifier not null,
		LedgerItemTypeID uniqueidentifier null,
		PropertyID uniqueidentifier null,
		Amount money null)
		
	CREATE TABLE #AppliedTrans (
		ATransactionID uniqueidentifier not null,
		ALedgerItemTypeID uniqueidentifier null,
		PropertyID uniqueidentifier null,
		PDate date null,
		Amount money null,
		TTName nvarchar(50),
		PaymentID uniqueidentifier null,
		PaymentType nvarchar(100) null)
		
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate date NOT NULL,
		EndDate date NOT NULL)
		
	INSERT #PropertiesAndDates
		SELECT pIDs.Value, pap.StartDate, pap.EndDate
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		
	INSERT #Trans1 
		SELECT	DISTINCT
				t.TransactionID,
				t.LedgerItemTypeID,
				t.PropertyID,
				t.Amount
			FROM [Transaction] t

				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Charge')
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID				
				LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
			WHERE t.TransactionDate >= #pad.StartDate --@startDate
			  AND t.TransactionDate <= #pad.EndDate --@endDate
			  AND t.AccountID = @accountID			  	  	  	

			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
	
	-- Get all payments with an application date in the given date range
	INSERT #AppliedTrans
		SELECT	DISTINCT
				ta.TransactionID AS 'ATransactionID',
				--apt.LedgerItemTypeID AS 'ALedgerItemTypeID',
				t.LedgerItemTypeID AS 'ALedgerItemTypeID',
				ta.PropertyID,
				pay.[Date] AS 'PDate',
				ta.Amount,
				tt.Name AS 'TTName',
				--CASE
				--	WHEN (0 < (SELECT COUNT(*)
				--					FROM [Transaction] tbtp
				--						INNER JOIN TransactionType ttbtp ON tbtp.TransactionTypeID = ttbtp.TransactionTypeID 
				--												AND ttbtp.Name IN ('Balance Transfer Payment')
				--						INNER JOIN [PaymentTransaction] pttbtp ON tbtp.TransactionID = pttbtp.TransactionID 
				--						INNER JOIN Payment ptbtp ON pttbtp.PaymentID = ptbtp.PaymentID
				--						INNER JOIN [PaymentTransaction] ptta ON ptta.PaymentID = ptbtp.PaymentID AND ptta.TransactionID = ta.TransactionID))
				--		THEN 'Deposit Applied'
				--	ELSE tt.Name END AS 'TTName',
				pay.PaymentID AS 'PaymentID',
				pay.[Type]
			FROM [Transaction] ta
				INNER JOIN TransactionType tt ON ta.TransactionTypeID = tt.TransactionTypeID
				-- Get the original charge the payment applied to
				INNER JOIN [Transaction] t ON t.TransactionID = ta.AppliesToTransactionID	
				-- Transaction Type of the charge the payment applies to
				INNER JOIN [TransactionType] ctt ON ctt.TransactionTypeID = t.TransactionTypeID									
				INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
				INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
				INNER JOIN #PropertiesAndDates #pad ON ta.PropertyID = #pad.PropertyID
			WHERE 
				tt.Name IN ('Payment')			
			  AND tt.[Group] <> 'Invoice'
			  -- Don't show the transactions created to transfer payments from one ledger to another
			  AND ctt.Name <> 'Payment'
			  AND ta.TransactionDate >= #pad.StartDate --@startDate
			  AND ta.TransactionDate <= #pad.EndDate  --@endDate
			  -- AppliesToTransactionID Gets set to the Reversed Charge
			  -- Don't include reveresed payments here	
			  AND ta.ReversesTransactionID IS NULL
			  
	--SELECT * FROM #AppliedTrans WHERE ALedgerItemTypeID = '0400aae3-1c63-4077-a5c4-dcd3d88a65c3'
	-- Get all reversed payment applications where the reversal happens within the given date range			  
	INSERT #AppliedTrans
		SELECT	DISTINCT
				tar.TransactionID AS 'ATransactionID',				
				t.LedgerItemTypeID AS 'ALedgerItemTypeID',
				tar.PropertyID,
				pay.[Date] AS 'PDate',
				tar.Amount,
				tt.Name AS 'TTName',
				pay.PaymentID AS 'PaymentID',
				pay.[Type]
			FROM [Transaction] tar
				INNER JOIN TransactionType tt ON tar.TransactionTypeID = tt.TransactionTypeID
				-- Get the original payment that was reversed by tar
				INNER JOIN [Transaction] ta ON ta.TransactionID = tar.ReversesTransactionID			
				-- Get the original charge the payment applied to
				INNER JOIN [Transaction] t ON t.TransactionID = ta.AppliesToTransactionID				
				INNER JOIN PaymentTransaction pt ON tar.TransactionID = pt.TransactionID
				INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
				INNER JOIN #PropertiesAndDates #pad ON tar.PropertyID = #pad.PropertyID
			WHERE 
				tt.Name IN ('Payment')				
			  AND tt.[Group] <> 'Invoice'

			  AND tar.TransactionDate >= #pad.StartDate --@startDate
			  AND tar.TransactionDate <= #pad.EndDate  --@endDate				  		  
	--SELECT * FROM #AppliedTrans WHERE ALedgerItemTypeID = '0400aae3-1c63-4077-a5c4-dcd3d88a65c3'  
			
	UPDATE #at SET TTName = 'Deposit Applied'
		FROM #AppliedTrans #at
			INNER JOIN PaymentTransaction pt ON #at.PaymentID = pt.PaymentID
			INNER JOIN #PropertiesAndDates #pad ON #at.PropertyID = #pad.PropertyID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID AND t.Amount > 0 AND t.TransactionDate <= #pad.EndDate --@endDate
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Deposit Applied to Balance', 'Balance Transfer Payment')
	
	INSERT #IncomeSummary
		SELECT	DISTINCT
				p.PropertyID AS 'PropertyID',
				p.Name AS 'PropertyName',
				lit.LedgerItemTypeID AS 'LedgerItemTypeID',
				lit.Name AS 'LedgerItemTypeName',
				'Charge',
				SUM(#t1.Amount) AS 'ChargeTotal',
				null,
				null,
				null,
				null
			FROM #Trans1 #t1
				INNER JOIN Property p ON #t1.PropertyID = p.PropertyID
				INNER JOIN LedgerItemType lit ON #t1.LedgerItemTypeID = lit.LedgerItemTypeID
			GROUP BY p.Name, p.PropertyID, lit.LedgerItemTypeID, lit.Name
			
	INSERT #IncomeSummary
		SELECT DISTINCT
			p.PropertyID,
			p.Name AS 'PropertyName',
			lit.LedgerItemTypeID AS 'LedgerItemTypeID',
			lit.Name AS 'LedgerItemTypeName',
			'Charge',
			0 AS 'ChargeTotal',
			null,
			null,
			null,
			null
		FROM #AppliedTrans #apt
			LEFT JOIN #Trans1 #t1 ON #t1.LedgerItemTypeID = #apt.ALedgerItemTypeID
			INNER JOIN LedgerItemType lit ON #apt.ALedgerItemTypeID = lit.LedgerItemTypeID
			INNER JOIN Property p ON #apt.PropertyID = p.PropertyID
		WHERE #t1.LedgerItemTypeID IS NULL			
				
	UPDATE #is SET Payments =  ISNULL((SELECT SUM(#apt.Amount) 
									FROM #AppliedTrans #apt
										INNER JOIN #PropertiesAndDates #pad ON #apt.PropertyID = #pad.PropertyID
									WHERE #apt.PDate >= #pad.StartDate --@startDate
									  AND #apt.PDate <= #pad.EndDate --@endDate
									  AND #apt.ALedgerItemTypeID = #is.LedgerItemTypeID
									  AND #apt.PropertyID = #is.PropertyID
									  AND #apt.TTName = 'Payment'
									  -- Don't include NSF and Credit Card Recapture reversal payments
									  AND #apt.PaymentType NOT IN ('NSF', 'Credit Card Recapture')
									GROUP BY #apt.PropertyID, #apt.ALedgerItemTypeID), 0)
		FROM #IncomeSummary #is
		
	UPDATE #is SET PriorPayments =  ISNULL((SELECT SUM(#apt.Amount) 
									FROM #AppliedTrans #apt
										INNER JOIN #PropertiesAndDates #pad ON #apt.PropertyID = #pad.PropertyID
									WHERE (#apt.PDate < #pad.StartDate /*@startDate*/ OR #apt.PDate > #pad.EndDate /*@endDate*/)
									  AND #apt.ALedgerItemTypeID = #is.LedgerItemTypeID
									  AND #apt.PropertyID = #is.PropertyID
									  AND #apt.TTName = 'Payment'
									  -- Don't include NSF and Credit Card Recapture reversal payments
									  AND #apt.PaymentType NOT IN ('NSF', 'Credit Card Recapture')
									GROUP BY #apt.PropertyID, #apt.ALedgerItemTypeID), 0)
		FROM #IncomeSummary #is		

	UPDATE #is SET DepositsApplied =  ISNULL((SELECT SUM(#apt.Amount) 
											FROM #AppliedTrans #apt
											WHERE 
												--#apt.PDate >= @startDate
											  --AND #apt.PDate <= @endDate
											  #apt.ALedgerItemTypeID = #is.LedgerItemTypeID
											  AND #apt.PropertyID = #is.PropertyID
											  AND #apt.TTName = 'Deposit Applied'
											GROUP BY #apt.PropertyID, #apt.ALedgerItemTypeID), 0)
		FROM #IncomeSummary #is
		
	UPDATE #is SET NSFs = ISNULL((SELECT SUM(-#apt.Amount)
								FROM #AppliedTrans #apt	
									INNER JOIN #PropertiesAndDates #pad ON #apt.PropertyID = #pad.PropertyID								
								WHERE #apt.PDate >= #pad.StartDate --@startDate
								  AND #apt.PDate <= #pad.EndDate --@endDate
								  -- Only include NSF and Credit Card Recapture reversal payments
								  AND #apt.PaymentType IN ('NSF', 'Credit Card Recapture')
								  AND #apt.Amount < 0
								  AND #apt.ALedgerItemTypeID = #is.LedgerItemTypeID
								  AND #apt.PropertyID = #is.PropertyID
								GROUP BY #apt.PropertyID, #apt.ALedgerItemTypeID), 0)
		FROM #IncomeSummary #is

	SELECT * FROM #IncomeSummary	
	UNION ALL	
	SELECT	
		PropertyID,
		PropertyName,
		LedgerItemTypeID,
		LedgerItemTypeName,
		'Credit' AS 'TransactionType',
		Amount,
		0,
		0,
		0,
		0
	FROM (SELECT PropertyID, PropertyName, LedgerItemTypeID, Payments.LedgerItemTypeName, ISNULL(SUM(Payments.Amount), 0) Amount
			 FROM (SELECT DISTINCT 
						t.PropertyID,
						p.Name AS 'PropertyName',
						py.PaymentID,
						lit.LedgerItemTypeID,
						lit.Name AS 'LedgerItemTypeName',
						py.Amount							
					FROM Payment py
						INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
						INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
						INNER JOIN Property p ON t.PropertyID = p.PropertyID	
						INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID						
						LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
						LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
					WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
					  AND tt.Name IN ('Credit')
					  AND tt.[Group] <> 'Invoice'
					  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
					  AND py.[Date] >= #pad.StartDate --@startDate
					  AND py.[Date] <= #pad.EndDate  --@endDate
					  AND NOT (tt.Name IN ('Payment', 'Credit') AND t.LedgerItemTypeID IS NULL)) Payments
			GROUP BY Payments.PropertyID, Payments.PropertyName, Payments.LedgerItemTypeID, Payments.LedgerItemTypeName) SummedPayments
			
	
END
GO
