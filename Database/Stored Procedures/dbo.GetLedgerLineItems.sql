SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 8, 2011
-- Description:	Gets LedgerLineItems
-- =============================================
CREATE PROCEDURE [dbo].[GetLedgerLineItems] 
	-- Add the parameters for the stored procedure here
	@AccountID bigint = null,
	@PropertyID uniqueidentifier = null,
	@ObjectID GuidCollection READONLY, 
	@ObjectGroup StringCollection READONLY,
	@StartDate datetime2 = null,
	@EndDate datetime2 = null,
	@Origins StringCollection readonly,
	@IncludeAllDeposits bit = 0,
	@SortDesc bit = 0,
	@includePendingProcessorPayments bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #TempLineItems (
		ID								uniqueidentifier		NOT NULL,
		[Date]							datetime				NOT NULL,
		UnitNumber						nvarchar(MAX)			NULL,
		[Type]							nvarchar(MAX)			NULL,
		LedgerItemTypeAbbreviation		nvarchar(MAX)			NULL,
		LedgerItemTypeID				uniqueidentifier		NULL,
		BatchNumber						int						NULL,
		BatchBankTransactionID			uniqueidentifier		NULL,
		[Description]					nvarchar(250)			NULL,
		Reference						nvarchar(50)			NULL,
		PaymentType						nvarchar(50)			NULL,
		Amount							money					NOT NULL,
		TaxAmount						money					NULL,
		Notes							nvarchar(MAX)			NULL,
		NotVisible						bit						NOT NULL,
		Reversed						bit						NOT NULL,
		IsRent							bit						NOT NULL,		
		ReversesTransactionID			uniqueidentifier		NULL,
		SortDate						datetime				NULL,
		OrderMe							int						NULL,
		Origin							nvarchar(10)			NULL,
		IsGainLossToLease				bit						NOT NULL,
		IsDepositInterestTransaction	bit						NOT NULL

		)
	
	CREATE TABLE #ObjectIDs ( ObjectID uniqueidentifier )
	INSERT INTO #ObjectIDs SELECT Value FROM @ObjectID

	DECLARE @filterOrigin bit
	SET @filterOrigin = (SELECT COUNT(Value) FROM @Origins)
		
	INSERT #TempLineItems
		SELECT (CASE WHEN t.Origin = 'T' AND tt.Name IN ('Prepayment', 'Over Credit', 'Deposit', 'Payment', 'Credit') AND pt.PaymentID IS NOT NULL THEN pt.PaymentID
					 ELSE t.TransactionID
				END) as 'ID',
				t.TransactionDate as 'Date',
				u.Number as 'UnitNumber',
				(CASE WHEN tt.Name = 'Prepayment' THEN 'Payment'
					  WHEN tt.Name = 'Over Credit' THEN 'Credit'
					  ELSE tt.Name
				END) as 'Type',
				lit.Abbreviation as 'LedgerItemTypeAbbreviation',
				lit.LedgerItemTypeID as 'LedgerItemTypeID',
				null AS 'BatchNumber',
				NULL AS 'BatchBankTransactionID',
				t.[Description] as 'Description',
				null as 'Reference',
				null as 'PaymentType',
				t.Amount as 'Amount',
				0.0 as 'TaxAmount',
				t.Note as 'Note',
				t.NotVisible as 'NotVisible',
				(CASE WHEN tr.TransactionID IS NOT NULL OR t.ReversesTransactionID IS NOT NULL THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END ) AS 'Reversed',
			    ISNULL(lit.IsRent, CAST(0 AS BIT)) AS 'IsRent',
				null as 'ReversesTransactionID',	
				t.TimeStamp as 'SortDate',
				lit.OrderBy as 'OrderMe',
				t.Origin,
				0 AS 'IsGainLossToLease',
				(CASE WHEN att.Name = 'Deposit Interest Payment' THEN CAST(1 AS BIT)
					  ELSE CAST(0 AS BIT)
				END) AS 'IsDepositInterestTransaction'
			FROM [Transaction] t
				INNER JOIN [TransactionType] tt on t.TransactionTypeID = tt.TransactionTypeID
				LEFT JOIN [UnitLeaseGroup] ulg on ulg.UnitLeaseGroupID = t.ObjectID
				LEFT JOIN [Unit] u on u.UnitID = ulg.UnitID
				LEFT JOIN [LedgerItemType] lit on lit.LedgerItemTypeID = t.LedgerItemTypeID
				LEFT JOIN [Transaction] tr on tr.ReversesTransactionID = t.TransactionID
				LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID
				LEFT JOIN [PaymentTransaction] pt ON pt.TransactionID = t.TransactionID				
				LEFT JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
				LEFT JOIN [TransactionType] att ON att.TransactionTypeID = at.TransactionTypeID
				INNER JOIN #ObjectIDs #o ON #o.ObjectID = t.ObjectID
			WHERE ((tt.Name in ('Charge', 'Balance Transfer Payment', 'Balance Transfer Deposit', 'Deposit Applied to Deposit', 'Deposit Applied to Balance'))
					-- If a Payment, Credit, or Deposit is transferred we need to include the single transactions
					-- that make up that transfer
					OR ((tt.Name IN ('Prepayment', 'Over Credit', 'Deposit', 'Payment', 'Credit') AND t.Origin = 'T')))
				AND t.AccountID = @AccountID
				AND t.PropertyID = @PropertyID
				--AND tt.[Group] in (select Value from @ObjectGroup)
				AND ((t.TransactionDate >= @StartDate) OR (tt.Name IN ('Balance Transfer Deposit','Deposit Applied to Deposit') AND @IncludeAllDeposits = 1) OR (t.Origin = 'T' AND tt.Name = 'Deposit' AND @IncludeAllDeposits = 1))
				AND ((t.TransactionDate <= @EndDate) OR (tt.Name IN ('Balance Transfer Deposit','Deposit Applied to Deposit') AND @IncludeAllDeposits = 1) OR (t.Origin = 'T' AND tt.Name = 'Deposit' AND @IncludeAllDeposits = 1))
				AND ((@filterOrigin = 0) OR (t.Origin IN (SELECT Value FROM @Origins)))
				--AND ((NOT EXISTS (SELECT * FROM @ObjectID)) OR (t.ObjectID in (SELECT Value FROM @ObjectID)))
				AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
	
	INSERT #TempLineItems		
		SELECT DISTINCT 
				p.PaymentID as 'ID', 
				p.[Date] as 'Date', 
				u.Number as 'UnitNumber',
				tt.Name as 'Type', 
				lit.Abbreviation as 'LedgerItemTypeAbbreviation', 
				lit.LedgerItemTypeID as 'LedgerItemTypeID',
				b.Number AS 'Batch',
				b.BankTransactionID AS 'BatchBankTransactionID',
				p.Description as 'Description', 
				p.ReferenceNumber as 'Reference', 
				p.Type as 'PaymentType',
				p.Amount as 'Amount', 
				0.0 as 'TaxAmount',
				p.Notes as 'Note',
				CASE 
					WHEN p.Reversed = 1 AND (p.ReversedReason IN ('Posting Error', 'Move In', 'Move Out')) THEN 1
					WHEN p.Amount < 0 AND (p.[Type] IN ('Posting Error', 'Move In', 'Move Out')) THEN 1
					ELSE 0 
				END as 'NotVisible', 	
				CASE 
					WHEN p.Reversed = 1 THEN 1
					WHEN p.Amount < 0 AND (p.[Type] IN ('Posting Error', 'Move In', 'Move Out', 'Late Payment', 'Non-Sufficient Funds', 'Credit Card Recapture', 'Other', 'Reversed')) THEN 1
					ELSE 0 
				END as 'Reversed',
				ISNULL(lit.IsRent, CAST(0 AS BIT)) AS 'IsRent',
				null as 'ReversesTransactionID',							
				p.TimeStamp as 'SortDate',
				200 as 'Orderme',
				(SELECT TOP 1 Origin
				 FROM [Transaction] ot
					INNER JOIN PaymentTransaction opt ON opt.TransactionID = ot.TransactionID				
				 WHERE opt.PaymentID = p.PaymentID
				 ORDER BY ot.[TimeStamp] DESC),
				 CAST(0 AS BIT) AS 'IsGainLossToLease',
				(CASE WHEN att.Name = 'Deposit Interest Payment' OR tt.Name = 'Deposit Interest Payment' THEN CAST(1 AS BIT)
					  ELSE CAST(0 AS BIT)
				END) AS 'IsDepositInterestTransaction'
			FROM Payment p
				INNER JOIN [PaymentTransaction] pt on p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t on t.TransactionID = pt.TransactionID
				LEFT JOIN [LedgerItemType] lit on t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN [Batch] b on b.BatchID = p.BatchID
				--LEFT JOIN [BankTransaction] bt ON bt.ObjectID = b.BankTransactionID
				--LEFT JOIN [Unit] u on u.UnitID = t.UnitID
				LEFT JOIN [UnitLeaseGroup] ulg on ulg.UnitLeaseGroupID = t.ObjectID
				LEFT JOIN [Unit] u on u.UnitID = ulg.UnitID					
				INNER JOIN [TransactionType] tt on tt.TransactionTypeID = t.TransactionTypeID
				LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = p.PostingBatchID
				LEFT JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
				LEFT JOIN [TransactionType] att ON att.TransactionTypeID = at.TransactionTypeID
				INNER JOIN #ObjectIDs #o ON #o.ObjectID = t.ObjectID
			WHERE tt.Name in ('Payment', 'Deposit', 'Deposit Interest Payment', 'Credit', 'Payment Refund', 'Deposit Refund')
				AND p.AccountID = @AccountID 
				AND t.PropertyID = @PropertyID
				--AND tt.[Group] in (select value from  @ObjectGroup)				
				AND ((p.[Date] >= @StartDate) OR (tt.Name IN ('Deposit', 'Deposit Refund', 'Deposit Interest Payment') AND @IncludeAllDeposits = 1))
				AND ((p.[Date] <= @EndDate) OR (tt.Name IN ('Deposit', 'Deposit Refund', 'Deposit Interest Payment') AND @IncludeAllDeposits = 1))				
				-- Don't include the payments or credits due to balance transfers and deposit applications
				AND NOT ((tt.Name = 'Payment' OR tt.Name = 'Credit') AND t.LedgerItemTypeID IS NULL)		
				AND ((@filterOrigin = 0) OR (t.Origin IN (SELECT Value FROM @Origins)))
				--AND ((NOT EXISTS (SELECT * FROM @ObjectID)) OR (t.ObjectID in (SELECT Value FROM @ObjectID)))
				AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
				-- When we transfer a payment, credit, or deposit the new ObjectID 
				-- transactions are tied to the same Payment record but the ledger entries
				-- for the transfer will be take care of in the above Transaction query.
				-- Make sure we only include the original Payment for the original ObjectID
				AND p.ObjectID = t.ObjectID
				
