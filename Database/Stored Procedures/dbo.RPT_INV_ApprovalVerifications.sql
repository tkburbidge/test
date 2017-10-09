SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Jordan Betteridge
-- Create date: March 17, 2016
-- Description:	Generates the data for the Invoice Approval Verification Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_ApprovalVerifications] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate datetime,
	@endDate datetime,
	@accountingPeriodID uniqueidentifier = null,
	@sameEnteredPerson bit = 0,
	@sameApprovedPerson bit = 0,
	@samePaidPerson bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #InvoiceVerifications(
		VendorID uniqueidentifier,
		VendorName nvarchar(200),
		InvoiceID uniqueidentifier,
		InvoiceNumber nvarchar(50),
		InvoiceDate date,
		AccountingDate date,
		LastPaymentDate date,
		InvoiceAmount money,
		EnteredPersonID uniqueidentifier,		-- Based off first POInvoiceNote
		ApprovedPersonID uniqueidentifier,		-- Based off last POInvoiceNote of Approved
		PaidPersonID uniqueidentifier,			-- Base off last POInvoiceNote of Paid
		[User] nvarchar(100),
		EnteredTimestamp datetime,				-- Based off first POInvoiceNote
		ApprovedTimestamp datetime,				-- Based off last POInvoiceNote of Approved
		PaidTimestamp datetime,					-- Base off last POInvoiceNote of Paid
		PaymentMethod nvarchar(100))

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	

	INSERT INTO #InvoiceVerifications
		SELECT DISTINCT
				(CASE WHEN (i.SummaryVendorID IS NOT NULL) THEN sv.SummaryVendorID
					  ELSE v.VendorID
					  END) AS 'VendorID',
				(CASE WHEN i.SummaryVendorID IS NOT NULL THEN sv.Name
					  ELSE v.CompanyName
				 END) AS 'VendorName',
				i.InvoiceID, 
				i.Number AS 'InvoiceNumber', 
				i.InvoiceDate,
				i.AccountingDate,
				null,
				i.Total as 'InvoiceAmount',
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null
			FROM Invoice i
				INNER JOIN InvoiceLineItem ili ON ili.InvoiceID = i.InvoiceID
				INNER JOIN Vendor v ON v.VendorID = i.VendorID
				LEFT JOIN SummaryVendor sv ON sv.SummaryVendorID = i.SummaryVendorID
				INNER JOIN Property prop ON ili.PropertyID = prop.PropertyID				
				INNER JOIN #PropertiesAndDates #pad ON prop.PropertyID = #pad.PropertyID
			WHERE i.AccountID = @accountID
			  AND (i.AccountingDate >= #pad.StartDate AND i.AccountingDate <= #pad.EndDate)


	-- update payment information
	UPDATE #iv SET LastPaymentDate = PaymentInfo.[Date], PaymentMethod = PaymentInfo.[Type]
		FROM #InvoiceVerifications #iv
		OUTER APPLY
			(SELECT TOP 1 at.ObjectID AS 'InvoiceID', p.[Date], p.[Type]
			   FROM [Transaction] t
				   INNER JOIN PaymentTransaction pt ON pt.TransactionID = t.TransactionID
				   INNER JOIN Payment p on pt.PaymentID = p.PaymentID
				   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				   LEFT JOIN [Transaction] rpt ON rpt.ReversesTransactionID = t.TransactionID
				   INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
				   INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
			   WHERE t.AppliesToTransactionID IN (SELECT TransactionID
												   FROM [Transaction] t
												   WHERE t.ObjectID = #iv.InvoiceID)
				   AND tt.Name = 'Payment'
				   AND tt.[Group] = 'Invoice'
				   AND rpt.TransactionID IS NULL
			   ORDER BY p.[Date] DESC, p.[TimeStamp] DESC) AS PaymentInfo 
		WHERE PaymentInfo.InvoiceID = #iv.InvoiceID


	-- update entered timestamp information
	UPDATE #iv SET EnteredPersonID = NoteInfo.PersonID, EnteredTimestamp = NoteInfo.[Timestamp] 
		FROM #InvoiceVerifications #iv
		OUTER APPLY
			(SELECT TOP 1 poin.ObjectID, poin.PersonID, poin.[Timestamp]
				FROM POInvoiceNote poin
				WHERE poin.ObjectID = #iv.InvoiceID
				ORDER BY poin.[Timestamp] ASC) AS NoteInfo
		WHERE NoteInfo.ObjectID = #iv.InvoiceID
		  AND @sameEnteredPerson = 1


	-- update approved by information
	UPDATE #iv SET ApprovedPersonID = NoteInfo.PersonID, ApprovedTimestamp = NoteInfo.[Timestamp]
		FROM #InvoiceVerifications #iv
		OUTER APPLY
			(SELECT TOP 1 poin.ObjectID, poin.PersonID, poin.[Timestamp]
				FROM POInvoiceNote poin
				WHERE poin.ObjectID = #iv.InvoiceID
				  AND poin.[Status] = 'Approved'
				ORDER BY poin.[Timestamp] DESC) AS NoteInfo
		WHERE NoteInfo.ObjectID = #iv.InvoiceID
		  AND @sameApprovedPerson = 1


	-- update paid by information
	UPDATE #iv SET PaidPersonID = NoteInfo.PersonID, PaidTimestamp = NoteInfo.[Timestamp]
		FROM #InvoiceVerifications #iv
		OUTER APPLY
			(SELECT TOP 1 poin.ObjectID, poin.PersonID, poin.[Timestamp]
				FROM POInvoiceNote poin
				WHERE poin.ObjectID = #iv.InvoiceID
				  AND poin.[Status] = 'Paid'
				ORDER BY poin.[Timestamp] DESC) AS NoteInfo
		WHERE NoteInfo.ObjectID = #iv.InvoiceID
		  AND @samePaidPerson = 1

	
	-- update user name, only need to do this at least twice as only one of the parameters can be false
	UPDATE #iv SET [User] = per.FirstName + ' ' + per.LastName
		FROM #InvoiceVerifications #iv
			LEFT JOIN Person per ON per.PersonID = EnteredPersonID
		WHERE @sameEnteredPerson = 1

	UPDATE #iv SET [User] = per.FirstName + ' ' + per.LastName
		FROM #InvoiceVerifications #iv
			LEFT JOIN Person per ON per.PersonID = ApprovedPersonID
		WHERE @sameApprovedPerson = 1



	SELECT *
		FROM #InvoiceVerifications
		WHERE (@sameEnteredPerson = 1 AND @sameApprovedPerson = 1 AND @samePaidPerson = 1 AND EnteredPersonID = ApprovedPersonID AND EnteredPersonID = PaidPersonID)
		   OR (@sameEnteredPerson = 1 AND @sameApprovedPerson = 1 AND @samePaidPerson = 0 AND EnteredPersonID = ApprovedPersonID)
		   OR (@sameEnteredPerson = 1 AND @samePaidPerson = 1 AND @sameApprovedPerson = 0 AND EnteredPersonID = PaidPersonID)
		   OR (@sameApprovedPerson = 1 AND @samePaidPerson = 1 AND @sameEnteredPerson = 0 AND ApprovedPersonID = PaidPersonID)
    
END


GO
