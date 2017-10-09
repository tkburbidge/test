SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 27, 2012
-- Description:	Generates the data for the Unpaid Invoices Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_UnpaidInvoices] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportDate date = null,
	@invoiceFilterDate nvarchar(50) = null,
	@useCurrentStatus bit = null,
	@accountingPeriodID uniqueidentifier = null,
	@includeApproved bit = 1,
	@includePendingApproval bit = 1
AS

DECLARE @invoiceStatusDate date = @reportDate

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
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
			SELECT pids.Value, @reportDate, @reportDate, (CASE WHEN @useCurrentStatus = 1 THEN NULL ELSE @reportDate END)
				FROM @propertyIDs pids
	END

	IF (@useCurrentStatus = 1)
	BEGIN
		SET @invoiceStatusDate = null
	END
	
	CREATE TABLE #UnPaidInvoices (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		PropertyAbbreviation nvarchar(50) not null,
		VendorID uniqueidentifier not null,
		VendorName nvarchar(500) not null,
		InvoiceID uniqueidentifier not null,
		InvoiceNumber nvarchar(500) not null,
		InvoiceDate date null,
		AccountingDate date null,
		DueDate date null,
		[Description] nvarchar(500) null,
		Total money null,
		AmountPaid money null,
		Credit bit null,
		InvoiceStatus nvarchar(20) null,
		IsHighPriorityPayment bit null,
		ApproverPersonID uniqueidentifier null,
		ApproverLastName nvarchar(500) null,
		HoldDate date null)

	INSERT INTO #UnPaidInvoices
		SELECT  DISTINCT
				p.PropertyID AS 'PropertyID',
				p.Name AS 'PropertyName',
				p.Abbreviation AS 'PropertyAbbreviation',
				i.VendorID AS 'VendorID',
				v.CompanyName AS 'VendorName',
				i.InvoiceID AS 'InvoiceID',
				i.Number AS 'InvoiceNumber',
				i.InvoiceDate AS 'InvoiceDate',
				i.AccountingDate AS 'AccountingDate',
				i.DueDate AS 'DueDate',
				i.Description AS 'Description',
				0 AS 'Total',
				0 AS 'AmountPaid',
				--i.Total AS 'Total',
				--(SELECT ISNULL(SUM(t1.Amount), 0)
				--	FROM [Transaction] t1
				--	WHERE t1.TransactionID = t.TransactionID) AS 'Total',
				--(SELECT ISNULL(SUM(ta.Amount), 0) 
				--	FROM [Transaction] t
				--		INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
				--		LEFT JOIN [Transaction] tra ON tra.ReversesTransactionID = ta.TransactionID
				--	WHERE t.ObjectID = i.InvoiceID
				--	  AND tra.TransactionID IS NULL
				--	  AND ta.TransactionDate <= @reportDate) AS 'AmountPaid',
				i.Credit AS 'Credit',
				INVSTAT.InvoiceStatus,
				v.HighPriorityPayment,
				null,
				null,
				i.HoldDate			
			FROM Invoice i
				INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
				INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN Vendor v ON i.VendorID = v.VendorID
				INNER JOIN #PropertyAndDates #pad ON #pad.PropertyID = t.PropertyID
				OUTER APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, #pad.InvoiceStatusDate) AS INVSTAT
			WHERE  (INVSTAT.InvoiceStatus IS NULL OR INVSTAT.InvoiceStatus NOT IN ('Void', 'Paid', 'Applied'))
			  -- All kinds of magic on which date to use, which is dictated by @invoiceFilterDate
			  AND ((((@invoiceFilterDate IS NULL) OR (@invoiceFilterDate = 'AccountingDate')) AND (i.AccountingDate <= #pad.EndDate))
				OR ((@invoiceFilterDate = 'InvoiceDate') AND (i.InvoiceDate <= #pad.EndDate))
				OR ((@invoiceFilterDate = 'DueDate') AND (i.DueDate <= #pad.EndDate))
				OR ((@invoiceFilterDate = 'ReceivedDate') AND (i.ReceivedDate <= #pad.EndDate)))
			  AND (((@includeApproved = 1) AND (INVSTAT.InvoiceStatus IN ('Approved', 'Approved-R', 'Partially Paid', 'Partially Paid-R', 'Partially Applied')))
			    OR ((@includePendingApproval = 1) AND (INVSTAT.InvoiceStatus IN ('Pending Approval', 'Unapplied'))))

	UPDATE #UnPaidInvoices SET ApproverPersonID = (SELECT TOP 1 wra.ApproverPersonID
													   FROM WorkflowRuleApproval wra
														   INNER JOIN InvoiceLineItem ili ON wra.ObjectID = ili.InvoiceLineItemID
														   INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID
													   WHERE i.InvoiceID = #UnPaidInvoices.InvoiceID
													   ORDER BY wra.DateApproved DESC)
		WHERE [InvoiceStatus] IN ('Approved')

	UPDATE #upi SET ApproverLastName = per.LastName
		FROM #UnPaidInvoices #upi
			INNER JOIN Person per ON #upi.ApproverPersonID = per.PersonID
		WHERE #upi.ApproverPersonID IS NOT NULL
			  
	UPDATE #UnPaidInvoices SET Total = ISNULL((SELECT ISNULL(SUM(t.Amount), 0)
									    FROM InvoiceLineItem ili
											INNER JOIN [Transaction] t ON t.TransactionID = ili.TransactionID
										WHERE ili.InvoiceID = #UnPaidInvoices.InvoiceID
											AND t.PropertyID = #UnPaidInvoices.PropertyID), 0),
							   AmountPaid = ISNULL((SELECT ISNULL(SUM(ta.Amount), 0) 
											 FROM InvoiceLineItem ili
												INNER JOIN [Transaction] t ON t.TransactionID = ili.TransactionID
												INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
												INNER JOIN #PropertyAndDates #pad ON #pad.PropertyID = t.PropertyID
												LEFT JOIN [Transaction] tra ON tra.ReversesTransactionID = ta.TransactionID
											 WHERE ili.InvoiceID = #UnPaidInvoices.InvoiceID
												AND t.PropertyID = #UnPaidInvoices.PropertyID
												AND (tra.TransactionID IS NULL OR tra.TransactionDate > #pad.EndDate)
												AND ta.TransactionDate <= #pad.EndDate), 0)

		SELECT * FROM #UnPaidInvoices WHERE Total > AmountPaid ORDER BY VendorName, PropertyAbbreviation, InvoiceNumber
END



GO
