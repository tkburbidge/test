SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 12, 2012
-- Description:	Transfers balances from accounts to other accounts as in a year end situation
-- =============================================
CREATE PROCEDURE [dbo].[DistributeGLBalances] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@startAccountingPeriodID uniqueidentifier = null,
	@endAccountingPeriodID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@personID uniqueidentifier = null,
	@summaryGLAccountID uniqueidentifier = null,
	@date date = null,
	@description nvarchar(500) = null,
	@sourceGLAccountIDs GuidCollection READONLY,								-- IF EMPTY, grab Income Statement GLAccountIDs.
	@destinationGLAccounts AccountPercentCollection READONLY,
	@year int = 2013--,
	--@retainedEarningsID uniqueidentifier = null									-- IF NULL, create a new one.
AS
DECLARE @propertyIDs GuidCollection
DECLARE @newTransactionID uniqueidentifier
DECLARE @newDistTransactionID uniqueidentifier
DECLARE @cashTransactionGroupID uniqueidentifier 
DECLARE @accrualTransactionGroupID uniqueidentifier 
DECLARE @transactionTypeID uniqueidentifier
DECLARE @transactionGroupID uniqueidentifier
DECLARE @sumAmount money
DECLARE @ctr int
DECLARE @max int
DECLARE @thisAmount money
DECLARE @summingAmount money
DECLARE @accountingBasis nvarchar(10)
DECLARE @basisDone int
DECLARE @myGLAccountID GuidCollection
DECLARE @retainedEarningsIDs GuidCollection
DECLARE @existingTransactionGroupIDs GuidCollection
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF ((SELECT COUNT(*) FROM @sourceGLAccountIDs) = 0)
	BEGIN
		-- Get Profit and Loss GL Accounts
		INSERT INTO @myGLAccountID
			SELECT DISTINCT 
					gl.GLAccountID AS 'Value'
			FROM GLAccount gl
			WHERE gl.AccountID = @accountID
				AND gl.GLAccountType IN (
					'Income',
					'Expense',
					'Other Income',
					'Other Expense',
					'Non-Operating Expense'
				)
	END
	ELSE
	BEGIN
		INSERT INTO @myGLAccountID
			SELECT Value FROM @sourceGLAccountIDs
	END
	
	CREATE TABLE #AccountingBookIDs ( ID int IDENTITY, AccountingBookID uniqueidentifier null )
	INSERT INTO #AccountingBookIDs VALUES (NULL)
	INSERT INTO #AccountingBookIDs SELECT AccountingBookID FROM AccountingBook WHERE AccountID = @accountID

	CREATE TABLE #IncomeStatement (
		GLAccountID uniqueidentifier not null,		
		YTDAmount money null,
		TransactionID uniqueidentifier)		
		
	CREATE TABLE #Distributions (
		Sequence INT IDENTITY,
		GLAccount uniqueidentifier not null,
		[Percent] decimal(9, 4) not null)	
		
	CREATE TABLE #DistributionTransactionIDs (
		TransactionID uniqueidentifier not null)
		
	INSERT INTO #Distributions
		SELECT * FROM @destinationGLAccounts ORDER BY [Percent]	
	
	DECLARE @counter int = 1

	WHILE (@counter <= (SELECT MAX(ID) FROM #AccountingBookIDs))
	BEGIN
		DECLARE @accountingBookID uniqueidentifier = (SELECT AccountingBookID FROM #AccountingBookIDs WHERE ID = @counter)

		INSERT INTO @retainedEarningsIDs
		SELECT RetainedEarningsID 
			FROM RetainedEarnings 
			WHERE AccountID = @accountID 
				AND PropertyID = @propertyID
				AND [Year] = @year
				AND ((@accountingBookID IS NULL AND AccountingBookID IS NULL)
					 OR (@accountingBookID = AccountingBookID))

		--IF (@retainedEarningsID IS NULL)
		--BEGIN
			-- Create new IDs for the TransactionGroups
			SET @cashTransactionGroupID = NEWID()
			SET @accrualTransactionGroupID = NEWID()
		--END
		--ELSE
		--BEGIN
		--	-- Get the existing IDs for the previously run Retained Earnings entry
		--	SELECT @cashTransactionGroupID = CashTransactionGroupID, @accrualTransactionGroupID = AccrualTransactionGroupID	
		--	FROM RetainedEarnings 
		--	WHERE RetainedEarningsID = @retainedEarningsID
		--END
								
		SELECT @transactionTypeID = TransactionTypeID FROM TransactionType WHERE Name = 'Distribution' AND [Group] = 'Journal Entry' AND AccountID = @accountID
	
		SET @max = (SELECT MAX(Sequence) FROM #Distributions)
	
		SET @accountingBasis = 'Cash'
		SET @basisDone = 0
		DECLARE @entriesPosted bit = 0
				
			
		WHILE (@basisDone < 2)
		BEGIN			
		-- Add empty entries for the source accounts
			INSERT INTO #IncomeStatement
				SELECT Value AS 'GLAccountID',  0.0 AS 'YTDAmount', NEWID() FROM @myGLAccountID 															  	
	
			UPDATE #IncomeStatement SET YTDAmount = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID AND t.PropertyID = @propertyID														
															INNER JOIN PropertyAccountingPeriod papb ON papb.AccountingPeriodID = @startAccountingPeriodID AND papb.PropertyID = @propertyID
															INNER JOIN PropertyAccountingPeriod pape ON pape.AccountingPeriodID = @endAccountingPeriodID AND pape.PropertyID = @propertyID																											
														WHERE t.TransactionDate >= papb.StartDate
														  AND t.TransactionDate <= pape.EndDate
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBasis = @accountingBasis														  
														  AND je.GLAccountID = #IncomeStatement.GLAccountID
														  AND ((je.AccountingBookID IS NULL AND @accountingBookID IS NULL)
															   OR (je.AccountingBookID = @accountingBookID)))
		
			-- Subtract out already posted retained earnins entries from the calculated income and expense amounts
			IF (@accountingBasis = 'Cash')
			BEGIN			
				SET @transactionGroupID = @cashTransactionGroupID
			
				INSERT INTO @existingTransactionGroupIDs
					SELECT CashTransactionGroupID
					FROM RetainedEarnings
					WHERE RetainedEarningsID IN (SELECT Value FROM @retainedEarningsIDs)
			END
			ELSE
			BEGIN
				SET @transactionGroupID = @accrualTransactionGroupID
			
				INSERT INTO @existingTransactionGroupIDs
					SELECT AccrualTransactionGroupID
					FROM RetainedEarnings
					WHERE RetainedEarningsID IN (SELECT Value FROM @retainedEarningsIDs)
			END

			UPDATE #IncomeStatement SET YTDAmount = ISNULL(YTDAmount, 0) + ISNULL((SELECT SUM(je.Amount)
																				   FROM JournalEntry je
																					   INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																				   WHERE t.TransactionID IN (SELECT TransactionID 
																												FROM TransactionGroup
																												WHERE TransactionGroupID IN (SELECT Value FROM @existingTransactionGroupIDs))																						
																						AND je.GLAccountID = #IncomeStatement.GLAccountID
																						AND ((je.AccountingBookID IS NULL AND @accountingBookID IS NULL)
																								OR (je.AccountingBookID = @accountingBookID))), 0)
	
			-- If any entries need to be made
			IF (EXISTS(SELECT * FROM #IncomeStatement WHERE YTDAmount <> 0))
			BEGIN
				SET @entriesPosted = 1

				-- Add the zeroing entries							
				-- This statement should zero out every entry in the Income Statement.  The sum of all entries should work as the difference between Income & Expenses.
				INSERT [Transaction] (TransactionID, TransactionTypeID, Amount, [Description], AccountID, ObjectID, PropertyID, PersonID, NotVisible, Origin, TransactionDate, IsDeleted, [TimeStamp])
					SELECT TransactionID, @transactionTypeID, -YTDAmount, @description, @accountID, @propertyID, @propertyID, @personID, 0, 'Y', @date, 0, GETDATE() 
					FROM #IncomeStatement
					WHERE YTDAmount IS NOT NULL
						AND YTDAmount <> 0														  
		
				INSERT INTO JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis, AccountingBookID)
					SELECT NEWID(), @accountID, GLAccountID, TransactionID, -YTDAmount, @accountingBasis, @accountingBookID
						FROM #IncomeStatement 					
						WHERE YTDAmount IS NOT NULL
						  AND YTDAmount <> 0.0				  
		
				INSERT #DistributionTransactionIDs 
					SELECT TransactionID 
					FROM #IncomeStatement
					WHERE YTDAmount IS NOT NULL
						AND YTDAmount <> 0		
				  
				SELECT @sumAmount = SUM(YTDAmount) FROM #IncomeStatement
				
				--IF (@summaryGLAccountID IS NOT NULL)
				--BEGIN
				--	INSERT JournalEntry VALUES (NEWID(), @accountID, @summaryGLAccountID, @newTransactionID, @sumAmount, @accountingBasis)
				--	INSERT JournalEntry VALUES (NEWID(), @accountID, @summaryGLAccountID, @newTransactionID, -1 * @sumAmount, @accountingBasis)
				--END
		
				SET @summingAmount = 0
				SET @ctr = 1
			
		
				-- Post Equity Entries (not sure on sign, these are debit entries as is)
				WHILE (@ctr <= @max)
				BEGIN
			
					SET @thisAmount = (SELECT ROUND(@sumAmount * ([Percent] / 100.0), 2) FROM #Distributions WHERE Sequence = @ctr)
					SET @summingAmount = @summingAmount + @thisAmount
			
					-- Last one, make sure the math works out right down to the penny.
					IF (@ctr = @max)
					BEGIN	
						SET @thisAmount = @thisAmount + (@sumAmount - @summingAmount)
					END
								
					IF (@thisAmount IS NOT NULL AND @thisAmount <> 0)
					BEGIN
						-- Add the distribution entry
						SET @newDistTransactionID = NEWID()
				
						INSERT #DistributionTransactionIDs VALUES (@newDistTransactionID)
							
						INSERT [Transaction] (TransactionID, TransactionTypeID, Amount, [Description], AccountID, ObjectID, PropertyID, PersonID, NotVisible, Origin, TransactionDate, IsDeleted, [TimeStamp])
							VALUES (@newDistTransactionID, @transactionTypeID, @thisAmount, @description, @accountID, @propertyID, @propertyID, @personID, 0, 'E', @date, 0, GETDATE())
				
						INSERT INTO JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis, AccountingBookID)
							SELECT NEWID(), @accountID, GLAccount, @newDistTransactionID, @thisAmount, @accountingBasis, @accountingBookID
								FROM #Distributions 
								WHERE Sequence = @ctr						  					  
					END					  
			
					SET @ctr = @ctr + 1
				END
		
				IF (@accountingBasis = 'Cash')
			BEGIN						
				INSERT INTO TransactionGroup SELECT @cashTransactionGroupID, @accountID, TransactionID FROM #DistributionTransactionIDs

				INSERT INTO TransactionGroupParent (TransactionGroupParentID, AccountID, TransactionGroupID, PropertyID, [Date], [Description], Amount, AccountingBasis, PersonID, AccountingBookID)
					VALUES (NEWID(), @accountID, @cashTransactionGroupID, @propertyID, @date, @description, ABS(@sumAmount), @accountingBasis, @personID, @accountingBookID)
			END
			ELSE
			BEGIN			
				INSERT INTO TransactionGroup SELECT @accrualTransactionGroupID, @accountID, TransactionID FROM #DistributionTransactionIDs

				INSERT INTO TransactionGroupParent (TransactionGroupParentID, AccountID, TransactionGroupID, PropertyID, [Date], [Description], Amount, AccountingBasis, PersonID, AccountingBookID)
					VALUES (NEWID(), @accountID, @accrualTransactionGroupID, @propertyID, @date, @description, ABS(@sumAmount), @accountingBasis, @personID, @accountingBookID)
			END
		


			END
			SET @basisDone = @basisDone + 1
			SET @accountingBasis = 'Accrual'
			TRUNCATE TABLE #IncomeStatement
			TRUNCATE TABLE #DistributionTransactionIDs
			DELETE FROM @existingTransactionGroupIDs
		END


		IF (@entriesPosted = 1)
		BEGIN
			INSERT RetainedEarnings (RetainedEarningsID, AccountID, PropertyID, [Year], CashTransactionGroupID, AccrualTransactionGroupID, IsComplete, DateCreated, PostingPersonID, AccountingBookID) 
				VALUES (NEWID(), @accountID, @propertyID, @year, @cashTransactionGroupID, @accrualTransactionGroupID, CAST(1 AS bit), getdate(), @personID, @accountingBookID)
		END

		SET @counter = @counter + 1

	END
END
GO
