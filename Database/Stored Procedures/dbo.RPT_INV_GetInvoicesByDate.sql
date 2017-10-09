SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
	
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 7, 2014
-- Description:	Gets all invoices and associated line items for a collection of properties, in a given date range.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_GetInvoicesByDate] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@invoiceFilterDate nvarchar(50) = null,
	@useCurrentStatus bit = null,
	@unpaidOnly bit = 0,
	@accountingPeriodID uniqueidentifier = null,
	@batchID uniqueidentifier = null,
	@includeApproved bit = 1,
	@includePendingApproval bit = 1,
	@integrationPartnerID int = null,
	@includeLastPaymentData bit = 0
AS

DECLARE @invoiceStatusDate date = @endDate

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF (@useCurrentStatus = 1)
	BEGIN
		SET @invoiceStatusDate = null
	END

	CREATE TABLE #Invoices (
		InvoiceID uniqueidentifier not null,
		InvoiceNumber nvarchar(50) not null,
		VendorName nvarchar(200) not null,
		InvoiceDate date null,
		AccountingDate date null,
		DueDate date null,
		[Description] nvarchar(500) null,
		Total money null,
		AmountPaid money null,
		PONumbers nvarchar(500) null,
		IsCredit bit null,
		PostingPersonID uniqueidentifier null,
		PostingPerson nvarchar(200) null,
		LastReference nvarchar(50) null,
		LastReferenceDate date null,
		LastBank nvarchar(200) null,
		HoldDate date null,
		ApproverPersonID uniqueidentifier null,
		ApproverLastName nvarchar(50) null,
		InvoiceStatus nvarchar(20) null)
		
	CREATE TABLE #InvoiceLineItems (
		InvoiceID uniqueidentifier not null,
		InvoiceLineItemID uniqueidentifier not null,		
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		PropertyAbbreviation nvarchar(50) not null,
		GLAccountNumber nvarchar(50) not null,
		GLAccountName nvarchar(200) not null,
		[Description] nvarchar(500) null,
		Total money null,
		AmountPaid money null,
		AccountingDate date null,
		InvoiceNumber nvarchar(50) null,
		IsCredit bit null,
		InvoiceStatus nvarchar(20) null)
		
	
	CREATE TABLE #PropertyAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL,
		InvoiceStatusDate [Date] NULL)

	IF (@accountingPeriodID IS NOT NULL)
	BEGIN		
		INSERT #PropertyAndDates
			SELECT pids.Value, pap.StartDate, pap.EndDate, (CASE WHEN @useCurrentStatus = 1 THEN NULL ELSE pap.EndDate END)
				FROM @propertyIDs pids
					INNER JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	END
	ELSE
	BEGIN
		INSERT #PropertyAndDates
			SELECT pids.Value, @startDate, @endDate, (CASE WHEN @useCurrentStatus = 1 THEN NULL ELSE @endDate END)
				FROM @propertyIDs pids
	END

	INSERT #InvoiceLineItems 
		SELECT	
				i.InvoiceID,
				ili.InvoiceLineItemID,
				p.PropertyID,
				p.Name AS 'PropertyName',
				p.Abbreviation AS 'PropertyAbbreviation',
				gla.Number AS 'GLAccountNumber',
				gla.Name AS 'GLAccountName',
				t.[Description] AS 'Description',
				t.Amount AS 'Total',
				null,
				i.AccountingDate,
				i.Number AS 'InvoiceNumber',
				i.Credit AS 'IsCredit',
				INVSTAT.InvoiceStatus
		FROM Invoice i 
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			INNER JOIN GLAccount gla ON ili.GLAccountID = gla.GLAccountID
			INNER JOIN #PropertyAndDates #p ON #p.PropertyID = t.PropertyID			
			OUTER APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, #p.InvoiceStatusDate) AS INVSTAT
			LEFT JOIN InvoiceBatch ib on ib.BatchID = @batchID AND ib.InvoiceID = i.InvoiceID
		WHERE
		  ((@unpaidOnly = 0) OR (INVSTAT.InvoiceStatus IS NULL OR INVSTAT.InvoiceStatus NOT IN ('Void', 'Paid', 'Applied')))
		  -- All kinds of magic on which date to use, which is dictated by @invoiceFilterDate
		  AND ((@batchID IS NOT NULL AND ib.BatchID IS NOT NULL) 
			    OR (((((@invoiceFilterDate IS NULL) OR (@invoiceFilterDate = 'AccountingDate')) AND (i.AccountingDate >= #p.StartDate) AND (i.AccountingDate <= #p.EndDate))
				    OR ((@invoiceFilterDate = 'InvoiceDate') AND (i.InvoiceDate >= #p.StartDate) AND (i.InvoiceDate <= #p.EndDate))
					OR ((@invoiceFilterDate = 'DueDate') AND (i.DueDate >= #p.StartDate) AND (i.DueDate <= #p.EndDate))
					OR ((@invoiceFilterDate = 'ReceivedDate') AND (i.ReceivedDate >= #p.StartDate) AND (i.ReceivedDate <= #p.EndDate)))
				 AND ((@unpaidOnly = 0) OR (((@includeApproved = 1) AND (INVSTAT.InvoiceStatus IN ('Approved', 'Approved-R', 'Partially Paid', 'Partially Paid-R', 'Partially Applied')))
						OR ((@includePendingApproval = 1) AND (INVSTAT.InvoiceStatus IN ('Pending Approval', 'Unapplied')))))))
		  AND (@integrationPartnerID IS NULL OR i.IntegrationPartnerID = @integrationPartnerID)
		
	INSERT #Invoices
		SELECT	
				i.InvoiceID,
				i.Number AS 'InvoiceNumber',
				v.CompanyName AS 'VendorName',
				i.InvoiceDate,
				i.AccountingDate,
				i.DueDate,
				i.[Description],
				SUM(#ili.Total) AS 'Total',
				null,
				STUFF((SELECT ', ' + Number
					FROM PurchaseOrder 
					WHERE InvoiceID = i.InvoiceID
					FOR XML PATH ('')), 1, 2, '') AS 'PONumbers',
				i.Credit AS 'IsCredit',
				null,
				null,
				null,
				null,
				null,
				i.HoldDate,
				null,
				null,
				#ili.InvoiceStatus
			FROM #InvoiceLineItems #ili
				INNER JOIN Invoice i ON #ili.InvoiceID = i.InvoiceID
				INNER JOIN Vendor v ON i.VendorID = v.VendorID
				INNER JOIN Person p on i.CreatedByPersonID = p.PersonID
			WHERE @integrationPartnerID IS NULL OR i.IntegrationPartnerID = @integrationPartnerID
			GROUP BY i.InvoiceID, i.Number, v.CompanyName, i.InvoiceDate, i.AccountingDate, i.DueDate, i.[Description], i.Credit, i.HoldDate, #ili.InvoiceStatus

	UPDATE #i SET PostingPerson = p.FirstName + ' ' + p.LastName, PostingPersonID = p.PersonID
									FROM #Invoices #i
									INNER JOIN Invoice i on #i.InvoiceID = i.InvoiceID
									INNER JOIN Person p on i.CreatedByPersonID = p.PersonID
			
	UPDATE #Invoices SET AmountPaid = ISNULL((SELECT ISNULL(SUM(ta.Amount), 0) 
											 FROM InvoiceLineItem ili
												INNER JOIN [Transaction] t ON t.TransactionID = ili.TransactionID
												INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
												LEFT JOIN [Transaction] tra ON tra.ReversesTransactionID = ta.TransactionID
												INNER JOIN #PropertyAndDates #p ON #p.PropertyID = t.PropertyID			
											 WHERE ili.InvoiceID = #Invoices.InvoiceID
												--AND t.PropertyID = #UnPaidInvoices.PropertyID
												AND (tra.TransactionID IS NULL OR tra.TransactionDate > #p.EndDate)
												AND ta.TransactionDate <= #p.EndDate
												AND ta.TransactionDate >= #p.StartDate), 0)
												
	UPDATE #InvoiceLineItems SET AmountPaid = ISNULL((SELECT ISNULL(SUM(ta.Amount), 0) 
														 FROM InvoiceLineItem ili
															INNER JOIN [Transaction] t ON t.TransactionID = ili.TransactionID
															INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
															LEFT JOIN [Transaction] tra ON tra.ReversesTransactionID = ta.TransactionID
															INNER JOIN #PropertyAndDates #p ON #p.PropertyID = t.PropertyID			
														 WHERE ili.InvoiceID = #InvoiceLineItems.InvoiceID
															AND ili.InvoiceLineItemID = #InvoiceLineItems.InvoiceLineItemID
															AND t.PropertyID = #InvoiceLineItems.PropertyID
															AND (tra.TransactionID IS NULL OR tra.TransactionDate > #p.EndDate)
															AND ta.TransactionDate <= #p.EndDate
															AND ta.TransactionDate >= #p.StartDate), 0)				
															

	UPDATE #Invoices SET ApproverPersonID = (SELECT TOP 1 wra.ApproverPersonID
												FROM WorkflowRuleApproval wra
													INNER JOIN InvoiceLineItem ili ON wra.ObjectID = ili.InvoiceLineItemID
													INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID
												WHERE i.InvoiceID = #Invoices.InvoiceID
												ORDER BY wra.DateApproved DESC)
		
	UPDATE #upi SET ApproverLastName = per.LastName
		FROM #Invoices #upi
			INNER JOIN Person per ON #upi.ApproverPersonID = per.PersonID
		WHERE #upi.ApproverPersonID IS NOT NULL															
																					

	IF(@includeLastPaymentData = 1)
	BEGIN
		UPDATE i set LastReference = PaymentInfo.ReferenceNumber, LastReferenceDate = PaymentInfo.[Date], LastBank = PaymentInfo.AccountName
		FROM #Invoices i
			OUTER APPLY
			  (SELECT TOP 1 at.ObjectID AS 'InvoiceID', p.ReferenceNumber, ba.AccountName, p.[Date]
			   FROM [Transaction] t
			   INNER JOIN PaymentTransaction pt ON pt.TransactionID = t.TransactionID
			   INNER JOIN Payment p on pt.PaymentID = p.PaymentID
			   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			   INNER JOIN BankAccount ba on ba.BankAccountID = t.ObjectID
			   LEFT JOIN [Transaction] rpt ON rpt.ReversesTransactionID = t.TransactionID
			   INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
			   LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			   WHERE t.AppliesToTransactionID IN (SELECT TransactionID
												   FROM [Transaction] t
												   WHERE t.ObjectID = i.InvoiceID)
			   AND tt.Name = 'Payment'
			   AND tt.[Group] = 'Invoice'
			   AND (((@accountingPeriodID IS NULL) AND (t.[TransactionDate] >= @startDate) AND (t.TransactionDate <= @endDate))
				 OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.[TransactionDate] <= pap.EndDate)))
			   AND rpt.TransactionID IS NULL
			   ORDER BY p.[Date] DESC, p.[TimeStamp] DESC) AS PaymentInfo 
			   WHERE PaymentInfo.InvoiceID = i.InvoiceID

	END

	IF (@unpaidOnly = 1)
	BEGIN
		SELECT * FROM #Invoices
			WHERE Total - ISNULL(AmountPaid, 0) <> 0
			ORDER BY VendorName, InvoiceNumber, AccountingDate

		SELECT	#ili.InvoiceID,
				PropertyID,
				PropertyName,
				PropertyAbbreviation,
				GLAccountNumber,
				GLAccountName,
				#ili.[Description],
				#ili.Total,
				#ili.AmountPaid,
				#ili.IsCredit
			FROM #InvoiceLineItems	#ili
				INNER JOIN #Invoices #i ON #ili.InvoiceID = #i.InvoiceID
			WHERE #ili.Total - ISNULL(#ili.AmountPaid, 0) <> 0
			--GROUP BY #ili.InvoiceID, PropertyAbbreviation, GLAccountNumber, GLAccountName, #ili.[Description], #ili.Total, #i.Total, #ili.AccountingDate,
			--		 #ili.InvoiceNumber
			--HAVING #i.Total - ISNULL(SUM(#ili.AmountPaid), 0) <> 0
			ORDER BY #ili.PropertyAbbreviation,  #ili.InvoiceNumber, #ili.AccountingDate
	END
	ELSE
	BEGIN			
		SELECT * FROM #Invoices
			ORDER BY VendorName, InvoiceNumber, AccountingDate
		
		SELECT	InvoiceID,
				PropertyID,
				PropertyName,
				PropertyAbbreviation,
				GLAccountNumber,
				GLAccountName,
				[Description],
				Total,
				AmountPaid,
				IsCredit
			FROM #InvoiceLineItems	
			ORDER BY PropertyAbbreviation, InvoiceNumber, AccountingDate
	END			


END


GO
