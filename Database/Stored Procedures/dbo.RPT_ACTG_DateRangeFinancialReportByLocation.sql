SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





CREATE PROCEDURE [dbo].[RPT_ACTG_DateRangeFinancialReportByLocation]
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null,
	@objectIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@reportStartDate datetime = null,
	@reportEndDate datetime = null,
	@includePOs bit = 0,
	@glAccountIDs GuidCollection READONLY,
	@calculateMonthOnly bit = 0,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byProperty bit = 0,
	@parameterGLAccountTypes StringCollection READONLY,
	@includeDefaultAccountingBook bit = 1,
	@accountingBookIDs GuidCollection READONLY
AS

DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @accountID bigint
DECLARE @overrideHide bit = 0
DECLARE @glAccountTypes StringCollection
--DECLARE @accountingPeriodID uniqueidentifier

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #ObjectIDs (
		ObjectID uniqueidentifier NOT NULL)

	CREATE TABLE #AllInfo (	
		ObjectID uniqueidentifier NULL,	
		GLAccountID uniqueidentifier NOT NULL,
		Number nvarchar(15) NOT NULL,
		Name nvarchar(200) NOT NULL, 
		[Description] nvarchar(500) NULL,
		GLAccountType nvarchar(50) NOT NULL,
		ParentGLAccountID uniqueidentifier NULL,
		Depth int NOT NULL,
		IsLeaf bit NOT NULL,
		SummaryParent bit NOT NULL,
		[OrderByPath] nvarchar(max) NOT NULL,
		[Path]  nvarchar(max) NOT NULL,
		SummaryParentPath nvarchar(max),
		CurrentAPAmount money null,
		YTDAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null,
		BudgetNotes nvarchar(MAX) null
		)	
		
	CREATE TABLE #AlternateInfo (	
		ObjectID uniqueidentifier NULL,	
		GLAccountID uniqueidentifier NOT NULL,
		Number nvarchar(15) NOT NULL,
		Name nvarchar(200) NOT NULL, 
		[Description] nvarchar(500) NULL,
		GLAccountType nvarchar(50) NOT NULL,
		ParentGLAccountID uniqueidentifier NULL,
		Depth int NOT NULL,
		IsLeaf bit NOT NULL,
		SummaryParent bit NOT NULL,
		[OrderByPath] nvarchar(max) NOT NULL,
		[Path]  nvarchar(max) NOT NULL,
		SummaryParentPath nvarchar(max) NOT NULL,
		CurrentAPAmount money null,
		YTDAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null,
		BudgetNotes nvarchar(MAX) null
		)			
		
	CREATE TABLE #AlternateInfoValues (	
		ObjectID uniqueidentifier NULL,	
		GLAccountID uniqueidentifier NOT NULL,
		Number nvarchar(15) NOT NULL,
		Name nvarchar(200) NOT NULL, 
		[Description] nvarchar(500) NULL,
		GLAccountType nvarchar(50) NOT NULL,
		ParentGLAccountID uniqueidentifier NULL,
		Depth int NOT NULL,
		IsLeaf bit NOT NULL,
		SummaryParent bit NOT NULL,
		[OrderByPath] nvarchar(max) NOT NULL,
		[Path]  nvarchar(max) NOT NULL,
		SummaryParentPath nvarchar(max) NOT NULL,
		CurrentAPAmount money null,
		YTDAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null,
		BudgetNotes nvarchar(MAX) null
		)									
	
	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier NOT NULL)
		
	INSERT #AccountingBooks
		SELECT Value FROM @accountingBookIDs
	
	IF (@byProperty IS NULL)
	BEGIN
		SET @byProperty = 0
	END
	
	INSERT #ObjectIDs SELECT Value FROM @objectIDs
	
	SET @accountID = (SELECT AccountID FROM Property WHERE PropertyID = @propertyID)
	
	--SET @accountingPeriodID = (SELECT AccountingPeriodID FROM AccountingPeriod WHERE EndDate >= @reportEndDate AND StartDate <= @reportEndDate AND AccountID = @accountID)
	

	INSERT @glAccountTypes VALUES ('Income')
	INSERT @glAccountTypes VALUES ('Expense')
	INSERT @glAccountTypes VALUES ('Other Income')				
	INSERT @glAccountTypes VALUES ('Other Expense')
	INSERT @glAccountTypes VALUES ('Non-Operating Expense')				
		
	IF (@alternateChartOfAccountsID IS NULL)
	BEGIN	
		INSERT #AllInfo SELECT 
							--prop.PropertyID,
							#objs.ObjectID,
							GLAccountID,
							Number,
							chartOfAccts.Name,
							chartOfAccts.[Description],
							GLAccountType,
							ParentGLAccountID,
							Depth,
							IsLeaf,
							SummaryParent,
							OrderByPath,
							[Path],
							SummaryParentPath,
							0,
							0,
							0,
							0,
							null
						FROM GetChartOfAccounts(@accountID, @glAccountTypes) chartOfAccts	
							INNER JOIN Property prop ON prop.PropertyID = @propertyID
							INNER JOIN #ObjectIDs #objs ON 1=1
	END
	ELSE
	BEGIN
		INSERT #AllInfo SELECT 
							--prop.PropertyID,
							#objs.ObjectID,
							GLAccountID,
							Number,
							altChartOfAccts.Name,
							altChartOfAccts.[Description],
							GLAccountType,
							ParentGLAccountID,
							Depth,
							IsLeaf,
							SummaryParent,
							OrderByPath,
							[Path],
							SummaryParentPath,
							0,
							0,
							0,
							0,
							null
						FROM GetChartOfAccountsByAlternate(@accountID, @glAccountTypes, @alternateChartOfAccountsID) altChartOfAccts	
							INNER JOIN Property prop ON prop.PropertyID = @propertyID
							INNER JOIN #ObjectIDs #objs ON 1=1
	END

	-- If we provided a list of types to filter this report by, then 
	-- delete out any that shouldn't be in there
	IF ((SELECT COUNT(*) FROM @parameterGLAccountTypes) > 0) 
	BEGIN
		DELETE FROM #AllInfo
		WHERE GLAccountType NOT IN (SELECT Value FROM @parameterGLAccountTypes)
	END
		  
	IF (@accountingBasis = 'Accrual')
	BEGIN		  
		IF (@includeDefaultAccountingBook = 1)
		BEGIN
		
			-- Leases
			UPDATE #AllInfo SET CurrentAPAmount = (SELECT ISNULL(SUM(je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID AND t.PropertyID = @propertyID		
															INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
															INNER JOIN Unit u ON ulg.UnitID = u.UnitID																									
														WHERE t.TransactionDate >= @reportStartDate
														  AND t.TransactionDate <= @reportEndDate
														   -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND u.UnitID = #AllInfo.ObjectID
														  AND je.AccountingBasis = 'Accrual'														 
														  AND je.AccountingBookID IS NULL
														  )
			OPTION (RECOMPILE)	
			
			-- Invoices
			UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
													(SELECT ISNULL(SUM(je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID AND t.PropertyID = @propertyID	
															LEFT JOIN [Transaction] rt ON t.ReversesTransactionID = rt.TransactionID																
															INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID  OR rt.TransactionID = ili.TransactionID															
														WHERE t.TransactionDate >= @reportStartDate
														  AND t.TransactionDate <= @reportEndDate
														   -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND #AllInfo.ObjectID = ili.ObjectID
														  AND je.AccountingBasis = 'Accrual'														 
														  AND je.AccountingBookID IS NULL
														  )
			OPTION (RECOMPILE)			
			
			-- Vendor Payments
			UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
													(SELECT ISNULL(SUM(je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN VendorPaymentJournalEntry vpje ON je.JournalEntryID = vpje.JournalEntryID
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID																																							
														WHERE t.TransactionDate >= @reportStartDate 
														  AND t.TransactionDate <= @reportEndDate														   
														   -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND #AllInfo.ObjectID = vpje.ObjectID--IN (u.UnitID, woit.WOITAccountID, b.BuildingID, li.LedgerItemID)
														  AND je.AccountingBasis = 'Accrual'														  
														  AND je.AccountingBookID IS NULL
														  )
			OPTION (RECOMPILE)		
			
			-- Voided Vendor Payments
			-- We don't store a VendorPaymentJournalEntry record for the reversal so we can't
			-- join on VendorPaymentJournalEntry.ObjectID.  Also, since Vendor Payments are stored
			-- as a single Transaction and multiple Journal Entry records, we can't actually
			-- sum on the reversing JournalEntry amount since we don't know which JournalEntry
			-- reverses with Journal Entry.  But, since reversed VendorPayments are never partially 
			-- reversed, we can just sum on the negative amount of the original JounralEntry
			UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
													(SELECT ISNULL(SUM(-je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN VendorPaymentJournalEntry vpje ON je.JournalEntryID = vpje.JournalEntryID
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID		
															INNER JOIN [Transaction] rt ON rt.ReversesTransactionID = t.TransactionID																																					
														WHERE rt.TransactionDate >= @reportStartDate 
														  AND rt.TransactionDate <= @reportEndDate														   
														   -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND #AllInfo.ObjectID = vpje.ObjectID--IN (u.UnitID, woit.WOITAccountID, b.BuildingID, li.LedgerItemID)
														  AND je.AccountingBasis = 'Accrual'														  
														  AND je.AccountingBookID IS NULL
														  )
			OPTION (RECOMPILE)		

		END
		
		/*

		Can't post anything but JEs on other accounting books and JEs can't be tied to objects so don't need the following yet

		-- Other AccountingBooks Math!
		-- Leases
		UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
												(SELECT ISNULL(SUM(je.Amount), 0)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID AND t.PropertyID = @propertyID		
														INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
														INNER JOIN Unit u ON ulg.UnitID = u.UnitID										
														--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
														INNER JOIN #AccountingBooks #AB ON je.AccountingBookID = #AB.AccountingBookID
													WHERE t.TransactionDate >= @reportStartDate
													  AND t.TransactionDate <= @reportEndDate
													   -- Don't include closing the year entries
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND u.UnitID = #AllInfo.ObjectID
													  AND je.AccountingBasis = @accountingBasis AND @accountingBasis = 'Accrual'
													  --AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
													  )
		OPTION (RECOMPILE)	
		
		-- Invoices
		UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
												(SELECT ISNULL(SUM(je.Amount), 0)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID AND t.PropertyID = @propertyID		
														INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID 
														LEFT JOIN Unit u ON ili.ObjectID = u.UnitID
														LEFT JOIN WOITAccount woit ON ili.ObjectID = woit.WOITAccountID
														LEFT JOIN Building b ON ili.ObjectID = b.BuildingID
														LEFT JOIN LedgerItem li ON ili.ObjectID = li.LedgerItemID
														INNER JOIN #AccountingBooks #AB ON je.AccountingBookID = #AB.AccountingBookID
													WHERE t.TransactionDate >= @reportStartDate
													  AND t.TransactionDate <= @reportEndDate
													   -- Don't include closing the year entries
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND #AllInfo.ObjectID IN (u.UnitID, woit.WOITAccountID, b.BuildingID, li.LedgerItemID)
													  AND je.AccountingBasis = @accountingBasis AND @accountingBasis = 'Accrual'
													  --AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
													  )
		OPTION (RECOMPILE)			
		
		-- Vendor Payments
		UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
												(SELECT ISNULL(SUM(je.Amount), 0)
													FROM JournalEntry je
														INNER JOIN VendorPaymentJournalEntry vpje ON je.JournalEntryID = vpje.JournalEntryID
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														LEFT JOIN Unit u ON vpje.ObjectID = u.UnitID
														LEFT JOIN WOITAccount woit ON vpje.ObjectID = woit.WOITAccountID
														LEFT JOIN Building b ON vpje.ObjectID = b.BuildingID
														LEFT JOIN LedgerItem li ON vpje.ObjectID = li.LedgerItemID	
														INNER JOIN #AccountingBooks #AB ON je.AccountingBookID = #AB.AccountingBookID														
													WHERE t.TransactionDate >= @reportStartDate
													  AND t.TransactionDate <= @reportEndDate
													   -- Don't include closing the year entries
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND #AllInfo.ObjectID IN (u.UnitID, woit.WOITAccountID, b.BuildingID, li.LedgerItemID)
													  AND je.AccountingBasis = @accountingBasis AND @accountingBasis = 'Accrual'
													  --AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
													  )
		OPTION (RECOMPILE)		
	*/
	END										  

	IF (@accountingBasis = 'Cash')
	BEGIN		  

		IF (@includeDefaultAccountingBook = 1)
		BEGIN
		
			-- Leases
			UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
													(SELECT ISNULL(SUM(je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID AND t.PropertyID = @propertyID																
															INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
															INNER JOIN Unit u ON ulg.UnitID = u.UnitID																									
														WHERE t.TransactionDate >= @reportStartDate
														  AND t.TransactionDate <= @reportEndDate													
														   -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND u.UnitID = #AllInfo.ObjectID
														  AND je.AccountingBasis = 'Cash'														  
														  AND je.AccountingBookID IS NULL
														  )
			OPTION (RECOMPILE)	
			
			-- Invoices
			UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
													(SELECT ISNULL(SUM(je.Amount), 0)
														FROM JournalEntry je															
															-- Join in Payment Application or Reversal of Payment Application
															INNER JOIN [Transaction] taORtar ON je.TransactionID = taORtar.TransactionID AND taORtar.PropertyID = @propertyID 
															-- If taORtar is the reversal of an application, get the transaction that was used to pay off the charge
															LEFT JOIN [Transaction] ta ON taORtar.ReversesTransactionID = ta.TransactionID		
															-- Join in the invoice charge
															INNER JOIN [Transaction] t ON taORtar.AppliesToTransactionID = t.TransactionID OR ta.AppliesToTransactionID = t.TransactionID  -- Transaction applied to
															INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID 														
														WHERE taORtar.TransactionDate >= @reportStartDate
														  AND taORtar.TransactionDate <= @reportEndDate
														   -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND #AllInfo.ObjectID = ili.ObjectID
														  AND je.AccountingBasis = 'Cash'														 
														  AND je.AccountingBookID IS NULL
														  )
			OPTION (RECOMPILE)			
			
			-- Vendor Payments
			UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
													(SELECT ISNULL(SUM(je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN VendorPaymentJournalEntry vpje ON je.JournalEntryID = vpje.JournalEntryID
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID																												
														WHERE t.TransactionDate >= @reportStartDate
														  AND t.TransactionDate <= @reportEndDate
														   -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND #AllInfo.ObjectID = vpje.ObjectID --IN (u.UnitID, woit.WOITAccountID, b.BuildingID, li.LedgerItemID)
														  AND je.AccountingBasis = 'Cash'														  
														  AND je.AccountingBookID IS NULL
														  )
			OPTION (RECOMPILE)		

						-- Voided Vendor Payments
			-- We don't store a VendorPaymentJournalEntry record for the reversal so we can't
			-- join on VendorPaymentJournalEntry.ObjectID.  Also, since Vendor Payments are stored
			-- as a single Transaction and multiple Journal Entry records, we can't actually
			-- sum on the reversing JournalEntry amount since we don't know which JournalEntry
			-- reverses with Journal Entry.  But, since reversed VendorPayments are never partially 
			-- reversed, we can just sum on the negative amount of the original JounralEntry
			UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
													(SELECT ISNULL(SUM(-je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN VendorPaymentJournalEntry vpje ON je.JournalEntryID = vpje.JournalEntryID
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID		
															INNER JOIN [Transaction] rt ON rt.ReversesTransactionID = t.TransactionID																																					
														WHERE rt.TransactionDate >= @reportStartDate 
														  AND rt.TransactionDate <= @reportEndDate														   
														   -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND #AllInfo.ObjectID = vpje.ObjectID--IN (u.UnitID, woit.WOITAccountID, b.BuildingID, li.LedgerItemID)
														  AND je.AccountingBasis = 'Cash'														  
														  AND je.AccountingBookID IS NULL
														  )
			OPTION (RECOMPILE)	
			
		END
		
		---- Other AccountingBooks Math!
		---- Leases
		--UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
		--										(SELECT ISNULL(SUM(je.Amount), 0)
		--											FROM JournalEntry je
		--												INNER JOIN [Transaction] taORtr ON je.TransactionID = taORtr.TransactionID AND taORtr.PropertyID = @propertyID	
		--												INNER JOIN [Transaction] t ON taORtr.AppliesToTransactionID = t.TransactionID OR taORtr.ReversesTransactionID = t.TransactionID
		--												INNER JOIN UnitLeaseGroup ulg ON taORtr.ObjectID = ulg.UnitLeaseGroupID
		--												INNER JOIN Unit u ON ulg.UnitID = u.UnitID										
		--												--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
		--												INNER JOIN #AccountingBooks #AB ON je.AccountingBookID = #AB.AccountingBookID
		--											WHERE taORtr.TransactionDate >= @reportStartDate
		--											  AND taORtr.TransactionDate <= @reportEndDate
		--											   -- Don't include closing the year entries
		--											  AND t.Origin NOT IN ('Y', 'E')
		--											  AND je.GLAccountID = #AllInfo.GLAccountID
		--											  AND u.UnitID = #AllInfo.ObjectID
		--											  AND je.AccountingBasis = @accountingBasis AND @accountingBasis = 'Cash'
		--											  --AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
		--											  )
		--OPTION (RECOMPILE)	
		
		---- Invoices
		--UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
		--										(SELECT ISNULL(SUM(je.Amount), 0)
		--											FROM JournalEntry je
		--												INNER JOIN [Transaction] taORtr ON je.TransactionID = taORtr.TransactionID AND taORtr.PropertyID = @propertyID	
		--												INNER JOIN [Transaction] t ON taORtr.AppliesToTransactionID = t.TransactionID OR taORtr.ReversesTransactionID = t.TransactionID
		--												INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID 
		--												LEFT JOIN Unit u ON ili.ObjectID = u.UnitID
		--												LEFT JOIN WOITAccount woit ON ili.ObjectID = woit.WOITAccountID
		--												LEFT JOIN Building b ON ili.ObjectID = b.BuildingID
		--												LEFT JOIN LedgerItem li ON ili.ObjectID = li.LedgerItemID
		--												INNER JOIN #AccountingBooks #AB ON je.AccountingBookID = #AB.AccountingBookID
		--											WHERE taORtr.TransactionDate >= @reportStartDate
		--											  AND taORtr.TransactionDate <= @reportEndDate
		--											   -- Don't include closing the year entries
		--											  AND t.Origin NOT IN ('Y', 'E')
		--											  AND je.GLAccountID = #AllInfo.GLAccountID
		--											  AND #AllInfo.ObjectID IN (u.UnitID, woit.WOITAccountID, b.BuildingID, li.LedgerItemID)
		--											  AND je.AccountingBasis = @accountingBasis AND @accountingBasis = 'Cash'
		--											  --AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
		--											  )
		--OPTION (RECOMPILE)			
		
		---- Vendor Payments
		--UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) +
		--										(SELECT ISNULL(SUM(je.Amount), 0)
		--											FROM JournalEntry je
		--												INNER JOIN VendorPaymentJournalEntry vpje ON je.JournalEntryID = vpje.JournalEntryID
		--												INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
		--												LEFT JOIN Unit u ON vpje.ObjectID = u.UnitID
		--												LEFT JOIN WOITAccount woit ON vpje.ObjectID = woit.WOITAccountID
		--												LEFT JOIN Building b ON vpje.ObjectID = b.BuildingID
		--												LEFT JOIN LedgerItem li ON vpje.ObjectID = li.LedgerItemID	
		--												INNER JOIN #AccountingBooks #AB ON je.AccountingBookID = #AB.AccountingBookID														
		--											WHERE t.TransactionDate >= @reportStartDate
		--											  AND t.TransactionDate <= @reportEndDate
		--											   -- Don't include closing the year entries
		--											  AND t.Origin NOT IN ('Y', 'E')
		--											  AND je.GLAccountID = #AllInfo.GLAccountID
		--											  AND #AllInfo.ObjectID IN (u.UnitID, woit.WOITAccountID, b.BuildingID, li.LedgerItemID)
		--											  AND je.AccountingBasis = @accountingBasis AND @accountingBasis = 'Cash'
		--											  --AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
		--											  )
		--OPTION (RECOMPILE)		
				
	END										  

	--IF (@includePOs = 1)
	--BEGIN
	--	UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) 
	--														+ (SELECT ISNULL(SUM(poli.GLTotal), 0)
	--																FROM PurchaseOrderLineItem poli																	
	--																	INNER JOIN PurchaseOrder po ON poli.PurchaseOrderID = po.PurchaseOrderID
	--																	CROSS APPLY GetInvoiceStatusByInvoiceID(poli.PurchaseOrderID, @reportEndDate) AS [Status]
	--																	--INNER JOIN #Properties p ON p.PropertyID = poli.PropertyID
	--																WHERE [Status].InvoiceStatus IN ('Approved', 'Approved-R')
	--																  AND poli.PropertyID = @propertyID
	--																  AND po.[Date] >= @reportStartDate
	--																  AND po.[Date] <= @reportEndDate																	  
	--																  AND poli.GLAccountID = #AllInfo.GLAccountID
	--																  AND poli.ObjectID = #AllInfo.ObjectID
	--																  --AND ((@byProperty = 0) OR ((@byProperty = 1) AND (poli.PropertyID = #AllInfo.PropertyID)))																	  
	--																  )
	--	OPTION (RECOMPILE)																	 

	--END	
	
	
	IF (@alternateChartOfAccountsID IS NOT NULL)
	BEGIN
		INSERT #AlternateInfo SELECT 
							#objs.ObjectID,
							GLAccountID,
							Number,
							Name, 
							[Description],
							[GLAccountType],
							ParentGLAccountID,
							Depth, 
							IsLeaf,
							SummaryParent,
							[OrderByPath],
							[Path],
							SummaryParentPath,
							0,
							0,
							0,
							0,
							null								
						 FROM GetAlternateChartOfAccounts(@accountID, @glAccountTypes, @alternateChartOfAccountsID)	
							INNER JOIN #ObjectIDs #objs ON 1=1
		
		INSERT #AlternateInfoValues				 
			SELECT	distinct #info.ObjectID,
					#ai.GLAccountID,
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					#ai.GLAccountType AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.[OrderByPath],
					#ai.[Path],
					#ai.[SummaryParentPath],
					ISNULL(SUM(ISNULL(#info.CurrentAPAmount, 0)), 0) AS 'CurrentAPAmount',
					ISNULL(SUM(ISNULL(#info.YTDAmount, 0)), 0) AS 'YTDAmount',
					ISNULL(SUM(ISNULL(#info.CurrentAPBudget, 0)), 0) AS 'CurrentAPBudget',
					ISNULL(SUM(ISNULL(#info.YTDBudget, 0)), 0) AS 'YTDBudget',
					null
				FROM #AlternateInfo #ai
					INNER JOIN GLAccountAlternateGLAccount altGL ON #ai.GLAccountID = altGL.AlternateGLAccountID 
					INNER JOIN #AllInfo #info ON altGL.GLAccountID = #info.GLAccountID AND (@byProperty = 0 OR #ai.ObjectID = #info.ObjectID)				
				GROUP BY #ai.GLAccountID, #ai.Number, #ai.Name, #ai.[Description], #ai.GLAccountType, #ai.ParentGLAccountID, #ai.Depth,
					#ai.IsLeaf, #ai.SummaryParent, #ai.[OrderByPath], #ai.[Path], #ai.[SummaryParentPath], #info.ObjectID								
			
			INSERT #AlternateInfoValues 
			SELECT	ObjectID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
					OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
					[Path] + '!#' + Number + ' ' + Name + ' - Other', 
					[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
					CurrentAPAmount, YTDAmount, CurrentAPBudget, YTDBudget, BudgetNotes
			FROM #AlternateInfoValues
			WHERE IsLeaf = 0
			  AND (CurrentAPAmount <> 0)					
					
											 		
	END
	ELSE
	BEGIN
		-- Update the non-leaf nodes that have values to display on the report
		INSERT #AllInfo 
		SELECT	ObjectID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
				OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
				[Path] + '!#' + Number + ' ' + Name + ' - Other', 
				[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
				CurrentAPAmount, YTDAmount, CurrentAPBudget, YTDBudget, BudgetNotes
		FROM #AllInfo
		WHERE IsLeaf = 0
		  AND (CurrentAPAmount <> 0)
	END

		
											  
	--IF (@overrideHide = 0 AND
	--	1 =	(SELECT HideZeroValuesInFinancialReports 
	--			FROM Settings s
	--				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID AND s.AccountID = ap.AccountID))
					
	IF (@overrideHide = 0 AND
		1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings 
				WHERE AccountID = @accountID))
				
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN
			SELECT  #ai.ObjectID AS 'ObjectID',
					p.Name AS 'PropertyName',
					#ai.GLAccountID, 
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					LTRIM(#ai.GLAccountType) AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.OrderByPath,
					#ai.[Path],
					#ai.SummaryParentPath,
					ISNULL(#ai.CurrentAPAmount, 0) AS 'CurrentAPAmount',
					ISNULL(#ai.YTDAmount, 0) AS 'YTDAmount',
					ISNULL(#ai.CurrentAPBudget, 0) AS 'CurrentAPBudget',
					ISNULL(#ai.YTDBudget, 0) AS 'YTDBudget',
					#ai.BudgetNotes
				FROM #AlternateInfoValues #ai
					INNER JOIN Property p ON p.PropertyID = @propertyID
					--LEFT JOIN Property p ON #ai.PropertyID = p.PropertyID
				WHERE CurrentAPAmount <> 0
				   OR YTDAmount <> 0
				   OR CurrentAPAmount <> 0
				   OR YTDBudget <> 0			  
				   OR GLAccountID IN ( '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
				   ORDER BY OrderByPath			
								
		END
		ELSE	
		BEGIN
			SELECT  #ai.ObjectID AS 'ObjectID',
					p.Name AS 'PropertyName',
					#ai.GLAccountID, 
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					LTRIM(#ai.GLAccountType) AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.OrderByPath,
					#ai.[Path],
					#ai.SummaryParentPath,
					ISNULL(#ai.CurrentAPAmount, 0) AS 'CurrentAPAmount',
					ISNULL(#ai.YTDAmount, 0) AS 'YTDAmount',
					ISNULL(#ai.CurrentAPBudget, 0) AS 'CurrentAPBudget',
					ISNULL(#ai.YTDBudget, 0) AS 'YTDBudget',
					#ai.BudgetNotes
				FROM #AllInfo #ai
					--LEFT JOIN Property p ON #ai.PropertyID = p.PropertyID
					INNER JOIN Property p ON p.PropertyID = @propertyID
				WHERE IsLeaf = 1
				  AND (CurrentAPAmount <> 0
				   OR YTDAmount <> 0
				   OR CurrentAPBudget <> 0
				   OR YTDBudget <> 0
				   OR GLAccountID IN ( '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'))
				ORDER BY OrderByPath
		END			
	END
	ELSE
	BEGIN	
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN			
			SELECT  #ai.ObjectID AS 'ObjectID',
					p.Name AS 'PropertyName',
					#ai.GLAccountID, 
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					LTRIM(#ai.GLAccountType) AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.OrderByPath,
					#ai.[Path],
					#ai.SummaryParentPath,
					ISNULL(#ai.CurrentAPAmount, 0) AS 'CurrentAPAmount',
					ISNULL(#ai.YTDAmount, 0) AS 'YTDAmount',
					ISNULL(#ai.CurrentAPBudget, 0) AS 'CurrentAPBudget',
					ISNULL(#ai.YTDBudget, 0) AS 'YTDBudget',
					#ai.BudgetNotes
				FROM #AlternateInfoValues #ai
					--LEFT JOIN Property p ON #ai.PropertyID = p.PropertyID
					INNER JOIN Property p ON p.PropertyID = @propertyID
				WHERE IsLeaf = 1		  
					ORDER BY OrderByPath			
								
		END
		ELSE	
		BEGIN
			SELECT  #ai.ObjectID AS 'ObjectID',
					p.Name AS 'PropertyName',
					#ai.GLAccountID, 
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					LTRIM(#ai.GLAccountType) AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.OrderByPath,
					#ai.[Path],
					#ai.SummaryParentPath,
					ISNULL(#ai.CurrentAPAmount, 0) AS 'CurrentAPAmount',
					ISNULL(#ai.YTDAmount, 0) AS 'YTDAmount',
					ISNULL(#ai.CurrentAPBudget, 0) AS 'CurrentAPBudget',
					ISNULL(#ai.YTDBudget, 0) AS 'YTDBudget',
					#ai.BudgetNotes
				FROM #AllInfo #ai
					--LEFT JOIN Property p ON #ai.PropertyID = p.PropertyID
					INNER JOIN Property p ON p.PropertyID = @propertyID
				WHERE IsLeaf = 1				 
				ORDER BY OrderByPath
		END			
	END
	
			
END











GO
