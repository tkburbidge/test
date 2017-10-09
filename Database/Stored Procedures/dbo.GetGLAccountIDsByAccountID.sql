SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetGLAccountIDsByAccountID] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT
		ttar.GLAccountID AS 'AccountsReceivableGLAccountID',
		ttap.GLAccountID AS 'AccountsPayableGLAccountID',
		ttppi.GLAccountID AS 'PrepaidIncomeGLAccountID',
		s.DepositAccountsPayableGLAccountID,
		ttudf.GLAccountID AS 'UndepositedFundsGLAccountID',
		s.GrossPotentialRentGLAccountID,
		s.DelinquentRentGLAccountID,
		s.ManagementFeesGLAccountID,
		s.RetainedEarningsGLAccountID,
		ttsdi.GLAccountID AS 'SecurityDepositInterestLiabilityGLAccountID',
		s.SecurityDepositInterestExpenseGLAccountID AS 'SecurityDepositInterestExpenseGLAccountID',
		s.LossToLeaseGLAccountID,
		s.GainToLeaseGLAccountID,
		s.PriorMonthCollectionsGLAccountID,
		s.PaymentProcessorFeesGLAccountID,
		s.ManagementFeesIncomeGLAccountID,
		s.UtilityReimbursementsGLAccountID
	FROM Settings s
		INNER JOIN TransactionType ttar ON s.AccountID = ttar.AccountID AND ttar.Name = 'Charge' AND ttar.[Group] = 'Lease'
		INNER JOIN TransactionType ttap ON s.AccountID = ttap.AccountID AND ttap.Name = 'Payment' AND ttap.[Group] = 'Invoice'
		INNER JOIN TransactionType ttppi ON s.AccountID = ttppi.AccountID AND ttppi.Name = 'Prepayment' AND ttppi.[Group] = 'Lease'
		INNER JOIN TransactionType ttudf ON s.AccountID = ttudf.AccountID AND ttudf.Name = 'Deposit' AND ttudf.[Group] = 'Bank'
		INNER JOIN TransactionType ttsdi ON s.AccountID = ttsdi.AccountID AND ttsdi.Name = 'Deposit Interest Payment' AND ttsdi.[Group] = 'Lease'
	WHERE s.AccountID = @accountID
END
GO
