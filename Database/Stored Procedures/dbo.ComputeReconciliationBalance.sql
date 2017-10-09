SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 3, 2012
-- Description:	Computes the new reconciliation balance
-- =============================================
CREATE PROCEDURE [dbo].[ComputeReconciliationBalance] 
	-- Add the parameters for the stored procedure here
	@bankAccountID uniqueidentifier = null,
	@bankAccountReconciliationID uniqueidentifier = null
	
AS

DECLARE @OldEndingBalance money
DECLARE @OldDifference money
DECLARE @ReconciledDeposits money
DECLARE @ReconciledPayments money

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @OldEndingBalance = (SELECT TOP 1 EndingBalance FROM BankAccountReconciliation
								WHERE BankAccountID = @bankAccountID AND DateCompleted IS NOT NULL
								ORDER BY DateCompleted DESC)
	SET @OldDifference = (SELECT TOP 1 BankAccountReconciliation.[Difference] FROM BankAccountReconciliation
								WHERE BankAccountID = @bankAccountID AND DateCompleted IS NOT NULL
								ORDER BY DateCompleted DESC)
								
	SET @ReconciledDeposits = (SELECT SUM(ISNULL(p.Amount, 0))
									FROM BankTransaction bt
										INNER JOIN Payment p ON bt.ObjectID = p.PaymentID
									WHERE bt.BankReconciliationID = @bankAccountReconciliationID
									  AND bt.ObjectType = 'Payment')
									  
	SET @ReconciledPayments = (SELECT SUM(ISNULL(t.Amount, 0))
									FROM BankTransaction bt
										INNER JOIN [Transaction] t ON bt.ObjectID = t.TransactionID
									WHERE bt.BankReconciliationID = @bankAccountReconciliationID
									  AND bt.ObjectType = 'Transaction')
									
	RETURN (ISNULL(@OldEndingBalance, 0) + ISNULL(@OldDifference, 0) + ISNULL(@ReconciledDeposits, 0) - ISNULL(@ReconciledPayments, 0))
	

END
GO
