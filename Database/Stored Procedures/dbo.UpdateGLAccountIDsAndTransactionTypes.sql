SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[UpdateGLAccountIDsAndTransactionTypes] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@accountsReceivableGLAccountID uniqueidentifier = null,
	@accountsPayableGLAccountID uniqueidentifier = null,
	@prepaidIncomeGLAccountID uniqueidentifier = null,
	@securityDepositGLAccountID uniqueidentifier = null,
	@undepositedFundsGLAccountID uniqueidentifier = null,
	@grossPotentialRentGLAccountID uniqueidentifier = null,
	@delinquentRentGLAccountID uniqueidentifier = null,
	@managementFeesGLAccountID uniqueidentifier = null,
	@retainedEarningsGLAccountID uniqueidentifier = null,
	@securityDepositInterestLiabilityGLAccountID uniqueidentifier = null,
	@securityDepositInterestExpenseGLAccountID uniqueidentifier = null,
	@priorMonthCollectionsGLAccountID uniqueidentifier = null,
	@paymentProcessorFeesGLAccountID uniqueidentifier = null,
	@lossToLeaseGLAccountID uniqueidentifier,
	@gainToLeaseGLAccountID uniqueidentifier,
	@managementFeesIncomeGLAccountID uniqueidentifier = null,
	@utilityReimbursementsGLAccountID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE TransactionType SET GLAccountID = @accountsReceivableGLAccountID
		WHERE Name IN  ('Charge', 'Tax Charge', 'Credit', 'Tax Credit', 'Over Credit', 'Payment', 'Tax Payment', 'Balance Transfer Payment', 'Balance Transfer Deposit',
						'Deposit Applied to Deposit', 'Deposit Applied to Balance', 'Deposit Refund', 'Payment Refund')
		  AND [Group] NOT IN ('Invoice')
		  AND AccountID = @accountID
		  
	UPDATE Settings SET AccountsReceivableGLAccountID = @accountsReceivableGLAccountID 
		WHERE AccountID = @accountID
						
	UPDATE TransactionType SET GLAccountID = @accountsPayableGLAccountID 
		WHERE Name IN ('Charge', 'Credit', 'Payment')
		  AND [Group] IN ('Invoice')
		  AND AccountID = @accountID
		  
	UPDATE Settings SET AccountsPayableGLAccountID = @accountsPayableGLAccountID
		WHERE AccountID = @accountID
		
	UPDATE TransactionType SET GLAccountID = @prepaidIncomeGLAccountID
		WHERE Name IN ('Prepayment')
		  AND AccountID = @accountID
		  
	UPDATE Settings SET PrepaidIncomeGLAccountID = @prepaidIncomeGLAccountID
		WHERE AccountID = @accountID
		  
	UPDATE Settings SET DepositAccountsPayableGLAccountID = @securityDepositGLAccountID
		WHERE AccountID = @accountID
		
	UPDATE TransactionType SET GLAccountID = @undepositedFundsGLAccountID
		WHERE AccountID = @accountID		
		  AND ([Group] IN ('Bank') OR [Name] = 'Deposit')

	UPDATE Settings SET GrossPotentialRentGLAccountID = @grossPotentialRentGLAccountID
		WHERE AccountID = @accountID

	UPDATE Settings SET DelinquentRentGLAccountID = @delinquentRentGLAccountID
		WHERE AccountID = @accountID

	UPDATE Settings SET ManagementFeesGLAccountID = @managementFeesGLAccountID
		WHERE AccountID = @accountID

	UPDATE Settings SET RetainedEarningsGLAccountID = @retainedEarningsGLAccountID
		WHERE AccountID = @accountID

	UPDATE TransactionType SET GLAccountID = ISNULL(@securityDepositInterestLiabilityGLAccountID , '00000000-0000-0000-0000-000000000000')
		WHERE Name = 'Deposit Interest Payment'		  
		  AND AccountID = @accountID

	UPDATE Settings SET SecurityDepositInterestExpenseGLAccountID = ISNULL(@securityDepositInterestExpenseGLAccountID, '00000000-0000-0000-0000-000000000000')
		WHERE AccountID = @accountID

	UPDATE LedgerItemType SET GLAccountID = ISNULL(@securityDepositInterestExpenseGLAccountID, '00000000-0000-0000-0000-000000000000')
		WHERE AccountID = @accountID
			AND IsDepositInterest = 1
			
	UPDATE Settings SET PriorMonthCollectionsGLAccountID = @priorMonthCollectionsGLAccountID
		WHERE AccountID = @accountID
			
	UPDATE Settings SET PaymentProcessorFeesGLAccountID = @paymentProcessorFeesGLAccountID
		WHERE AccountID = @accountID
			
	UPDATE Settings SET LossToLeaseGLAccountID = @lossToLeaseGLAccountID
		WHERE AccountID = @accountID
			
	UPDATE Settings SET GainToLeaseGLAccountID = @gainToLeaseGLAccountID
		WHERE AccountID = @accountID
		
	UPDATE Settings SET ManagementFeesIncomeGLAccountID = @managementFeesIncomeGLAccountID
		WHERE AccountID = @accountID

	UPDATE Settings SET UtilityReimbursementsGLAccountID = @utilityReimbursementsGLAccountID
		WHERE AccountID = @accountID
END
GO
