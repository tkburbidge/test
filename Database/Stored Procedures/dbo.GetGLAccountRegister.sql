SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 30, 2012
-- Description:	Gets the GL Account Infomation for Display
-- =============================================
CREATE PROCEDURE [dbo].[GetGLAccountRegister] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	--@glAccountID uniqueidentifier = null,
	@glAccountIDs GuidCollection readonly,
	@glAccountTypes StringCollection readonly,	
	@accountingBasis nvarchar(10) = null,
	@startDate datetime = null,
	@endDate datetime = null,
	@propertyIDs GuidCollection readonly,
	@groupByDay bit = null,
	@summarizeSlushAccounts bit = null,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@accountingPeriodID uniqueidentifier = null,
	@accountingBookIDs GuidCollection readonly
AS
DECLARE @accountsReceivableGLAccountID uniqueidentifier
DECLARE @undepositedFundsGLAccountID uniqueidentifier
DECLARE @prepaidIncomeGLAccountID uniqueidentifier
DECLARE @accountsPayableGLAccountID uniqueidentifier
DECLARE @startTime datetime2

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SET @accountsReceivableGLAccountID = (SELECT GLAccountID FROM TransactionType WHERE Name = 'Charge' AND [Group] = 'Lease' AND AccountID = @accountID)
	SET @undepositedFundsGLAccountID = (SELECT GLAccountID FROM TransactionType WHERE Name = 'Deposit' AND [Group] = 'Bank' AND AccountID = @accountID)
	SET @prepaidIncomeGLAccountID = (SELECT GLAccountID FROM TransactionType WHERE Name = 'Prepayment' AND [Group] = 'Lease' AND AccountID = @accountID)
	SET @accountsPayableGLAccountID = (SELECT GLAccountID FROM TransactionType WHERE Name = 'Charge' AND [Group] = 'Invoice' AND AccountID = @accountID)
	
	CREATE TABLE #Accounts (GLAccountID uniqueidentifier null)	
		
	-- If we are passed in types, get all GL Accounts
	-- based on the types passed in
	IF ((SELECT COUNT(*) FROM @glAccountTypes) > 0)
	BEGIN
		INSERT INTO #Accounts
			SELECT GLAccountID
			FROM GLAccount 
			WHERE AccountID = @accountID
				AND GLAccountType IN (SELECT Value FROM @glAccountTypes)
	END
	ELSE IF ((SELECT COUNT(*) FROM @glAccountIDs) > 0)
	BEGIN
		INSERT INTO #Accounts SELECT Value FROM @glAccountIDs
	END
	ELSE 
	BEGIN
		INSERT INTO #Accounts 
			SELECT GLAccountID 
			FROM GLAccount
			WHERE AccountID = @accountID
	END
		
	--CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	--INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs		
	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null)
		
	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		
	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier not null)

	INSERT #AccountingBooks 
		SELECT Value FROM @accountingBookIDs

	--CREATE TABLE #TimeMe (
	--	StartTime datetime2 not null,
	--	EndTime datetime2 not null,
	--	Chunk nvarchar(50) not null)
		
	IF (@groupByDay = 1)
	BEGIN
		--SET @startTime = SYSDATETIME()		
			
		IF (@alternateChartOfAccountsID IS NULL)
		BEGIN			
			SELECT 	
				null AS 'JournalEntryID',
				null AS 'PropertyID',	
				null AS 'PropertyAbbreviation',
				t.TransactionDate AS 'Date',
				null AS 'ObjectID',
				null AS 'ObjectType',
				null AS 'ObjectName',		
				null AS 'TransactionObjectID',
				null AS 'TransactionObjectType',
				null AS 'Reference',
				CONVERT(nvarchar(20), COUNT(*)) AS 'Description',
				SUM(je.Amount) AS 'Amount',
				t.TransactionDate AS 'TimeStamp', 				
				je.GLAccountID AS 'GLAccountID',
				CAST(1 AS bit) AS 'Summary',
				ap.EndDate AS 'AccountingPeriodEndDate',
				'0' AS 'Origin',
				null AS 'AltObjectID',
				1 AS 'TopOrderBy'		
			FROM JournalEntry je
				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID --AND t.TransactionDate >= @startDate AND t.TransactionDate <= @endDate
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
				--INNER JOIN AccountingPeriod ap ON ap.StartDate <= t.TransactionDate AND ap.EndDate >= t.TransactionDate AND ap.AccountID = @accountID
				INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.EndDate >= t.TransactionDate AND pap.StartDate <= t.TransactionDate
				INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
				INNER JOIN #Accounts ON #Accounts.GLAccountID = je.GLAccountID
				INNER JOIN #AccountingBooks #ab ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #ab.AccountingBookID
				--INNER JOIN #PropertyIDs ON #PropertyIDs.PropertyID = t.PropertyID				
			WHERE je.AccountID = @accountID		  
			  AND je.AccountingBasis = @accountingBasis		
			  AND t.Origin NOT IN ('Y', 'E')			  
			GROUP BY je.GLAccountID, t.TransactionDate, ap.EndDate
			
			UNION ALL 
			-- Get year end entries separate
			SELECT 	
					je.JournalEntryID, p.PropertyID AS 'PropertyID',	
					p.Abbreviation AS 'PropertyAbbreviation',
					t.TransactionDate AS 'Date',
					t.PropertyID AS 'ObjectID',
					tt.[Group] AS 'ObjectType', 
					p.Name AS 'ObjectName',
					tg.TransactionGroupID AS 'TransactionObjectID',
					tt.Name AS 'TransactionObjectType',
					null AS 'Reference',
					t.[Description] AS 'Description',
					je.Amount AS 'Amount',
					t.[TimeStamp] AS 'TimeStamp',
					je.GLAccountID AS 'GLAccountID',
					CAST(0 as bit) AS 'Summary',
					ap.EndDate AS 'AccountingPeriodEndDate',
					t.Origin,
					null AS 'AltObjectID',
					0 AS 'TopOrderBy'
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN Property p ON t.PropertyID = p.PropertyID
					INNER JOIN TransactionGroup tg ON t.TransactionID = tg.TransactionID
					INNER JOIN #Accounts ON #Accounts.GLAccountID = je.GLAccountID
					--INNER JOIN #PropertyIDs ON #PropertyIDs.PropertyID = t.PropertyID	
					--INNER JOIN AccountingPeriod ap ON ap.StartDate <= t.TransactionDate AND ap.EndDate >= t.TransactionDate AND ap.AccountID = @accountID
					INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate <= t.TransactionDate AND pap.EndDate >= t.TransactionDate AND t.PropertyID = pap.PropertyID
					INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
					INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
					INNER JOIN #AccountingBooks #ab ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #ab.AccountingBookID
				WHERE je.AccountID = @accountID				  				  
				  AND je.AccountingBasis = @accountingBasis
				  --AND t.TransactionDate <= @endDate
				  --AND t.TransactionDate >= @startDate	
				  AND t.TransactionDate >= #pad.StartDate
				  AND t.TransactionDate <= #pad.EndDate
				  AND tt.[Group] in ('Journal Entry')
				  AND t.Origin IN ('Y', 'E')
			ORDER BY TopOrderBy, t.TransactionDate, je.GLAccountID
		END
		ELSE
		BEGIN
			(SELECT 	
					null AS 'JournalEntryID',
					null AS 'PropertyID',	
					null AS 'PropertyAbbreviation',
					t.TransactionDate AS 'Date',
					null AS 'ObjectID',
					null AS 'ObjectType',
					null AS 'ObjectName',		
					null AS 'TransactionObjectID',
					null AS 'TransactionObjectType',
					null AS 'Reference',
					CONVERT(nvarchar(20), COUNT(*)) AS 'Description',
					SUM(je.Amount) AS 'Amount',
					t.TransactionDate AS 'TimeStamp', 
					altGLA.AlternateGLAccountID AS 'GLAccountID',			
					CAST(1 AS bit) AS 'Summary',
					ap.EndDate AS 'AccountingPeriodEndDate',
					'0' AS 'Origin',
					null AS 'AltObjectID',
					1 AS 'TopOrderBy'
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID --AND t.TransactionDate >= @startDate AND t.TransactionDate <= @endDate
					INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
					--INNER JOIN AccountingPeriod ap ON ap.StartDate <= t.TransactionDate AND ap.EndDate >= t.TransactionDate AND ap.AccountID = @accountID
					INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate <= t.TransactionDate AND pap.EndDate >= t.TransactionDate AND pap.PropertyID = t.PropertyID
					INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
					INNER JOIN #Accounts ON #Accounts.GLAccountID = je.GLAccountID
					--INNER JOIN #PropertyIDs ON #PropertyIDs.PropertyID = t.PropertyID
					INNER JOIN GLAccountAlternateGLAccount altGLA ON je.GLAccountID = altGLA.GLAccountID
					INNER JOIN AlternateGLAccount alt ON alt.AlternateGLAccountID = altGLA.AlternateGLAccountID AND alt.AlternateChartOfAccountsID = @alternateChartOfAccountsID
					INNER JOIN #AccountingBooks #ab ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #ab.AccountingBookID
				WHERE je.AccountID = @accountID		  
				  AND je.AccountingBasis = @accountingBasis
				  AND t.Origin NOT IN ('Y', 'E')
				GROUP BY altGLA.AlternateGLAccountID, t.TransactionDate, ap.EndDate	)			
				
				UNION ALL
				
				(SELECT 	
					je.JournalEntryID, 
					p.PropertyID AS 'PropertyID',	
					p.Abbreviation AS 'PropertyAbbreviation',
					t.TransactionDate AS 'Date',
					t.PropertyID AS 'ObjectID',
					tt.[Group] AS 'ObjectType', 
					p.Name AS 'ObjectName',
					tg.TransactionGroupID AS 'TransactionObjectID',
					tt.Name AS 'TransactionObjectType',
					null AS 'Reference',
					t.[Description] AS 'Description',
					je.Amount AS 'Amount',
					t.[TimeStamp] AS 'TimeStamp',
					je.GLAccountID AS 'GLAccountID',
					CAST(0 as bit) AS 'Summary',
					ap.EndDate AS 'AccountingPeriodEndDate',
					t.Origin,
					null AS 'AltObjectID',
					0 AS 'TopOrderBy'
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN Property p ON t.PropertyID = p.PropertyID
					INNER JOIN TransactionGroup tg ON t.TransactionID = tg.TransactionID
					INNER JOIN #Accounts ON #Accounts.GLAccountID = je.GLAccountID
					--INNER JOIN #PropertyIDs ON #PropertyIDs.PropertyID = t.PropertyID	
					--INNER JOIN AccountingPeriod ap ON ap.StartDate <= t.TransactionDate AND ap.EndDate >= t.TransactionDate AND ap.AccountID = @accountID
					INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate <= t.TransactionDate AND pap.EndDate >= t.TransactionDate AND pap.PropertyID = t.PropertyID
					INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
					INNER JOIN GLAccountAlternateGLAccount altGLA ON je.GLAccountID = altGLA.GLAccountID
					INNER JOIN AlternateGLAccount alt ON alt.AlternateGLAccountID = altGLA.AlternateGLAccountID AND alt.AlternateChartOfAccountsID = @alternateChartOfAccountsID
					INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
					INNER JOIN #AccountingBooks #ab ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #ab.AccountingBookID
				WHERE je.AccountID = @accountID				  				  
				  AND je.AccountingBasis = @accountingBasis
				  --AND t.TransactionDate <= @endDate
				  --AND t.TransactionDate >= @startDate	
				  AND t.TransactionDate <= #pad.EndDate
				  AND t.TransactionDate >= #pad.StartDate			 
				  AND tt.[Group] in ('Journal Entry')
				  AND t.Origin IN ('Y', 'E'))
			ORDER BY TopOrderBy, t.TransactionDate, altGLA.AlternateGLAccountID
							  
		END				
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Summary')	
	END
		
	ELSE
	BEGIN	
	
		CREATE TABLE #TempRegister (
			JournalEntryID uniqueidentifier null,
			TransactionID uniqueidentifier null,
			TransactionAppliesToTransactionID uniqueidentifier null,
			PropertyID uniqueidentifier null,
			PropertyAbbreviation nvarchar(50) null,
			[TransactionDate] DateTime not null,
			ObjectID uniqueidentifier null,
			ObjectType nvarchar(50) null,
			ObjectName nvarchar(500) null,
			TransactionObjectID uniqueidentifier null,
			TransactionObjectType nvarchar(50) null,
			Reference nvarchar(100) null,
			[Description] nvarchar(1000) null,
			JournalEntryAmount money null,
			TransactionAmount money null,
			[TimeStamp] datetime null,
			GLAccountID uniqueidentifier null,
			Summary bit not null,
			Origin nvarchar(100) null,
			AltObjectID uniqueidentifier null,
			TransactionTypeName nvarchar(100),
			TransactionTypeGroup nvarchar(100),
			ReversesTransactionID uniqueidentifier null,
			AccountingBookID uniqueidentifier null)

		CREATE TABLE #Register (
			JournalEntryID uniqueidentifier null,
			PropertyID uniqueidentifier null,
			PropertyAbbreviation nvarchar(50) null,
			[Date] DateTime not null,
			ObjectID uniqueidentifier null,
			ObjectType nvarchar(50) null,
			ObjectName nvarchar(500) null,
			TransactionObjectID uniqueidentifier null,
			TransactionObjectType nvarchar(50) null,
			Reference nvarchar(100) null,
			[Description] nvarchar(1000) null,
			Amount money null,
			[TimeStamp] datetime null,
			GLAccountID uniqueidentifier null,
			Summary bit not null,
			Origin nvarchar(100) null,
			AltObjectID uniqueidentifier null,
			AccountingBookID uniqueidentifier null)
			
		--SET @startTime = SYSDATETIME()

		CREATE TABLE #SlushTransactionTypeIDs ( TransactionTypeID uniqueidentifier )
		INSERT  #SlushTransactionTypeIDs
			SELECT TransactionTypeID
			FROM TransactionType
			WHERE ([Group] in ('Unit') AND Name IN ('Charge', 'Credit', 'Over Credit'))
			OR ([Group] in ('Lease')
					AND Name in ('Charge', 'Balance Transfer Payment', 'Balance Transfer Deposit', 'Deposit Applied to Deposit',
											'Deposit Applied to Balance', 'Deposit Refund', 'Tax Charge',
									'Credit', 'Payment', 'Deposit', 'Prepayment', 'Over Credit', 'Payment Refund', 
													'Tax Credit', 'Tax Payment'))
			OR ([Group] in ('Prospect', 'Non-Resident Account', 'WOIT Account')
				AND Name in ('Charge', 'Balance Transfer Payment', 'Balance Transfer Deposit', 'Deposit Applied to Deposit',
									'Deposit Applied to Balance', 'Deposit Refund', 'Tax Charge',
								'Credit', 'Payment', 'Deposit', 'Prepayment', 'Over Credit', 'Payment Refund', 'Tax Credit', 'Tax Payment'))
			OR ([Group] IN ('Invoice')
				AND Name IN ('Charge', 'Credit', 'Payment'))

		-- Get everything from the Transaction and JournalEntry table that we need and 
		-- then stop touching those tables		
		INSERT INTO #TempRegister
			SELECT 		
					je.JournalEntryID, 
					t.TransactionID,
					t.AppliesToTransactionID,
					t.PropertyID AS 'PropertyID',
					p.Abbreviation AS 'PropertyAbbreviation',
					t.TransactionDate AS 'Date',
					t.ObjectID AS 'ObjectID',
					tt.[Group] AS 'ObjectType', 
					'' AS 'ObjectName',
					t.ObjectID AS 'TransactionObjectID',
					tt.Name AS 'TransactionObjectType',
					null AS 'Reference',
					t.[Description] AS 'Description',
					je.Amount AS 'JournalEntryAmount',
					t.Amount AS 'TransactionAmount',
					t.[TimeStamp] AS 'TimeStamp',
					je.GLAccountID AS 'GLAccountID',
					0 AS 'Summary',
					t.Origin,
					null AS 'AltObjectID',
					tt.Name,
					tt.[Group],
					t.ReversesTransactionID,
					je.AccountingBookID
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
					INNER JOIN Property p ON p.PropertyID = t.PropertyID
					INNER JOIN #Accounts ON #Accounts.GLAccountID = je.GLAccountID
					INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
					INNER JOIN #AccountingBooks #ab ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #ab.AccountingBookID
				WHERE je.AccountID = @accountID								  
				  AND je.AccountingBasis = @accountingBasis
				 AND  ((@summarizeSlushAccounts = 0) 				
					OR ((@summarizeSlushAccounts = 1) AND 
						(je.GLAccountID NOT IN (@accountsReceivableGLAccountID, @undepositedFundsGLAccountID, @prepaidIncomeGLAccountID, @accountsPayableGLAccountID)
						OR
						tt.TransactionTypeID NOT IN (SELECT TransactionTypeID FROM #SlushTransactionTypeIDs))))
				
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Initial Transaction Data')
		--SET @startTime = SYSDATETIME()

								  
		INSERT INTO #Register
			-- Bank transactions
			SELECT 	
					#r.JournalEntryID, 
					#r.PropertyID AS 'PropertyID',
					#r.PropertyAbbreviation AS 'PropertyAbbreviation',
					#r.[TransactionDate] AS 'Date',
					#r.ObjectID AS 'ObjectID',
					#r.TransactionTypeGroup AS 'ObjectType', 
					ba.AccountNumberDisplay + '-' + ba.AccountName AS 'ObjectName',
					(CASE WHEN btc.Category = 'System Deposit' THEN bt.BankTransactionID ELSE #r.TransactionID END) AS 'TransactionObjectID',
					--t.TransactionID AS 'TransactionObjectID',
				   (CASE WHEN btc.Category = 'System Deposit' THEN 'System Deposit' ELSE #r.TransactionTypeName END) AS 'TransactionObjectType',
					bt.ReferenceNumber,
					#r.Description,			
					#r.JournalEntryAmount AS 'Amount',
					#r.[TimeStamp] AS 'TimeStamp',
					#r.GLAccountID AS 'GLAccountID',
					0 AS 'Summary',
					#r.Origin,
					null AS 'AltObjectID',
					#r.AccountingBookID
				FROM #TempRegister #r 														
					LEFT JOIN BankTransactionTransaction btt ON #r.TransactionID = btt.TransactionID					
					LEFT JOIN BankTransaction bt ON btt.BankTransactionID = bt.BankTransactionID OR bt.ObjectID = #r.TransactionID
					INNER JOIN BankAccount ba ON #r.ObjectID = ba.BankAccountID
					LEFT JOIN BankTransactionCategory btc on btc.BankTransactionCategoryID = bt.BankTransactionCategoryID					
				WHERE #r.TransactionTypeGroup = 'Bank'
					AND #r.TransactionTypeName IN ('Deposit', 'Withdrawal', 'Adjustment', 'Transfer')				  
			
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Bank Dep/Withdrawal/Adg/Trans')
		--SET @startTime = SYSDATETIME()
		
		INSERT INTO #Register			
			-- Bank checks and refunds
			SELECT 	
					#r.JournalEntryID,
					#r.PropertyID AS 'PropertyID',
					#r.PropertyAbbreviation AS 'PropertyAbbreviation',
					#r.TransactionDate AS 'Date',
					py.ObjectID AS 'ObjectID',
					py.ObjectType AS 'ObjectType', 
					py.ReceivedFromPaidTo AS 'ObjectName',
					py.PaymentID AS 'TransactionObjectID',
					#r.TransactionTypeName AS 'TransactionObjectType',
					CASE
						WHEN #r.TransactionAmount < 0 THEN 'R-' + bt.ReferenceNumber
						ELSE bt.ReferenceNumber
						END AS 'Reference',
					CASE
						WHEN #r.TransactionAmount < 0 THEN 'Reversed ' + py.[Description] 
						ELSE py.[Description] 
						END AS 'Description',
					#r.JournalEntryAmount AS 'Amount',
					#r.[TimeStamp] AS 'TimeStamp',
					#r.GLAccountID AS 'GLAccountID',
					0 AS 'Summary',
					#r.Origin,
					null AS 'AltObjectID',
					#r.AccountingBookID	
				FROM #TempRegister #r
					INNER JOIN PaymentTransaction pt ON #r.TransactionID = pt.TransactionID
					INNER JOIN Payment py ON pt.PaymentID = py.PaymentID
					INNER JOIN BankTransaction bt ON bt.ObjectID = py.PaymentID
					INNER JOIN BankAccount ba ON #r.TransactionObjectID = ba.BankAccountID 				
				WHERE #r.TransactionTypeGroup = 'Bank'
					AND #r.TransactionTypeName IN ('Check', 'Refund', 'Vendor Credit', 'Intercompany Refund')	  
				  
		
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Bank Check/Refund')
		--SET @startTime = SYSDATETIME()
		INSERT INTO #Register
					
			-- Unit charges
			SELECT 		
					#r.JournalEntryID, 
					#r.PropertyID AS 'PropertyID',
					#r.PropertyAbbreviation AS 'PropertyAbbreviation',
					#r.TransactionDate AS 'Date',
					u.UnitID AS 'ObjectID',
					#r.TransactionTypeGroup AS 'ObjectType', 
					u.Number + ' - Vacant Unit' AS 'ObjectName',
					#r.TransactionID AS 'TransactionObjectID',
					#r.TransactionTypeName AS 'TransactionObjectType',
					null AS 'Reference',
					#r.[Description] AS 'Description',
					#r.JournalEntryAmount AS 'Amount',
					#r.[TimeStamp] AS 'TimeStamp',
					#r.GLAccountID AS 'GLAccountID',
					0 AS 'Summary',
					#r.Origin,
					null AS 'AltObjectID',
					#r.AccountingBookID 	
				FROM #TempRegister #r					
					INNER JOIN Unit u ON #r.TransactionObjectID = u.UnitID					
				WHERE #r.TransactionTypeGroup = 'Unit'
					AND #r.TransactionTypeName IN ('Charge')	  
													  
		
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Unit Charge')		
		--SET @startTime = SYSDATETIME()
		
		IF ((SELECT COUNT(*) FROM #TempRegister WHERE TransactionTypeGroup = 'Unit') > 0)
		BEGIN
			INSERT INTO #Register
			
				-- Unit credits
				SELECT 		
						#r.JournalEntryID, 
						#r.PropertyID AS 'PropertyID',
						#r.PropertyAbbreviation AS 'PropertyAbbreviation',
						#r.TransactionDate AS 'Date',
						u.UnitID AS 'ObjectID',
						#r.TransactionTypeGroup AS 'ObjectType', 
						py.ReceivedFromPaidTo AS 'ObjectName',
						py.PaymentID AS 'TransactionObjectID',
						#r.TransactionTypeName AS 'TransactionObjectType',
						null AS 'Reference',
						#r.[Description] AS 'Description',
						#r.JournalEntryAmount AS 'Amount',
						#r.[TimeStamp] AS 'TimeStamp',
						#r.GLAccountID AS 'GLAccountID',
						0 AS 'Summary',
						#r.Origin,
						null AS 'AltObjectID',
						#r.AccountingBookID
					FROM #TempRegister #r						
						INNER JOIN Unit u ON #r.TransactionObjectID = u.UnitID
						INNER JOIN PaymentTransaction pt ON #r.TransactionID = pt.TransactionID
						INNER JOIN Payment py ON py.PaymentID = pt.PaymentID					
					WHERE #r.TransactionTypeGroup = 'Unit'
						AND #r.TransactionTypeName IN ('Charge')	  
				  
		END
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Unit Credit')
		--SET @startTime = SYSDATETIME()
		
		INSERT INTO #Register			
			-- Journal Entries
			SELECT 	
					#r.JournalEntryID, 
					#r.PropertyID AS 'PropertyID',	
					#r.PropertyAbbreviation AS 'PropertyAbbreviation',
					#r.TransactionDate AS 'Date',
					#r.PropertyID AS 'ObjectID',
					#r.TransactionTypeGroup AS 'ObjectType', 
					p.Name AS 'ObjectName',
					tg.TransactionGroupID AS 'TransactionObjectID',
					#r.TransactionTypeName AS 'TransactionObjectType',
					null AS 'Reference',
					#r.[Description] AS 'Description',
					#r.JournalEntryAmount AS 'Amount',
					#r.[TimeStamp] AS 'TimeStamp',
					#r.GLAccountID AS 'GLAccountID',
					0 AS 'Summary',
					#r.Origin,
					null AS 'AltObjectID',
					#r.AccountingBookID
				FROM #TempRegister #r						
					INNER JOIN Property p ON #r.PropertyID = p.PropertyID
					INNER JOIN TransactionGroup tg ON #r.TransactionID = tg.TransactionID					
				WHERE #r.TransactionTypeGroup = 'Journal Entry'
				  
		
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Journal Entry')
		--SET @startTime = SYSDATETIME()
		INSERT INTO #Register

			-- Invoice charges and credits
			SELECT 	
				#r.JournalEntryID, 
				#r.PropertyID AS 'PropertyID',	
				#r.PropertyAbbreviation AS 'PropertyAbbreviation',
				#r.TransactionDate AS 'Date',
				v.VendorID AS 'ObjectID',
				#r.TransactionTypeGroup AS 'ObjectType', 
				CASE 
					WHEN (v.Summary = 1) THEN sv.Name
					ELSE v.CompanyName
					END AS 'ObjectName',
				#r.TransactionObjectID AS 'TransactionObjectID',
				#r.TransactionTypeName AS 'TransactionObjectType',
				CASE
					WHEN #r.ReversesTransactionID IS NOT NULL THEN 'V-' + i.Number 
					ELSE i.Number
					END AS 'Reference',
				CASE
					WHEN #r.ReversesTransactionID IS NOT NULL THEN 'Voided ' + #r.[Description] 
					ELSE #r.[Description] 
					END AS 'Description',
				#r.JournalEntryAmount AS 'Amount',
				#r.[TimeStamp] AS 'TimeStamp',
				#r.GLAccountID AS 'GLAccountID',
				0 AS 'Summary',
				#r.Origin,
				null AS 'AltObjectID',
				#r.AccountingBookID
			FROM #TempRegister #r				
				INNER JOIN Invoice i ON #r.TransactionObjectID = i.InvoiceID
				INNER JOIN Vendor v ON i.VendorID = v.VendorID
				LEFT JOIN SummaryVendor sv ON i.SummaryVendorID = sv.SummaryVendorID			
			WHERE #r.TransactionTypeGroup = 'Invoice'
				AND #r.TransactionTypeName IN ('Charge', 'Credit')
			 

		
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Invoice Charge/Credit')
		--SET @startTime = SYSDATETIME()
		INSERT INTO #Register
			
			-- Invoice payments
			SELECT 	
				#r.JournalEntryID, 
				#r.PropertyID AS 'PropertyID',	
				#r.PropertyAbbreviation AS 'PropertyAbbreviation',
				#R.TransactionDate AS 'Date',
				py.ObjectID AS 'ObjectID',
				py.ObjectType AS 'ObjectType',
				py.ReceivedFromPaidTo AS 'ObjectName',
				py.PaymentID AS 'TransactionObjectID',
				#r.TransactionTypeName AS 'TransactionObjectType',
				CASE
					WHEN #r.ReversesTransactionID IS NOT NULL THEN 'R-' + py.ReferenceNumber
					ELSE py.ReferenceNumber
					END AS 'Reference',
				CASE 
					WHEN #r.ReversesTransactionID IS NOT NULL THEN 'Reversed ' + #r.[Description] 
					ELSE #r.[Description] 
					END AS 'Description',
				#r.JournalEntryAmount AS 'Amount',
				#r.[TimeStamp] AS 'TimeStamp',
				#r.GLAccountID AS 'GLAccountID',
				0 AS 'Summary',
				#r.Origin,
				#r.TransactionAppliesToTransactionID AS 'AltObjectID',
				#r.AccountingBookID
			FROM #TempRegister #r				
				INNER JOIN PaymentTransaction pt ON pt.TransactionID = #r.TransactionID
				INNER JOIN Payment py ON py.PaymentID = pt.PaymentID				
			WHERE #r.TransactionTypeGroup = 'Invoice'
			  AND #r.TransactionTypeName IN ('Payment', 'Intercompany Payment')	
			  
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Invoice Payment')
		--SET @startTime = SYSDATETIME()
		INSERT INTO #Register
			
			-- Lease Charges and other transaction related items
			SELECT 	
				#r.JournalEntryID, 
				#r.PropertyID AS 'PropertyID',	
				#r.PropertyAbbreviation AS 'PropertyAbbreviation',
				#r.TransactionDate AS 'Date',
				l.LeaseID AS 'ObjectID',
				#r.TransactionTypeGroup AS 'ObjectType',
			   (u.Number + ' - ' + STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID				 
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 ORDER BY PersonLease.OrderBy, Person.PreferredName
					 FOR XML PATH ('')), 1, 2, '')) AS 'ObjectName',		
				#r.TransactionID AS 'TransactionObjectID',
				#r.TransactionTypeName AS 'TransactionObjectType',
				null AS 'Reference',
				#r.[Description] AS 'Description',
				#r.JournalEntryAmount AS 'Amount',
				#r.[TimeStamp] AS 'TimeStamp',
				#r.GLAccountID AS 'GLAccountID',
				0 AS 'Summary',
				#r.Origin,
				null AS 'AltObjectID',
				#r.AccountingBookID
			FROM #TempRegister #r				
				INNER JOIN UnitLeaseGroup ulg ON #r.TransactionObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID				
			WHERE  #r.TransactionTypeGroup = 'Lease'
			  AND #r.TransactionTypeName IN ('Charge', 'Balance Transfer Payment', 'Balance Transfer Deposit', 'Deposit Applied to Deposit',
																	'Deposit Applied to Balance', 'Tax Charge')						  
			  AND (l.LeaseID = (SELECT TOP 1 l2.LeaseID
								FROM Lease l2
								WHERE l2.UnitLeaseGroupID = #r.TransactionObjectID
								ORDER BY l2.LeaseEndDate DESC))
			 
		
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Lease Charge')
		--SET @startTime = SYSDATETIME()
		INSERT INTO #Register
			
			-- Lease Payments
			SELECT 	
				#r.JournalEntryID, 
				#r.PropertyID AS 'PropertyID',	
				#r.PropertyAbbreviation AS 'PropertyAbbreviation',
				#r.TransactionDate AS 'Date',
				l.LeaseID AS 'ObjectID',
				#r.TransactionTypeGroup AS 'ObjectType',
				py.ReceivedFromPaidTo AS 'ObjectName',		
				py.PaymentID AS 'TransactionObjectID',
				#r.TransactionTypeName AS 'TransactionObjectType',
				py.ReferenceNumber AS 'Reference',
				#r.[Description] AS 'Description',
				#r.JournalEntryAmount AS 'Amount',
				#r.[TimeStamp] AS 'TimeStamp',
				#r.GLAccountID AS 'GLAccountID',
				0 AS 'Summary',
				#r.Origin,
				null AS 'AltObjectID',
				#r.AccountingBookID
			FROM #TempRegister #r			
				INNER JOIN UnitLeaseGroup ulg ON #r.TransactionObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN PaymentTransaction pt ON pt.TransactionID = #r.TransactionID
				INNER JOIN Payment py ON py.PaymentID = pt.PaymentID					
			WHERE  #r.TransactionTypeGroup = 'Lease'
			  AND #r.TransactionTypeName IN ('Credit', 'Payment', 'Deposit', 'Deposit Interest Payment', 'Prepayment', 'Over Credit', 'Payment Refund', 
																			'Tax Credit', 'Tax Payment', 'Deposit Refund')			  
			  AND (l.LeaseID = (SELECT TOP 1 l2.LeaseID
								FROM Lease l2
								WHERE l2.UnitLeaseGroupID = #r.TransactionObjectID
								ORDER BY l2.LeaseEndDate DESC))
			 
			
		
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Lease P/C')
		--SET @startTime = SYSDATETIME()
		INSERT INTO #Register
			
			SELECT 	
				#r.JournalEntryID, 
				#r.PropertyID AS 'PropertyID',	
				#r.PropertyAbbreviation AS 'PropertyAbbreviation',
				#r.TransactionDate AS 'Date',
				#r.TransactionObjectID AS 'ObjectID',
				#r.TransactionTypeGroup AS 'ObjectType',
				CASE #r.TransactionTypeGroup
					WHEN 'WOIT Account' THEN woita.Name
					ELSE pr.PreferredName + ' ' + pr.LastName
					END AS 'ObjectName',		 
				#r.TransactionID AS 'TransactionObjectID',
				#r.TransactionTypeName AS 'TransactionObjectType',
				null AS 'Reference',
				#r.[Description] AS 'Description',
				#r.JournalEntryAmount AS 'Amount',
				#r.[TimeStamp] AS 'TimeStamp',
				#r.GLAccountID AS 'GLAccountID',
				0 AS 'Summary',
				#r.Origin,
				null AS 'AltObjectID',
				#r.AccountingBookID	
			FROM #TempRegister #r				
				LEFT JOIN Person pr ON #r.TransactionObjectID = pr.PersonID
				LEFT JOIN WOITAccount woita ON #r.TransactionObjectID = woita.WOITAccountID				
			WHERE #r.[TransactionTypeGroup] in ('Prospect', 'Non-Resident Account', 'WOIT Account')
			  AND #r.TransactionTypeName in ('Charge', 'Balance Transfer Payment', 'Balance Transfer Deposit', 'Deposit Applied to Deposit',
							  'Deposit Applied to Balance', 'Tax Charge') 		
			  
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Non-Lease Charge')
		--SET @startTime = SYSDATETIME()
		INSERT INTO #Register

			SELECT 	
				#r.JournalEntryID, 
				#r.PropertyID AS 'PropertyID',	
				#r.PropertyAbbreviation AS 'PropertyAbbreviation',
				#r.TransactionDate AS 'Date',
				#r.TransactionObjectID AS 'ObjectID',
				#r.TransactionTypeGroup AS 'ObjectType',
				py.ReceivedFromPaidTo AS 'ObjectName',		
				py.PaymentID AS 'TransactionObjectID',
				#r.[TransactionTypeName] AS 'TransactionObjectType',
				py.ReferenceNumber AS 'Reference',
				#r.[Description] AS 'Description',
				#r.JournalEntryAmount AS 'Amount',
				#r.[TimeStamp] AS 'TimeStamp',
				#r.GLAccountID AS 'GLAccountID',
				0 AS 'Summary',
				#r.Origin,
				null AS 'AltObjectID',
				#r.AccountingBookID
			FROM #TempRegister #r				
				INNER JOIN PaymentTransaction pt ON pt.TransactionID = #r.TransactionID
				INNER JOIN Payment py ON py.PaymentID = pt.PaymentID
			WHERE #r.[TransactionTypeGroup] in ('Prospect', 'Non-Resident Account', 'WOIT Account')
			  AND #r.TransactionTypeName in ('Credit', 'Payment', 'Deposit', 'Prepayment', 'Over Credit', 'Payment Refund', 'Deposit Refund', 'Tax Credit', 'Tax Payment') 			
			  
			
		--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Non-Lease P/C')
		--SET @startTime = SYSDATETIME()
		

		-- If we are summarizing slush accounts we need to add a record
		-- for each account and day that we skipped in the above queries
		IF (@summarizeSlushAccounts = 1)
		BEGIN
				INSERT INTO #Register
				SELECT 	
					null as 'JournalEntryID',
					p.PropertyID AS 'PropertyID',	
					p.Abbreviation AS 'PropertyAbbreviation',
					t.TransactionDate AS 'Date',
					null AS 'ObjectID',
					null AS 'ObjectType',
					null AS 'ObjectName',		
					null AS 'TransactionObjectID',
					null AS 'TransactionObjectType',
					null AS 'Reference',
					CONVERT(nvarchar(20), COUNT(*)) AS 'Description',
					SUM(je.Amount) AS 'Amount',
					t.TransactionDate AS 'TimeStamp', 
					je.GLAccountID AS 'GLAccountID',
					1 AS 'Summary',
					'0' AS 'Origin',
					null AS 'AltObjectID',
					null AS 'AccountingBookID'
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID-- AND t.TransactionDate >= @startDate AND t.TransactionDate <= @endDate
					INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
								AND t.TransactionTypeID IN (SELECT TransactionTypeID
															 FROM TransactionType
															 WHERE ([Group] in ('Unit') AND Name IN ('Charge', 'Credit', 'Over Credit'))
																OR ([Group] in ('Lease')
																		AND Name in ('Charge', 'Balance Transfer Payment', 'Balance Transfer Deposit', 'Deposit Applied to Deposit',
																								'Deposit Applied to Balance', 'Deposit Refund', 'Tax Charge',
																						'Credit', 'Payment', 'Deposit', 'Prepayment', 'Over Credit', 'Payment Refund', 
																										'Tax Credit', 'Tax Payment'))
																OR ([Group] in ('Prospect', 'Non-Resident Account', 'WOIT Account')
																	AND Name in ('Charge', 'Balance Transfer Payment', 'Balance Transfer Deposit', 'Deposit Applied to Deposit',
																						'Deposit Applied to Balance', 'Deposit Refund', 'Tax Charge',
																					'Credit', 'Payment', 'Deposit', 'Prepayment', 'Over Credit', 'Payment Refund', 'Tax Credit', 'Tax Payment'))
																OR ([Group] IN ('Invoice')
																	AND Name IN ('Charge', 'Credit', 'Payment')))
					--INNER JOIN AccountingPeriod ap ON ap.StartDate <= t.TransactionDate AND ap.EndDate >= t.TransactionDate AND ap.AccountID = @accountID
					INNER JOIN #PropertiesAndDates #pad ON #pad.StartDate <= t.TransactionDate AND #pad.EndDate >= t.TransactionDate AND #pad.PropertyID = t.PropertyID
					INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND t.TransactionDate >= pap.StartDate AND t.TransactionDate <= pap.EndDate
					INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
					INNER JOIN Property p ON t.PropertyID = p.PropertyID
					INNER JOIN #Accounts ON #Accounts.GLAccountID = je.GLAccountID
					INNER JOIN #AccountingBooks #ab ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #ab.AccountingBookID
					--INNER JOIN #PropertyIDs ON #PropertyIDs.PropertyID = t.PropertyID	
				WHERE je.AccountID = @accountID			  
				  AND je.AccountingBasis = @accountingBasis			 
				  AND (je.GLAccountID IN (@accountsReceivableGLAccountID, @undepositedFundsGLAccountID, @prepaidIncomeGLAccountID, @accountsPayableGLAccountID))
				GROUP BY je.GLAccountID, p.PropertyID, p.Abbreviation, t.TransactionDate, ap.EndDate				


			--INSERT #TimeMe VALUES (@startTime, SYSDATETIME(), 'Slush Summary')
			--SET @startTime = SYSDATETIME()
		END
		
	--SELECT *, datediff(millisecond, starttime, endtime) FROM #TimeMe  order by StartTime

		IF (@alternateChartOfAccountsID IS NULL)
		BEGIN
			SELECT	r.JournalEntryID,
					r.PropertyID,
					r.PropertyAbbreviation,
					r.[Date],
					r.ObjectID,
					r.ObjectType,
					r.ObjectName,
					r.TransactionObjectID,
					r.TransactionObjectType,
					r.Reference,
					r.[Description],
					r.Amount,
					r.[TimeStamp],				
					r.GLAccountID AS 'GLAccountID',
					r.Summary,
					--ap.EndDate AS 'AccountingPeriodEndDate',
					ap.EndDate AS 'AccountingPeriodEndDate',
					r.Origin,
					r.AltObjectID
				FROM #Register r
					--INNER JOIN AccountingPeriod ap ON ap.StartDate <= r.[Date] AND ap.EndDate >= r.[Date] 
					INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate <= r.[Date] AND pap.EndDate >= r.[Date] AND pap.PropertyID = r.PropertyID
					INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
				WHERE pap.AccountID = @accountID
				ORDER BY r.[Date], r.[TimeStamp], r.ObjectType, r.TransactionObjectType 
		END 
		ELSE
		BEGIN
			SELECT	r.JournalEntryID,
					r.PropertyID,
					r.PropertyAbbreviation,
					r.[Date],
					r.ObjectID,
					r.ObjectType,
					r.ObjectName,
					r.TransactionObjectID,
					r.TransactionObjectType,
					r.Reference,
					r.[Description],
					r.Amount,
					r.[TimeStamp],				
					altGLA.AlternateGLAccountID AS 'GLAccountID',
					r.Summary,
					--ap.EndDate AS 'AccountingPeriodEndDate',
					ap.EndDate AS 'AccountingPeriodEndDate',
					r.Origin,
					r.AltObjectID
				FROM #Register r
					--INNER JOIN AccountingPeriod ap ON ap.StartDate <= r.[Date] AND ap.EndDate >= r.[Date] 
					INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate <= r.[Date] AND pap.EndDate >= r.[Date] AND pap.PropertyID = r.PropertyID
					INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
					INNER JOIN GLAccountAlternateGLAccount altGLA ON r.GLAccountID = altGLA.GLAccountID
					INNER JOIN AlternateGLAccount alt ON alt.AlternateGLAccountID = altGLA.AlternateGLAccountID AND alt.AlternateChartOfAccountsID = @alternateChartOfAccountsID
				WHERE pap.AccountID = @accountID				  
				ORDER BY r.[Date], r.[TimeStamp], r.ObjectType, r.TransactionObjectType 
		END
		

	END			
	
END





GO