--INSERT #TempLineItems 
--	SELECT DISTINCT
--			t.TransactionID AS 'ID',
--			t.TransactionDate AS 'Date',
--			u.Number AS 'UnitNumber',
--			'Tax' AS 'Type',
--			'TAX' AS 'LedgerItemTypeAbbreviation',
--			null AS 'LedgerItemTypeID',
--			'Taxes' AS 'Description',
--			null AS 'Reference',
--			null AS 'PaymentType',
--			(SELECT SUM(ttaa.Amount)
--				FROM [Transaction] ttaa
--					INNER JOIN [TransactionType] tt ON ttaa.TransactionTypeID = tt.TransactionTypeID
--				WHERE ttaa.AppliesToTransactionID = t.TransactionID
--				  AND tt.Name IN ('Tax Charge')) AS 'Amount', 
--			null AS 'Note',
--			CAST(1 AS BIT) AS 'NotVisible',
--			CAST(0 AS BIT) AS 'IsRent',
--			null AS 'ReversesTransactionID',
--			t.TimeStamp AS 'SortDate',
--			0 AS 'OrderMe'
--	FROM [Transaction] t
--		INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
--		INNER JOIN [TransactionType] tt ON ta.TransactionTypeID = tt.TransactionTypeID
--		LEFT JOIN [UnitLeaseGroup] ulg ON t.ObjectID = ulg.UnitLeaseGroupID
--		LEFT JOIN [Unit] u ON ulg.UnitID = u.UnitID
--	WHERE tt.Name IN ('Tax Charge')
--	  AND t.TransactionID IN (SELECT DISTINCT ID FROM #TempLineItems)

	UPDATE #TempLineItems SET TaxAmount = ISNULL((SELECT SUM(ta.Amount)
												FROM [Transaction] t
													INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
													INNER JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID
												WHERE tta.Name IN ('Tax Charge')
												  AND t.TransactionID = #TempLineItems.ID
												GROUP BY t.TransactionID), 0)
		WHERE [Type] = 'Charge'
												
	UPDATE #TempLineItems SET TaxAmount = ISNULL((SELECT SUM(ta.Amount)
												FROM [Transaction] t
													INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
													INNER JOIN [PaymentTransaction] pt ON t.TransactionID = pt.TransactionID
													INNER JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID
												WHERE tta.Name IN ('Tax Credit')
												  AND pt.PaymentID = #TempLineItems.ID
												GROUP BY pt.TransactionID), 0)
		WHERE [Type] = 'Credit'
				
	
	UPDATE #TempLineItems SET IsGainLossToLease = (SELECT
													   CASE WHEN #TempLineItems.LedgerItemTypeID IN (SELECT ID
																								     FROM
																									 ((SELECT LossToLeaseLedgerItemTypeID AS ID	FROM Settings WHERE AccountID = @AccountID)
																									  UNION																				
																									 (SELECT GainToLeaseLedgerItemTypeID AS ID FROM Settings WHERE AccountID = @AccountID)) AS IDs)
															THEN 1
															ELSE 0
														END)																									 
				
	-- Update Deposit Applied to Balance, Deposit Applied to Deposit, and Deposit Refund to Interest XXXX if the original Payme t recrod
	-- the Transaction is tied to is a TransactionType of Deposit Interest Payment
				
	IF (@includePendingProcessorPayments = 1)
	BEGIN
		INSERT #TempLineItems		
			SELECT	pp.ProcessorPaymentID AS 'ID', 
					pp.DateProcessed AS 'Date',
					u.Number AS 'UnitNumber',
					'ProcessorPayment' AS [Type],
					null AS 'LedgerItemTypeAbbreviation',
					null AS 'LedgerItemTypeID',
					null AS 'BatchNumber',
					null AS 'BatchBankTransactionID',
					'Pending Online Payment' AS 'Description',
					pp.ProcessorTransactionID as 'Reference',
					pp.PaymentType AS 'PaymentType',
					pp.Amount, 
					null AS 'TaxAmount',
					null as 'Notes',
					CAST(0 AS BIT) AS 'NotVisible',
					CAST(0 AS BIT) AS 'Reversed',
					CAST(0 AS BIT) AS 'Rent',
					null AS 'ReversesTransactionID',
					pp.DateCreated AS 'SortDate',
					CAST(0 AS BIT) As 'OrderMe',
					'X' AS 'Origin',
					CAST(0 AS BIT) AS 'IsGainLossToLease',	
					CAST(0 AS BIT) AS 'IsDepositInterestTransaction'	
		FROM ProcessorPayment pp				
			INNER JOIN [Property] prop on pp.PropertyID = prop.PropertyID		
			LEFT JOIN [UnitLeaseGroup] ulg on pp.ObjectID = ulg.UnitLeaseGroupID
			LEFT JOIN [Unit] u ON u.UnitID = ulg.UnitID
			INNER JOIN #ObjectIDs #o ON #o.ObjectID = pp.ObjectID
		WHERE pp.AccountID = @accountID 
			--AND pp.ObjectID in (SELECT VALUE FROM @ObjectID)
			AND pp.DateSettled IS NULL
			AND pp.PaymentID IS NULL
			AND CONVERT(date, pp.DateProcessed) >= @StartDate
			AND CONVERT(date, pp.DateProcessed) <= @EndDate
	END
					
	IF (@SortDesc = 1)
	BEGIN
		SELECT ID, [Date], UnitNumber, [Type], BatchNumber, BatchBankTransactionID, LedgerItemTypeAbbreviation, LedgerItemTypeID, [Description], Reference,
				PaymentType, Amount, TaxAmount, Notes, NotVisible, Reversed, IsRent, SortDate, Origin, IsGainLossToLease, IsDepositInterestTransaction
			FROM #TempLineItems
			ORDER BY [Date] DESC, SortDate DESC
	END
	ELSE
	BEGIN			
		SELECT ID, [Date], UnitNumber, [Type], BatchNumber, BatchBankTransactionID, LedgerItemTypeAbbreviation, LedgerItemTypeID, [Description], Reference,
				PaymentType, Amount, TaxAmount, Notes, NotVisible, Reversed, IsRent, SortDate, Origin, IsGainLossToLease, IsDepositInterestTransaction
			FROM #TempLineItems
			ORDER BY [Date], SortDate	
	END			
END



GO
