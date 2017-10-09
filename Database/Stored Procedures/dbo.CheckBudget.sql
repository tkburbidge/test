SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






-- =============================================
-- Author:		Nick Olsen
-- Create date: October 12, 2012
-- Description:	Returns budget and actual amounts to
--				check for budget purposes
-- =============================================
CREATE PROCEDURE [dbo].[CheckBudget]
	-- Add the parameters for the stored procedure here
	@accountID bigint,	
	@date date, 
	@propertyIDs GuidCollection READONLY,
	@glAccountIDs GuidCollection readonly,			
	-- Supplied if editing an invoice
	@invoiceID uniqueidentifier = null,
	-- Supplied it editing/adding an invoice tied to purchase orders
	@purchaseOrderIDs GuidCollection readonly,	
	@byProperty bit = 0,
	@accountingPeriod nvarchar(100) OUTPUT	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.

	DECLARE @includeApprovedPOs bit = (SELECT IncludeApprovedPOsInBudgetVariance FROM Settings WHERE AccountID = @accountID)
	DECLARE @includePendingPOs bit = (SELECT IncludePendingPOsInBudgetVariance FROM Settings WHERE AccountID = @accountID)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		AccountingPeriodID uniqueidentifier NOT NULL,
		APName nvarchar(100) NULL,
		StartDate date NULL,
		EndDate date NULL)
	
	SET NOCOUNT ON;
	
	-- Get accountingperiodid for the given @date
	--DECLARE @accountingPeriodID uniqueidentifier
	--DECLARE @accountingPeriodName nvarchar(100)
	
	--SELECT @accountingPeriodID = ap.AccountingPeriodID, @accountingPeriodName = ap.Name
	--FROM AccountingPeriod ap
	----INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID --AND pap.PropertyID = @propertyID
	--WHERE ap.StartDate <= @date AND ap.EndDate >= @date AND ap.AccountID = @accountID
	
	--SET @accountingPeriod = @accountingPeriodName + '|' + CONVERT(nvarchar(50), @accountingPeriodID)
	
	INSERT #PropertiesAndDates
		SELECT pap.PropertyID, ap.AccountingPeriodID, ap.Name + '|' + CONVERT(nvarchar(50), ap.AccountingPeriodID), pap.StartDate, pap.EndDate
			FROM PropertyAccountingPeriod pap 
				INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
			WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND pap.StartDate <= @date
			  AND pap.EndDate >= @date
	
	SET @accountingPeriod = (SELECT TOP 1 APName FROM #PropertiesAndDates)
	
	DECLARE @accountingBasis nvarchar(100) = (SELECT DefaultAccountingBasis FROM Settings WHERE AccountID = @accountID)

    --DECLARE @propertyIDs GuidCollection
    --INSERT INTO @propertyIDs VALUES (@propertyID)   
		
	CREATE TABLE #BudgetInfo (		
		PropertyID uniqueidentifier NULL,
		PropertyName nvarchar(1000) NULL,
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
		
	--INSERT INTO #BudgetInfo 
	--EXEC RPT_ACTG_GenerateKeyFinancialReports @propertyIDs, null, @accountingBasis, @accountingPeriodID, 0, @glAccountIDs, 0, null, @byProperty
	
	CREATE TABLE #MyAccountingPeriodIDs (
		Sequence int identity,
		AccountingPeriodID uniqueidentifier)
	
	INSERT #MyAccountingPeriodIDs
		SELECT DISTINCT AccountingPeriodID FROM #PropertiesAndDates
		
	DECLARE @myMaxAPIDs int = (SELECT COUNT(*) FROM #MyAccountingPeriodIDs)
	DECLARE @myCtr int = 1
	DECLARE @myCurrentAPID uniqueidentifier
	DECLARE @thesePropertyIDs GuidCollection
	DECLARE @empty StringCollection
	DECLARE @accountingBookIDs GuidCollection
	INSERT INTO @accountingBookIDs VALUES ('55555555-5555-5555-5555-555555555555')
	
	WHILE (@myCtr <= @myMaxAPIDs)
	BEGIN
		SET @myCurrentAPID = (SELECT AccountingPeriodID FROM #MyAccountingPeriodIDs WHERE Sequence = @myCtr)
		INSERT @thesePropertyIDs SELECT PropertyID FROM #PropertiesAndDates WHERE AccountingPeriodID = @myCurrentAPID
		INSERT INTO #BudgetInfo 
			EXEC RPT_ACTG_GenerateKeyFinancialReports @thesePropertyIDs, null, @accountingBasis, @myCurrentAPID, 0, @glAccountIDs, 0, null, @byProperty, @empty, @accountingBookIDs	
		SET @myCtr = @myCtr + 1	
	END
	
	-- If we have been given an InvoiceID then we are editing
	-- an existing invoice and we need to remove the amounts
	-- of the editing invoice from the returned above report
	IF @invoiceID IS NOT NULL
	BEGIN
		-- We only need to do this on an accrual basis as on a cash
		-- basis the invoice wouldn't be included in the above numbers
		IF @accountingBasis = 'Accrual'
		BEGIN
			-- If the invoice in the DB is in the same accounting period as the
			-- accounting period passed in, then subtract the amounts from the
			-- current month amount
			-- If the invoice in the DB is in the same or a previous accounting period
			-- as the accounting period passed in, then subtract the amounts from the
			-- YTD amount			
			IF (0 < (SELECT COUNT(*) FROM Invoice i
										 --INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
										 --INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
										 --INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
									 WHERE i.InvoiceID = @invoiceID 
										--AND t.PropertyID = @propertyID 
										--AND AccountingDate >= ap.StartDate 
										--AND AccountingDate <= ap.EndDate))
										AND AccountingDate >= (SELECT MIN(StartDate) FROM #PropertiesAndDates)
										AND AccountingDate <= (SELECT MAX(EndDate) FROM #PropertiesAndDates)))
			BEGIN
				
				
				

				UPDATE #BudgetInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) - ISNULL((SELECT SUM(ISNULL(t.Amount, 0))
																					   FROM #BudgetInfo #BI
																							INNER JOIN InvoiceLineItem ili ON #BI.GLAccountID = ili.GLAccountID 
																							INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID 
																							INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID AND i.InvoiceID = @invoiceID
																							INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
																					   WHERE #BI.GLAccountID = #BudgetInfo.GLAccountID
																					    AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (#BI.PropertyID = #BudgetInfo.PropertyID) AND (t.PropertyID = #BudgetInfo.PropertyID)))
																					    AND i.AccountingDate >= #pad.StartDate
																					    AND i.AccountingDate <= #pad.EndDate																						
																					   GROUP BY #BI.GLAccountID),0 )
				OPTION (RECOMPILE)
									
				UPDATE #BudgetInfo SET YTDAmount = ISNULL(YTDAmount, 0) - ISNULL((SELECT SUM(ISNULL(t.Amount, 0))
																		   FROM #BudgetInfo #BI
																				INNER JOIN InvoiceLineItem ili ON #BI.GLAccountID = ili.GLAccountID 
																				INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID 
																				INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID AND i.InvoiceID = @invoiceID
																		   WHERE #BI.GLAccountID = #BudgetInfo.GLAccountID
																		   AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (#BI.PropertyID = #BudgetInfo.PropertyID) AND (t.PropertyID = #BudgetInfo.PropertyID)))
																		   GROUP BY #BI.GLAccountID), 0)
				OPTION (RECOMPILE)
						

			END
			ELSE IF (0 < (SELECT COUNT(*) FROM Invoice i
												--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
												INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
												INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
												INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
											WHERE i.InvoiceID = @invoiceID 
												--AND t.PropertyID = @propertyID 
												--AND AccountingDate <= ap.EndDate))
												AND AccountingDate <= #pad.EndDate))
			BEGIN
				UPDATE #BudgetInfo SET YTDAmount = ISNULL(YTDAmount, 0) - (SELECT SUM(ISNULL(t.Amount, 0))
																		   FROM #BudgetInfo #BI
																				INNER JOIN InvoiceLineItem ili ON #BI.GLAccountID = ili.GLAccountID 
																				INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID 
																				INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID AND i.InvoiceID = @invoiceID
																		   WHERE #BI.GLAccountID = #BudgetInfo.GLAccountID
																		   AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (#BI.PropertyID = #BudgetInfo.PropertyID) AND (t.PropertyID = #BudgetInfo.PropertyID)))
																		   GROUP BY #BI.GLAccountID)
				OPTION (RECOMPILE)
			
			END
		END
	END	
		
	
	IF (((SELECT COUNT(*) FROM @purchaseOrderIDs) > 0) AND ((@includeApprovedPOs = 1) OR (@includePendingPOs = 1)))
	BEGIN
		
		CREATE TABLE #Statuses (
			[Status] nvarchar(100)
		)

		IF (@includeApprovedPOs = 1)
		BEGIN
			INSERT INTO #Statuses VALUES ('Approved')
			INSERT INTO #Statuses VALUES ('Approved-R')
		END

		IF (@includePendingPOs = 1)
		BEGIN
			INSERT INTO #Statuses VALUES ('Pending Approval')			
		END
		
		-- If the purchase order in the DB is in the same accounting period as the
		-- accounting period passed in, then subtract the amounts from the
		-- current month amount
		 
		-- If the purchase order in the DB is in the same or a previous accounting period
		-- as the accounting period passed in, then subtract the amounts from the
		-- YTD amount
		
			IF (0 < (SELECT COUNT(*) FROM PurchaseOrder po
					 --INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
					 CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, null) AS [POStatus]
					 WHERE PurchaseOrderID IN (SELECT Value FROM @purchaseOrderIDs) 
							--AND po.PropertyID = @propertyID 
							--AND [Date] >= ap.StartDate 
							--AND [Date] <= ap.EndDate
							AND [Date] >= (SELECT MIN(StartDate) FROM #PropertiesAndDates)
							AND [Date] <= (SELECT MAX(EndDate) FROM #PropertiesAndDates)
							AND POStatus.InvoiceStatus IN (SELECT [Status] FROM #Statuses)))
			BEGIN
			
				--select * from PurchaseOrderLineItem where PurchaseOrderID in (SELECT Value FROM @purchaseOrderIDs)
				UPDATE #BudgetInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) - ISNULL((SELECT SUM(ISNULL(poli.GLTotal , 0))
																						FROM #BudgetInfo #BI
																							INNER JOIN PurchaseOrderLineItem poli ON #BI.GLAccountID = poli.GLAccountID 
																							INNER JOIN PurchaseOrder po ON poli.PurchaseOrderID = po.PurchaseOrderID
																							CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, null) AS [POStatus]
																							INNER JOIN #PropertiesAndDates #pad ON poli.PropertyID = #pad.PropertyID
																						WHERE po.PurchaseOrderID IN (SELECT Value FROM @purchaseOrderIDs)
																						  AND POStatus.InvoiceStatus IN (SELECT [Status] FROM #Statuses)					  
																						  AND #BudgetInfo.GLAccountID = #BI.GLAccountID
																						  AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (poli.PropertyID = #BudgetInfo.PropertyID)))
																						  AND po.[Date] >= #pad.StartDate
																						  AND po.[Date] <= #pad.EndDate
																						GROUP BY poli.GLAccountID), 0)														  
				OPTION (RECOMPILE)
					  
				UPDATE #BudgetInfo SET YTDAmount = ISNULL(YTDAmount, 0) - ISNULL((SELECT SUM(ISNULL(poli.GLTotal , 0))
																			FROM #BudgetInfo #BI
																				INNER JOIN PurchaseOrderLineItem poli ON #BI.GLAccountID = poli.GLAccountID 
																				INNER JOIN PurchaseOrder po ON poli.PurchaseOrderID = po.PurchaseOrderID
																				CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, null) AS [POStatus]
																			WHERE po.PurchaseOrderID IN (SELECT Value FROM @purchaseOrderIDs)
																			  AND POStatus.InvoiceStatus IN (SELECT [Status] FROM #Statuses)					  
																			  AND #BudgetInfo.GLAccountID = #BI.GLAccountID
																			  AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (poli.PropertyID = #BudgetInfo.PropertyID)))
																			GROUP BY poli.GLAccountID), 0)
				OPTION (RECOMPILE)
			END
			ELSE IF (0 < (SELECT COUNT(*) FROM PurchaseOrder po
						  --INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
						  CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, null) AS [POStatus]
						  INNER JOIN PurchaseOrderLineItem poli ON po.PurchaseOrderID = poli.PurchaseOrderID
						  INNER JOIN #PropertiesAndDates #pad ON poli.PropertyID = #pad.PropertyID
						  WHERE po.PurchaseOrderID IN (SELECT Value FROM @purchaseOrderIDs) 
							--AND po.PropertyID = @propertyID 
							--AND [Date] <= ap.EndDate
							AND po.[Date] <= #pad.EndDate
							AND POStatus.InvoiceStatus IN (SELECT [Status] FROM #Statuses)))
			BEGIN
				UPDATE #BudgetInfo SET YTDAmount = ISNULL(YTDAmount, 0) - ISNULL((SELECT SUM(ISNULL(poli.GLTotal , 0))
																			FROM #BudgetInfo #BI
																				INNER JOIN PurchaseOrderLineItem poli ON #BI.GLAccountID = poli.GLAccountID 
																				INNER JOIN PurchaseOrder po ON poli.PurchaseOrderID = po.PurchaseOrderID
																				CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, null) AS [POStatus]
																			WHERE po.PurchaseOrderID IN (SELECT Value FROM @purchaseOrderIDs)
																			  AND POStatus.InvoiceStatus IN (SELECT [Status] FROM #Statuses)					  
																			  AND #BudgetInfo.GLAccountID = #BI.GLAccountID
																			  AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (poli.PropertyID = #BudgetInfo.PropertyID)))
																			GROUP BY poli.GLAccountID), 0)
				OPTION (RECOMPILE)
			END
	END	

	SELECT PropertyID, GLAccountID, GLAccountType AS 'Type', Number AS 'GLAccountNumber', Name AS 'GLAccountName', CurrentAPAmount, CurrentAPBudget, YTDAmount, YTDBudget, BudgetNotes 
	FROM #BudgetInfo
END
GO
