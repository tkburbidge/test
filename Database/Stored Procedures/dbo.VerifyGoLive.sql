SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 2017-10-04
-- Description:	Check that all necessary "Go Live" actions have been completed for an account
-- =============================================
CREATE PROCEDURE [dbo].[VerifyGoLive] 
	-- Add the parameters for the stored procedure here
	@accountID bigint
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #GoLiveChecks (
		[Name] nvarchar(MAX) not null,
		[Passed] bit not null
	)



	INSERT INTO #GoLiveChecks VALUES (
		'GL Accounts Imported',
		CASE WHEN (EXISTS (SELECT TOP 1 1 FROM GLAccount WHERE AccountID = @accountID)) THEN 1 ELSE 0 END
	)




	INSERT INTO #GoLiveChecks VALUES (
		'Transaction Categories Imported',
		CASE WHEN (EXISTS (SELECT TOP 1 1 FROM LedgerItemType WHERE AccountID = @accountID)) THEN 1 ELSE 0 END
	)




	CREATE TABLE #DefaultGLAccounts (
		AccountsReceivableGLAccountID uniqueidentifier not null,
		AccountsPayableGLAccountID uniqueidentifier not null,
		PrepaidIncomeGLAccountID uniqueidentifier not null,
		DepositAccountsPayableGLAccountID uniqueidentifier not null,
		UndepositedFundsGLAccountID uniqueidentifier not null,
		GrossPotentialRentGLAccountID uniqueidentifier not null,
		DelinquentRentGLAccountID uniqueidentifier null,
		ManagementFeesGLAccountID uniqueidentifier null,
		RetainedEarningsGLAccountID uniqueidentifier null,
		SecurityDepositInterestLiabilityGLAccountID uniqueidentifier not null,
		SecurityDepositInterestExpenseGLAccountID uniqueidentifier null,
		LossToLeaseGLAccountID uniqueidentifier not null,
		GainToLeaseGLAccountID uniqueidentifier not null,
		PriorMonthCollectionsGLAccountID uniqueidentifier null,
		PaymentProcessorFeesGLAccountID uniqueidentifier not null,
		ManagementFeesIncomeGLAccountID uniqueidentifier null,
		UtilityReimbursementsGLAccountID uniqueidentifier null,
	)

	INSERT INTO #DefaultGLAccounts EXEC GetGLAccountIDsByAccountID @accountID

	DECLARE @emptyGuid uniqueidentifier = '00000000-0000-0000-0000-000000000000'
	INSERT INTO #GoLiveChecks VALUES (
		'Default GL Accounts Selected',
		CASE WHEN (EXISTS (SELECT TOP 1 1 
								FROM #DefaultGLAccounts 
								WHERE AccountsReceivableGLAccountID <> @emptyGuid
								  AND AccountsPayableGLAccountID <> @emptyGuid
								  AND PrepaidIncomeGLAccountID <> @emptyGuid
								  AND DepositAccountsPayableGLAccountID <> @emptyGuid
								  AND UndepositedFundsGLAccountID <> @emptyGuid
								  AND GrossPotentialRentGLAccountID <> @emptyGuid
								  AND PaymentProcessorFeesGLAccountID <> @emptyGuid
								  AND LossToLeaseGLAccountID <> @emptyGuid
								  AND GainToLeaseGLAccountID <> @emptyGuid
							)
					) 
			THEN 1 ELSE 0 END
	)



	
	INSERT INTO #GoLiveChecks VALUES (
		'Default Transaction Categories Selected',
		CASE WHEN (EXISTS (SELECT TOP 1 1 
								FROM Settings 
								WHERE AccountID = @accountID 
								  AND LateFeeLedgerItemTypeID <> @emptyGuid
								  AND MonthToMonthFeeLedgerItemTypeID <> @emptyGuid
								  AND NSFChargeLedgerItemTypeID <> @emptyGuid
								  AND DefaultPortalPaymentLedgerItemTypeID <> @emptyGuid
								  AND DefaultPortalDepositLedgerItemTypeID <> @emptyGuid
							)
					) 
			THEN 1 ELSE 0 END
	)


	
	INSERT INTO #GoLiveChecks VALUES (
		'Unit Statuses Selected',
		CASE WHEN ((SELECT COUNT(1) 
								FROM UnitStatus 
								WHERE AccountID = @accountID
								  AND StatusLedgerItemTypeID <> @emptyGuid
					) = 6) 
			THEN 1 ELSE 0 END
	)



    -- Insert statements for procedure here
	SELECT * FROM #GoLiveChecks
END
GO
