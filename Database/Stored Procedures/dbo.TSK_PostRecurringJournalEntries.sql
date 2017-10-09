SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
				 
  

																													 
				 
  

						
  





-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 27, 2013
-- Description:	Adds recurring Journal Entries from the Journal Entry template tables.
-- =============================================
CREATE PROCEDURE [dbo].[TSK_PostRecurringJournalEntries]	
	@accountID bigint = null,
	@itemType nvarchar(50) = null,
	@date date,
	@recurringItemIDs GuidCollection READONLY,
	@postingPersonID UNIQUEIDENTIFIER = null
AS


DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @jeCtr int
DECLARE @maxjeCtr int
DECLARE @recurringItemID uniqueidentifier
DECLARE @journalEntryTemplateID uniqueidentifier
DECLARE @manualTransactionTypeID uniqueidentifier
DECLARE @cashTransactionTypeID uniqueidentifier
DECLARE @manualGLAccountID uniqueidentifier
DECLARE @cashGLAccountID uniqueidentifier
DECLARE @bankTransactionCategoryID uniqueidentifier
DECLARE @newTransactionID uniqueidentifier
DECLARE @newTransactionGroupID uniqueidentifier
DECLARE @personID uniqueidentifier
DECLARE @bankAccountID uniqueidentifier
DECLARE @basis nvarchar(10)
DECLARE @journalEntryAccountID bigint
DECLARE @recurringItemName nvarchar(600)
DECLARE @assignedToPersonID uniqueidentifier
DECLARE @newAlertTaskID uniqueidentifier
DECLARE @accountingBookID uniqueidentifier
DECLARE @approvalStatus nvarchar(50)
DECLARE @onlyApprovedJournalEntriesReporting bit
DECLARE @jeAccountingBookID uniqueidentifier

BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #RecurringItems (
		Sequence	int identity not null,
		RecurringItemID uniqueidentifier not null,
		AccountID bigint not null,
		PersonID uniqueidentifier not null,
		Name nvarchar(500) null,
		AssignedToPersonID uniqueidentifier not null)
		
	CREATE TABLE #JournalEntriesByTemplate (
		Sequence	int identity not null,
		JournalEntryTemplateID uniqueidentifier not null,
		AccountingBasis nvarchar(10) not null,
		BankAccountID uniqueidentifier null,
		PropertyID uniqueidentifier not null,
		AccountingBookID uniqueidentifier null)
		
	CREATE TABLE #PropertyBankAccounts (
	    PropertyID uniqueidentifier,
		BankAccountID uniqueidentifier,
		GLAccountID uniqueidentifier
	)			
	
	-- If we don't have a set of RecurringItems to post, get all 
	-- RecurringItems for the date.  Otherwise just do the ones
	-- for the passed in IDs		
	IF (0 = (SELECT COUNT(*) FROM @recurringItemIDs))
	BEGIN
		INSERT INTO #RecurringItems EXEC GetRecurringItemsByType @accountID, @itemType, @date
	END
	ELSE
	BEGIN
		INSERT INTO #RecurringItems 
			SELECT RecurringItemID, AccountID, PersonID, Name, AssignedToPersonID
				FROM RecurringItem
				WHERE RecurringItemID IN (SELECT Value FROM @recurringItemIDs)
	END
	
	SET @maxCtr = (SELECT MAX(Sequence) FROM #RecurringItems)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		
		SELECT  @recurringItemID = #ri.RecurringItemID, @accountID = #ri.AccountID, @personID = #ri.PersonID, @recurringItemName = #ri.Name, 
				@assignedToPersonID = #ri.AssignedToPersonID
			FROM #RecurringItems #ri
				INNER JOIN JournalEntryTemplate jet ON #ri.RecurringItemID = jet.RecurringItemID
			WHERE Sequence = @ctr
			
		SET @onlyApprovedJournalEntriesReporting = (SELECT OnlyShowApprovedJournalEntriesFinancialReporting FROM Settings where AccountID = @accountID)
		
		-- Get the needed Transaction Catgory IDs
		SELECT @manualGLAccountID = GLAccountID, @manualTransactionTypeID = TransactionTypeID
			FROM TransactionType
			WHERE Name = 'Manual' AND [Group] = 'Journal Entry' AND AccountID = @accountID
		SELECT @cashGLAccountID = GLAccountID, @cashTransactionTypeID = TransactionTypeID
			FROM TransactionType
			WHERE Name = 'Cash' AND [Group] = 'Journal Entry' AND AccountID = @accountID
		SELECT @bankTransactionCategoryID = BankTransactionCategoryID
			FROM BankTransactionCategory 	
			WHERE AccountID = @accountID
			  AND Category = 'Cash Journal Entry'
		  
		TRUNCATE TABLE #PropertyBankAccounts
		TRUNCATE TABLE #JournalEntriesByTemplate

		-- Get the bank GL AccountIDs for the properties associated with the template		  
		INSERT #PropertyBankAccounts 
			SELECT DISTINCT bap.PropertyID, ba.BankAccountID, ba.GLAccountID
				FROM BankAccount ba
					INNER JOIN BankAccountProperty bap ON ba.BankAccountID = bap.BankAccountID AND bap.AccountID = @accountID
					INNER JOIN JournalEntryTemplate jet ON jet.RecurringItemID = @recurringItemID AND bap.PropertyID = jet.PropertyID

		INSERT #JournalEntriesByTemplate
			SELECT JournalEntryTemplateID, 
				   AccountingBasis,
				   #PropertyBankAccounts.BankAccountID,
				   JournalEntryTemplate.PropertyID,
				   tgpt.AccountingBookID
				FROM JournalEntryTemplate
				INNER JOIN TransactionGroupParentTemplate tgpt ON tgpt.RecurringItemID = JournalEntryTemplate.RecurringItemID
				LEFT JOIN #PropertyBankAccounts ON #PropertyBankAccounts.GLAccountID = JournalEntryTemplate.GLAccountID AND #PropertyBankAccounts.PropertyID = JournalEntryTemplate.PropertyID
				WHERE JournalEntryTemplate.RecurringItemID = @recurringItemID
				ORDER BY OrderBy
				
		SET @jeCtr = 1
		SET @maxjeCtr = (SELECT MAX(Sequence) FROM #JournalEntriesByTemplate)
		SET @newTransactionGroupID = NEWID()	

		WHILE (@jeCtr <= @maxjeCtr)
		BEGIN
			SELECT @journalEntryTemplateID = JournalEntryTemplateID, @bankAccountID = BankAccountID, @basis = AccountingBasis, @accountingBookID = AccountingBookID
				FROM #JournalEntriesByTemplate
				WHERE Sequence = @jeCtr
				
			IF (@onlyApprovedJournalEntriesReporting = 1)
			BEGIN
				SET @jeAccountingBookID = '88888888-8888-8888-8888-888888888888'
				SET @approvalStatus = 'PendingApproval'
			END
			ELSE
			BEGIN
				SET @jeAccountingBookID = @accountingBookID
				SET @approvalStatus = null
			END

			-- Add a new Transaction				
			SET @newTransactionID = NEWID()
			INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, AppliesToTransactionID, ReversesTransactionID, PropertyID, PersonID, TaxRateGroupID, NotVisible, Origin, Amount, [Description], Note, TransactionDate, [TimeStamp], IsDeleted, PostingBatchID)
				SELECT @newTransactionID, AccountID, 
						-- ObjectID set to BankAccountID if this is a bank journal entry
						-- Otherwise set to the PropertyID
						CASE WHEN (@bankAccountID IS NOT NULL) THEN @bankAccountID ELSE PropertyID END,
						CASE WHEN (@bankAccountID IS NOT NULL) THEN @cashTransactionTypeID ELSE @manualTransactionTypeID END,
						null, null, null, PropertyID, Coalesce(@postingPersonID, @personID), null, 0, 'R', Amount, [Description], null, @date, DATEADD(s, @jeCtr, GETDATE()), 0, null
					FROM JournalEntryTemplate 
					WHERE JournalEntryTemplateID = @journalEntryTemplateID
			
			-- Add the journal entries					
			IF (@basis IN ('Cash', 'Both'))
			BEGIN
				INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, [TransactionID], Amount, AccountingBasis, AccountingBookID)
					SELECT NEWID(), AccountID, GLAccountID, @newTransactionID, Amount, 'Cash', @jeAccountingBookID
						FROM JournalEntryTemplate
						WHERE JournalEntryTemplateID = @journalEntryTemplateID
			END
			IF (@basis IN ('Accrual', 'Both'))
			BEGIN
				INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, [TransactionID], Amount, AccountingBasis, AccountingBookID)
					SELECT NEWID(), AccountID, GLAccountID, @newTransactionID, Amount, 'Accrual', @jeAccountingBookID
						FROM JournalEntryTemplate
						WHERE JournalEntryTemplateID = @journalEntryTemplateID
			END
			
			-- Add a BankTransaction if needed
			IF (@bankAccountID IS NOT NULL)
			BEGIN
				INSERT BankTransaction (BankTransactionID, AccountID, BankTransactionCategoryID, ObjectID, ObjectType, QueuedForPrinting)
					VALUES (NEWID(), @accountID, @bankTransactionCategoryID, @newTransactionID, 'Transaction', 0)
			END			
			
			-- Add a TransactionGroup entry
			INSERT TransactionGroup VALUES (@newTransactionGroupID, @accountID, @newTransactionID)
						
			SET @jeCtr = @jeCtr + 1
		END
		
		-- Add a TransactionGroupParent record for every property grouping of journal entries we just posted
		-- Scenario
		-- PROP1		1120 - Cash									1000
		-- PROP1		6701 - Expense						1000
		-- PROP2		1120 - Cash									2000
		-- PROP2		6701 - Expense						2000

		-- This needs to add two TransactionGroupParent records, one for PROP1 ($1000) and one for PROP2 ($2000)
		INSERT INTO TransactionGroupParent ( TransactionGroupParentID, AccountID, TransactionGroupID, PropertyID, [Date], [Description], Amount, AccountingBasis, PersonID, ReversedByTransactionGroupID, ReversesTransactionGroupID, AccountingBookID, ApprovalStatus )
			SELECT DISTINCT
				NEWID(),
				@accountID,
				@newTransactionGroupID,
				jet.PropertyID,
				@date,
				tgpt.[Description],
				SUM(jet.Amount), -- This gives us the total of the JE
				jet.AccountingBasis,
				COALESCE(@postingPersonID, @personID) ,-- For PersonID
				null,
				null,
				@accountingBookID,
				@approvalStatus
			FROM JournalEntryTemplate jet
				INNER JOIN TransactionGroupParentTemplate tgpt ON tgpt.RecurringItemID = jet.RecurringItemID
			WHERE jet.Amount > 0
				AND jet.RecurringItemID = @recurringItemID
			GROUP BY jet.PropertyID, jet.AccountingBasis, tgpt.[Description]
		
		IF (@postingPersonID is null)
		BEGIN
			update dbo.RecurringItem SET LastRecurringPostDate = @date
			where RecurringItemID = @recurringItemID
		END
		ELSE
		BEGIN
			update dbo.RecurringItem
			SET LastManualPostDate = @date, LastManualPostPersonID = @postingPersonID
			where RecurringItemID = @recurringItemID
		END	
		
		-- Add a task for the user to update the needed values
		SET @newAlertTaskID = NEWID()
		INSERT INTO AlertTask (AlertTaskID, AccountID, AssignedByPersonID, ObjectID, ObjectType, [Type], Importance, DateAssigned, DateDue, DateMarkedRead, NotifiedViaEmail, [Subject], TaskStatus)
			VALUES (@newAlertTaskID, @accountID, Coalesce(@postingPersonID, @personID), @newTransactionGroupID, 'Journal Entry', null, 'High', @date, @date, null, 0, 'Update Recurring Journal Entry: ' + @recurringItemName, 'Not Started')
					
		INSERT INTO TaskAssignment (TaskAssignmentID, AccountID, AlertTaskID, PersonID, DateMarkedRead, IsCarbonCopy)
			VALUES (NEWID(), @accountID, @newAlertTaskID, @assignedToPersonID, NULL, 0)

		SET @ctr = @ctr + 1
	END
		
END





GO
