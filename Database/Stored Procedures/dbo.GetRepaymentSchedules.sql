SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Thomas Hutchins
-- Create date: March 1, 2017
-- =============================================
CREATE PROCEDURE [dbo].[GetRepaymentSchedules] 
	-- Add the parameters for the stored procedure here
	@accountID BIGINT = null,
	@repaymentAgreementIDs GuidCollection READONLY
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
		CREATE TABLE #Schedule (
		RepaymentAgreementScheduleID UNIQUEIDENTIFIER not null,
		AccountID BIGINT not null,
		RepaymentAgreementID UNIQUEIDENTIFIER not null,
        DueDate DATE not null,
        Amount INT not null, 
		RepaymentAgreementChargeTransactionID UNIQUEIDENTIFIER null,
        PaymentMade MONEY null,
        AmountRetained MONEY null,
		OwnerAgentView bit not null,
		Locked BIT not null,
		ActualPayDate DATE null,
		)
		
	INSERT INTO #Schedule
		SELECT	
		ras.RepaymentAgreementScheduleID,
		ras.AccountID,
		ras.RepaymentAgreementID,
        ras.DueDate,
        ras.Amount, 
		ras.RepaymentAgreementChargeTransactionID,
		ras.PaymentMade,
		NULL AS 'AmountRetained',
		CASE 
			WHEN (r.AgreementType = 'Owner/Agent') THEN CAST(1 as bit)
			ELSE CAST(0 AS bit) END AS 'OwnerAgentView',
		CASE 
			WHEN (ras.RepaymentAgreementChargeTransactionID IS NULL) THEN CAST(0 as bit)
			ELSE CAST(1 AS bit) END AS 'Locked',
		
		ISNULL(ras.ActualPayDate, NULL) AS ActualPayDate
		
			FROM RepaymentAgreementSchedule ras		
					LEFT JOIN RepaymentAgreement r on ras.RepaymentAgreementID = r.RepaymentAgreementID
			WHERE ras.AccountID = @accountID 
					AND ras.RepaymentAgreementID in (SELECT * FROM @repaymentAgreementIDs)
						
					UPDATE #sch SET PaymentMade = ISNULL((select #sch.PaymentMade), ISNULL((SELECT SUM(ta.Amount) FROM [Transaction] ts 
								LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = ts.TransactionID
								LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = ts.TransactionID
								LEFT JOIN [TransactionType] tt ON ta.TransactionTypeID = tt.TransactionTypeID
								LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
								WHERE ts.TransactionID = #sch.RepaymentAgreementChargeTransactionID
									AND tr.TransactionID IS NULL
									AND tar.TransactionID IS NULL
									AND tt.Name  = 'Payment'), null))
					FROM #Schedule #sch

					UPDATE #sch SET ActualPayDate = ISNULL((select #sch.ActualPayDate), ISNULL((SELECT top 1 ta.TransactionDate FROM [Transaction] ts 
								LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = ts.TransactionID
								LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = ts.TransactionID
								LEFT JOIN [TransactionType] tt ON ta.TransactionTypeID = tt.TransactionTypeID
								LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
								WHERE ts.TransactionID = #sch.RepaymentAgreementChargeTransactionID
									AND tr.TransactionID IS NULL
									AND tar.TransactionID IS NULL
									AND tt.Name  = 'Payment'
								ORDER BY ta.TransactionDate desc), null))
					FROM #Schedule #sch

					UPDATE #sch SET AmountRetained = ISNULL((SELECT SUM(ta.Amount) FROM #Schedule ras
								LEFT JOIN[Transaction] ts  ON ras.RepaymentAgreementChargeTransactionID = ts.TransactionID
								LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = ts.TransactionID
								LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = ts.TransactionID
								LEFT JOIN [TransactionType] tt ON ta.TransactionTypeID = tt.TransactionTypeID
								LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
								WHERE ts.TransactionID = #sch.RepaymentAgreementChargeTransactionID
									AND tr.TransactionID IS NULL
									AND tar.TransactionID IS NULL
									AND tt.Name = 'Credit'), null)
					FROM #Schedule #sch
		

		SELECT DISTINCT * FROM #Schedule
END
GO
