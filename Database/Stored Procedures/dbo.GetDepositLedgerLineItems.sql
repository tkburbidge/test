SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/****** Object:  StoredProcedure [dbo].[GetDepositLedgerLineItems]    Script Date: 10/15/2012 13:50:35 ******/



-- =============================================
-- Author:		Nick Olsen
-- Create date: Oct. 15, 2012
-- Description:	Gets deposit transactions
-- =============================================
CREATE PROCEDURE [dbo].[GetDepositLedgerLineItems] 
	-- Add the parameters for the stored procedure here
	@AccountID bigint = null,
	@PropertyID uniqueidentifier = null,
	@ObjectID uniqueidentifier = null, 
	@ObjectGroup nvarchar(50) = null,
	@StartDate datetime2 = null,
	@EndDate datetime2 = null,
	@Origins StringCollection readonly,	
	@SortDesc bit = 0	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #TempLineItems (
		ID								uniqueidentifier		NOT NULL,
		[Date]							datetime				NOT NULL,
		UnitNumber						nvarchar(50)			NULL,
		[Type]							nvarchar(50)			NULL,
		LedgerItemTypeAbbreviation		nvarchar(50)			NULL,
		LedgerItemTypeID				uniqueidentifier		NULL,
		BatchNumber						int						NULL,
		[Description]					nvarchar(75)			NULL,
		Reference						nvarchar(50)			NULL,
		PaymentType						nvarchar(50)			NULL,
		Amount							money					NOT NULL,
		TaxAmount						money					NULL,
		Notes							nvarchar(200)			NULL,
		NotVisible						bit						NOT NULL,
		Reversed						bit						NOT NULL,
		IsRent							bit						NOT NULL,		
		ReversesTransactionID			uniqueidentifier		NULL,
		SortDate						datetime				NULL,
		OrderMe							int						NULL
		)

	DECLARE @filterOrigin bit
	SET @filterOrigin = (SELECT COUNT(Value) FROM @Origins)
		
	INSERT #TempLineItems 		
		SELECT (CASE WHEN t.Origin = 'T' AND tt.Name IN ('Deposit') AND pt.PaymentID IS NOT NULL THEN pt.PaymentID
					 ELSE t.TransactionID
				END) as 'ID',
				t.TransactionDate as 'Date', 
				u.Number as 'UnitNumber',
				tt.Name as 'Type', 
				lit.Abbreviation as 'LedgerItemTypeAbbreviation', 
				lit.LedgerItemTypeID as 'LedgerItemTypeID',
				null,
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
				lit.OrderBy as 'OrderMe' 
			FROM [Transaction] t
				INNER JOIN [TransactionType] tt on t.TransactionTypeID = tt.TransactionTypeID
				LEFT JOIN [UnitLeaseGroup] ulg on ulg.UnitLeaseGroupID = t.ObjectID
				LEFT JOIN [Unit] u on u.UnitID = ulg.UnitID
				LEFT JOIN [LedgerItemType] lit on lit.LedgerItemTypeID = t.LedgerItemTypeID
				LEFT JOIN [Transaction] tr on t.ReversesTransactionID = t.TransactionID
				LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID
				LEFT JOIN [PaymentTransaction] pt ON pt.TransactionID = t.TransactionID	
			WHERE ((tt.Name in ('Balance Transfer Deposit', 'Deposit Applied to Deposit'))
					-- If a Payment, Credit, or Deposit is transferred we need to include the single transactions
					-- that make up that transfer
					OR ((tt.Name IN ('Deposit') AND t.Origin = 'T')))
				AND t.AccountID = @AccountID 
				AND t.PropertyID = @PropertyID
				AND tt.[Group] = @ObjectGroup
				AND (t.TransactionDate >= @StartDate)
				AND (t.TransactionDate <= @EndDate)
				AND ((@filterOrigin = 0) OR (t.Origin IN (SELECT Value FROM @Origins)))
				AND ((@ObjectID IS NULL) OR (t.ObjectID = @ObjectID))
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
				200 as 'Orderme'
			FROM Payment p
				INNER JOIN [PaymentTransaction] pt on p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t on t.TransactionID = pt.TransactionID
				LEFT JOIN [LedgerItemType] lit on t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN [Batch] b on b.BatchID = p.BatchID
				--LEFT JOIN [Unit] u on u.UnitID = t.UnitID
				LEFT JOIN [UnitLeaseGroup] ulg on ulg.UnitLeaseGroupID = t.ObjectID
				LEFT JOIN [Unit] u on u.UnitID = ulg.UnitID					
				INNER JOIN [TransactionType] tt on tt.TransactionTypeID = t.TransactionTypeID
				LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = p.PostingBatchID
			WHERE tt.Name in ('Deposit', 'Deposit Refund')
				AND p.AccountID = @AccountID 
				AND t.PropertyID = @PropertyID
				AND tt.[Group] = @ObjectGroup				
				AND (p.[Date] >= @StartDate)
				AND (p.[Date] <= @EndDate)
				-- Don't include the payments or credits due to balance transfers and deposit applications
				AND NOT ((tt.Name = 'Payment' OR tt.Name = 'Credit') AND t.LedgerItemTypeID IS NULL)		
				AND ((@filterOrigin = 0) OR (t.Origin IN (SELECT Value FROM @Origins)))
				AND ((@ObjectID IS NULL) OR (t.ObjectID = @ObjectID))
				AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
				-- When we transfer a payment, credit, or deposit the new ObjectID 
				-- transactions are tied to the same Payment record but the ledger entries
				-- for the transfer will be take care of in the above Transaction query.
				-- Make sure we only include the original Payment for the original ObjectID
				AND p.ObjectID = t.ObjectID
				

	--UPDATE #TempLineItems SET TaxAmount = ISNULL((SELECT SUM(ta.Amount)
	--											FROM [Transaction] t
	--												INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
	--												INNER JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID
	--											WHERE tta.Name IN ('Tax Charge')
	--											  AND t.TransactionID = #TempLineItems.ID
	--											GROUP BY t.TransactionID), 0)
	--	WHERE [Type] = 'Charge'
												
	--UPDATE #TempLineItems SET TaxAmount = ISNULL((SELECT SUM(ta.Amount)
	--											FROM [Transaction] t
	--												INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
	--												INNER JOIN [PaymentTransaction] pt ON t.TransactionID = pt.TransactionID
	--												INNER JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID
	--											WHERE tta.Name IN ('Tax Credit')
	--											  AND pt.PaymentID = #TempLineItems.ID
	--											GROUP BY pt.TransactionID), 0)
	--	WHERE [Type] = 'Credit'
				
	IF (@SortDesc = 1)
	BEGIN
		SELECT ID, [Date], UnitNumber, [Type], BatchNumber, LedgerItemTypeAbbreviation, LedgerItemTypeID, [Description], Reference,
				PaymentType, Amount, TaxAmount, Notes, NotVisible, Reversed, IsRent, SortDate
			FROM #TempLineItems
			ORDER BY [Date] DESC, SortDate DESC
	END
	ELSE
	BEGIN			
		SELECT ID, [Date], UnitNumber, [Type], BatchNumber, LedgerItemTypeAbbreviation, LedgerItemTypeID, [Description], Reference,
				PaymentType, Amount, TaxAmount, Notes, NotVisible, Reversed, IsRent, SortDate
			FROM #TempLineItems
			ORDER BY [Date], SortDate	
	END			
END
GO
