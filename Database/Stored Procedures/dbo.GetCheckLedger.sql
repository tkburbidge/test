SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 22, 2011
-- Description:	Gets a list of items for a Bank Ledger
-- =============================================
CREATE PROCEDURE [dbo].[GetCheckLedger] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@bankAccountIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@onlyQueuedForPrinting bit = 0,
	@accountingPeriodID uniqueidentifier = null,
	@propertyIDs GuidCollection READONLY,
	@fromProcessor bit = 0,
	@includeDetails bit = 0	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL)

	CREATE TABLE #BankAccountIDs (
		BankAccountID uniqueidentifier NOT NULL)

	CREATE TABLE #PaymentsAndPonytails (
		PaymentID uniqueidentifier not null,
		BankTransactionID uniqueidentifier null,
		[Date] date null, 
		CheckNumber nvarchar(25) null, 
		PayTo nvarchar(250) null, 
		Amount money not null, 
		Memo nvarchar(75) null,
		CheckVoidedDate date null, 
		CheckPrintedDate date null,
		TransactionTypeGroup nvarchar(20) null, 
		TransactionTypeName nvarchar(50) null,
		ClearedDate date null,
		[Status] nvarchar(15) null,
		[TimeStamp] datetime null,
		BankAccountNumber nvarchar(256) null,
		BankAccountID uniqueidentifier null
	)



	-- IF @bankAccountIDs has values then @propertyIDs will be empty
	-- IF @propretyIDs has values then @bankAccountIDs will be empty
	IF ((SELECT COUNT(*) FROM @bankAccountIDs) <> 0)
	BEGIN

		INSERT #PropertiesAndDates
		SELECT DISTINCT bap.PropertyID, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM BankAccountProperty bap
				LEFT JOIN PropertyAccountingPeriod pap ON bap.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE bap.AccountID = @accountID
			  AND bap.BankAccountID IN (SELECT Value FROM @bankAccountIDs)

		INSERT #BankAccountIDs
			SELECT baIDs.Value
				FROM @bankAccountIDs baIDs
		--SELECT ba.BankAccountID
		--	FROM BankAccount ba
		--	WHERE ba.AccountID = @accountID
		--	  AND ba.BankAccountID = @bankAccountID

	END
	ELSE
	BEGIN

		INSERT #PropertiesAndDates
			SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
				FROM @propertyIDs pIDs
					LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

		INSERT #BankAccountIDs
			SELECT bap.BankAccountID
				FROM BankAccountProperty bap
				WHERE bap.AccountID = @accountID
				  AND bap.PropertyID IN (SELECT Value FROM @propertyIDs)

	END

	INSERT #PaymentsAndPonytails
		SELECT DISTINCT 
					p.PaymentID AS 'PaymentID', 
					bt.BankTransactionID, 
					CAST(p.[Date] AS Date) AS 'Date',
					bt.ReferenceNumber as 'CheckNumber', 
					p.ReceivedFromPaidTo as 'PayTo', 
					p.Amount, 
					p.[Description] AS 'Memo',
					p.ReversedDate AS 'CheckVoidedDate', 
					bt.CheckPrintedDate AS 'CheckPrintedDate',
					tt.[Group] AS 'TransactionTypeGroup', 
					tt.Name AS 'TransactionTypeName',
					bt.ClearedDate AS 'ClearedDate',
					CASE
						WHEN (bt.BankReconciliationID IS NOT NULL) THEN 'Reconciled'
						WHEN (bt.ClearedDate IS NOT NULL AND bt.BankReconciliationID IS NULL) THEN 'Cleared'
						ELSE 'Open'
						END AS 'Status',
					p.[TimeStamp],
					ba.AccountNumber AS 'BankAccountNumber',
					ba.BankAccountID
			FROM BankTransaction bt
				INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
				INNER JOIN [BankAccountProperty] baprop ON t.ObjectID = baprop.BankAccountID 
				INNER JOIN BankAccount ba ON baprop.BankAccountID = ba.BankAccountID
				INNER JOIN #PropertiesAndDates #pad ON prop.PropertyID = #pad.PropertyID
			WHERE p.AccountID = @accountID
			  AND ((@fromProcessor = 0 
					AND p.[Date] >= #pad.StartDate
					AND p.[Date] <= #pad.EndDate)
				OR (@fromProcessor = 1
					AND ((ba.PositivePayLastRunDate IS NOT NULL
						  AND p.[TimeStamp] > ba.PositivePayLastRunDate)
					  OR (ba.PositivePayLastRunDate IS NULL
						  AND p.[TimeStamp] > CONVERT(date, DATEADD(DAY,-1,GETDATE()))))))	
			  AND p.[Type] = 'Check'
			  AND t.ObjectID IN (SELECT BankAccountID FROM #BankAccountIDs)
			  AND t.IsDeleted = 0
			  AND (((tt.[Group] = 'Bank') AND (tt.Name = 'Check' OR tt.Name = 'Refund' OR tt.Name = 'Intercompany Refund')) OR ((tt.[Group] = 'Invoice') AND (tt.Name = 'Payment' OR tt.Name = 'Intercompany Payment')))
			  AND ((@onlyQueuedForPrinting = 0) OR ((bt.QueuedForPrinting = 1)))
			ORDER BY [Date]
		
		-- In the event that we have an intercompany payment and the bank account from which the money was withdrawn is also tied to the property
		-- that the invoice was posted to, we will get duplicate entries.  Here, delete the non-intercompany payment record
		DELETE #p
		FROM #PaymentsAndPonytails #p
			INNER JOIN #PaymentsAndPonytails #p2 ON #p2.PaymentID = #p.PaymentID AND #p2.TransactionTypeName = 'Intercompany Payment' AND #p2.TransactionTypeGroup = 'Invoice'
		WHERE #p.TransactionTypeName = 'Payment' 
			AND #p.TransactionTypeGroup = 'Invoice'

		-- Same story but for intercompany refunds
		DELETE #p
		FROM #PaymentsAndPonytails #p
			INNER JOIN #PaymentsAndPonytails #p2 ON #p2.PaymentID = #p.PaymentID AND #p2.TransactionTypeName = 'Intercompany Refund' AND #p2.TransactionTypeGroup = 'Bank'
		WHERE #p.TransactionTypeName = 'Refund' 
			AND #p.TransactionTypeGroup = 'Bank'

		SELECT * FROM #PaymentsAndPonytails
		
		IF (@includeDetails = 1)
		BEGIN
			
			SELECT
				p.PaymentID,
				tt.Name AS 'TransactionTypeName',
				SUM(
				CASE WHEN att.Name = 'Credit' THEN -t.Amount
				 ELSE t.Amount
				 END
				) AS 'Amount',
				t.PropertyID,
				prop.Name AS 'PropertyName',
				prop.Abbreviation AS 'PropertyAbbreviation',
				bt.ReferenceNumber AS 'Reference',
				CAST(p.[Date] AS Date) AS 'Date'
			FROM Payment p
				INNER JOIN PaymentTransaction pt on pt.PaymentID = p.PaymentID
				INNER JOIN [Transaction] t on pt.TransactionID = t.TransactionID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN #PaymentsAndPonytails #pp on p.PaymentID = #pp.PaymentID
				INNER JOIN Property prop on t.PropertyID = prop.PropertyID
				INNER JOIN BankTransaction bt on p.PaymentID = bt.ObjectID
				INNER JOIN [Transaction] at on at.TransactionID = t.AppliesToTransactionID
				INNER JOIN [TransactionType] att on att.TransactionTypeID = at.TransactionTypeID
			WHERE t.ReversesTransactionID IS NULL
			GROUP BY t.PropertyID, prop.Name, prop.Abbreviation, p.PaymentID, bt.ReferenceNumber, tt.Name, p.[Date]--, att.Name
		
		END		
END

GO
