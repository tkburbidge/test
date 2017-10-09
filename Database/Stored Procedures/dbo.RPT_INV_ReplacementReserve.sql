SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 17, 2015
-- Description:	Retrieves all the line items that 
-- were marked as ReplacementReserve and were paid
-- or partially paid on the given date range
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_ReplacementReserve]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@glAccountIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
	@accountingPeriodID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
   
	CREATE TABLE #PaidInvoices(
		PropertyID uniqueidentifier,
		PropertyAbbreviation nvarchar(200),
		InvoiceID uniqueidentifier,
		InvoiceNumber nvarchar(50),
		VendorID uniqueidentifier,
		Vendor nvarchar(500),
		[Description] nvarchar(500),
		IsCredit bit,
		InvoiceDate date,
		InvoiceAmount money,
		AmountPaid money null,
		AmountDue money null,
		CreditsApplied money null,
		LastReference nvarchar(50),
		LastReferenceDate date,
		LastBank nvarchar(200),
		InvoiceLineItemID uniqueidentifier,					-- ADD AND POPULATE FROM THIS POINT DOWN!!!!!!!!!
		TransactionID uniqueidentifier,
		GLAccountNumber nvarchar(50),
		GLAccountID uniqueidentifier,
		LocationID uniqueidentifier,
		Location nvarchar(100),
		[LIDescription] nvarchar(500),
		IsReplacementReserve bit)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #GLAccountIDs (
		GLAccountID uniqueidentifier
	)

	INSERT INTO #GLAccountIDs
		SELECT Value FROM @glAccountIDs

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	
	INSERT INTO #PaidInvoices
		SELECT DISTINCT	
				prop.PropertyID,	
				prop.Abbreviation,
				i.InvoiceID AS 'InvoiceID', 
				i.Number AS 'InvoiceNumber', 
				(CASE WHEN (i.SummaryVendorID IS NOT NULL) THEN sv.SummaryVendorID
					  ELSE v.VendorID
					  END) AS 'VendorID',
				(CASE WHEN i.SummaryVendorID IS NOT NULL THEN sv.Name
					  ELSE v.CompanyName
				 END) AS 'Vendor',
				i.[Description] AS 'Description',
				i.Credit,
				i.InvoiceDate AS 'InvoiceDate', 
				t.Amount,
				--(SELECT ISNULL(SUM(t1.Amount), 0)
				--	FROM InvoiceLineItem ili
				--		INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID					
				--	WHERE t1.PropertyID = prop.PropertyID 
				--		AND ili.InvoiceID = i.InvoiceID) AS 'InvoiceAmount',
				--i.Total AS 'InvoiceAmount',
				null,
				null,
				null,
				null,
				null,
				null,
				ili.InvoiceLineItemID,
				ili.TransactionID,
				gla.Number,
				gla.GLAccountID,
				ili.ObjectID,
				null,
				t2.[Description],
				ili.IsReplacementReserve
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
				INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
				INNER JOIN [Transaction] t2 ON t2.TransactionID = t.AppliesToTransactionID
				INNER JOIN Invoice i ON i.InvoiceID = t2.ObjectID
				INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID AND t2.TransactionID = ili.TransactionID --AND ili.IsReplacementReserve = 1
				INNER JOIN GLAccount gla ON ili.GLAccountID = gla.GLAccountID
				INNER JOIN Vendor v ON v.VendorID = i.VendorID
				LEFT JOIN SummaryVendor sv ON sv.SummaryVendorID = i.SummaryVendorID
				INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID
				INNER JOIN Property prop ON t2.PropertyID = prop.PropertyID				
				INNER JOIN #PropertiesAndDates #pad ON prop.PropertyID = #pad.PropertyID
			WHERE tt.Name = 'Payment'
			  AND tt.[Group] = 'Invoice'
			  AND p.PaidOut = 1			  
			  AND (p.[Date] >= #pad.StartDate AND p.[Date] <= #pad.EndDate)
			  AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
			  AND p.Reversed = 0
			  AND p.Amount > 0
		
	--INSERT INTO #PaidInvoices
	--	SELECT DISTINCT
	--			prop.PropertyID,
	--			prop.Abbreviation,
	--			i.InvoiceID AS 'InvoiceID', 
	--			i.Number AS 'InvoiceNumber', 
	--			(CASE WHEN (i.SummaryVendorID IS NOT NULL) THEN sv.SummaryVendorID
	--				  ELSE v.VendorID
	--				  END) AS 'VendorID',
	--			(CASE WHEN i.SummaryV5endorID IS NOT NULL THEN sv.Name
	--				  ELSE v.CompanyName
	--			 END) AS 'Vendor',
	--			i.[Description] AS 'Description',			
	--			i.Credit,
	--			i.InvoiceDate AS 'InvoiceDate', 
	--			(SELECT ISNULL(SUM(t1.Amount), 0)
	--				FROM InvoiceLineItem ili
	--					INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID					
	--				WHERE t1.PropertyID = prop.PropertyID 
	--					AND ili.InvoiceID = i.InvoiceID) AS 'InvoiceAmount',
	--			--i.Total AS 'InvoiceAmount',
	--			null,
	--			null,
	--			null,
	--			null,
	--			null,
	--			null,
	--			ili.InvoiceLineItemID,
	--			gla.Number,
	--			ili.ObjectID,
	--			null,
	--			t2.[Description]
	--		FROM [Transaction] t
	--			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
	--			INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
	--			INNER JOIN [Transaction] t2 ON t2.TransactionID = t.AppliesToTransactionID
	--			INNER JOIN Invoice i ON i.InvoiceID = t2.ObjectID	
	--			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID AND t2.TransactionID = ili.TransactionID AND ili.IsReplacementReserve = 1
	--			INNER JOIN GLAccount gla ON ili.GLAccountID = gla.GLAccountID
	--			INNER JOIN Property prop ON t2.PropertyID = prop.PropertyID
	--			INNER JOIN #PropertiesAndDates #pad ON prop.PropertyID = #pad.PropertyID
	--			INNER JOIN Vendor v ON v.VendorID = i.VendorID
	--			LEFT JOIN SummaryVendor sv ON sv.SummaryVendorID = i.SummaryVendorID	
	--			LEFT JOIN PropertyAccountingPeriod pap ON prop.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID				
	--		WHERE tt.Name = 'Credit'
	--		  AND tt.[Group] = 'Invoice'
	--		  AND t.AppliesToTransactionID IS NOT NULL					  
	--		  AND (t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate)
	--		  AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
	--		  AND i.InvoiceID NOT IN (SELECT InvoiceID FROM #PaidInvoices)

	UPDATE #PaidInvoices SET AmountPaid = (SELECT ISNULL(SUM(ISNULL(t.Amount, 0)), 0)
											   FROM [Transaction] t
												   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
												   LEFT JOIN [Transaction] rpt ON rpt.ReversesTransactionID = t.TransactionID
												   INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
											   WHERE t.AppliesToTransactionID = #PaidInvoices.TransactionID
											   --IN (SELECT ili.TransactionID
														--							   FROM InvoiceLineItem ili
														--									INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID
														--							   WHERE ili.InvoiceLineItemID = #PaidInvoices.InvoiceLineItemID 
														--								 AND t1.PropertyID = #PaidInvoices.PropertyID)
											     AND tt.Name = 'Payment'
											     AND tt.[Group] = 'Invoice'
											     AND (t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate)
											     AND (rpt.TransactionID IS NULL OR rpt.TransactionDate > #pad.EndDate))

	--UPDATE #PaidInvoices SET CreditsApplied = (SELECT ISNULL(SUM(ISNULL(t.Amount, 0)), 0)
	--											   FROM [Transaction] t
	--												   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
	--												   LEFT JOIN [Transaction] rpt ON rpt.ReversesTransactionID = t.TransactionID
	--												   INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
	--											   WHERE t.AppliesToTransactionID IN (SELECT ili.TransactionID
	--																					   FROM InvoiceLineItem ili																								
	--																					   WHERE ili.InvoiceLineItemID = #PaidInvoices.InvoiceLineItemID)																							 										   
	--											     AND tt.Name = 'Credit'
	--											     AND tt.[Group] = 'Invoice'
	--											     AND (t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate)
	--											     AND (rpt.TransactionID IS NULL OR rpt.TransactionDate > @endDate))

													 
	UPDATE #PaidInvoices SET Location = (SELECT CASE WHEN (u.UnitID IS NOT NULL) THEN u.Number
													 WHEN (b.BuildingID IS NOT NULL) THEN b.Name
													 WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
													 WHEN (ri.LedgerItemID IS NOT NULL) THEN ri.[Description]
													 END
											  FROM InvoiceLineItem ili
												  LEFT JOIN Unit u ON ili.ObjectID = u.UnitID
												  LEFT JOIN Building b ON ili.ObjectID = b.BuildingID
												  LEFT JOIN WOITAccount woit ON ili.ObjectID = woit.WOITAccountID
												  LEFT JOIN LedgerItem ri ON ili.ObjectID = ri.LedgerItemID
											  WHERE #PaidInvoices.InvoiceLineItemID = ili.InvoiceLineItemID)
											   
	UPDATE #PaidInvoices SET AmountDue = InvoiceAmount - AmountPaid --- CreditsApplied

	UPDATE paid SET LastReference = PaymentInfo.ReferenceNumber, LastReferenceDate = PaymentInfo.[Date]--, LastBank = PaymentInfo.AccountName
		FROM #PaidInvoices paid
		OUTER APPLY
		  (SELECT TOP 1 /*at.ObjectID AS 'InvoiceID',*/ paid.InvoiceLineItemID AS 'InvoiceLineItemID', p.ReferenceNumber, /*ba.AccountName,*/ p.[Date]
			   FROM [Transaction] t
				   INNER JOIN PaymentTransaction pt ON pt.TransactionID = t.TransactionID
				   INNER JOIN Payment p on pt.PaymentID = p.PaymentID
				   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				   --INNER JOIN BankAccount ba on ba.BankAccountID = t.ObjectID
				   LEFT JOIN [Transaction] rpt ON rpt.ReversesTransactionID = t.TransactionID
				   --INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID				   
				   INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
				   --INNER JOIN Invoice i ON at.ObjectID = i.InvoiceID
				   --INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID AND at.TransactionID = ili.TransactionID AND ili.IsReplacementReserve = 1
			   WHERE --t.AppliesToTransactionID IN (SELECT TransactionID
					--								   FROM [Transaction] t
					--								   WHERE t.ObjectID = paid.InvoiceID)
					t.AppliesToTransactionID = paid.TransactionID
			     AND tt.Name = 'Payment'
			     AND tt.[Group] = 'Invoice'			   
				 AND (t.[TransactionDate] >= #pad.StartDate AND t.[TransactionDate] <= #pad.EndDate)
			     AND rpt.TransactionID IS NULL
			     AND t.PropertyID = paid.PropertyID
			   ORDER BY p.[Date] DESC, p.[TimeStamp] DESC) AS PaymentInfo 
		   WHERE PaymentInfo.InvoiceLineItemID = paid.InvoiceLineItemID

		   UPDATE #PaidInvoices SET AmountPaid = -AmountPaid, InvoiceAmount = -InvoiceAmount WHERE IsCredit = 1

	IF ((SELECT COUNT(*) FROM @glAccountIDs) > 0)		-- filter by gl account ids
		SELECT * 
			FROM #PaidInvoices 
			INNER JOIN #GLAccountIDs ON #GLAccountIDs.GLAccountID = #PaidInvoices.GLAccountID			
	ELSE
		SELECT * 
			FROM #PaidInvoices
			WHERE IsReplacementReserve = 1
END
GO
