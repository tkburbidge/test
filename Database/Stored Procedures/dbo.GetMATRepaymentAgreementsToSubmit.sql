SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Tony Morgan
-- Create date: 3/2/2017
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[GetMATRepaymentAgreementsToSubmit] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@affordableSubmissionID uniqueidentifier,
	@propertyID uniqueidentifier,
	@voucherLock bit
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #RepaymentSchedulesPayments
	(
		RepaymentAgreementScheduleID uniqueidentifier not null,
		AccountID bigint not null,
		RepaymentAgreementID uniqueidentifier not null,
        DueDate date not null,
        Amount int not null, 
		RepaymentAgreementChargeTransactionID uniqueidentifier null,
        PaymentMade money null,
        AmountRetained money null,
		OwnerAgentView bit not null,
		Locked bit not null,
		ActualPayDate date null
	)

	CREATE TABLE #RepaymentPaymentsSum
	(
		RepaymentAgreementID uniqueidentifier not null,
		PaymentMade money null,
		AmountRetained money null
	)

	DECLARE @repaymentAgreementIDs GuidCollection

	IF(@voucherLock = 1)
	BEGIN
		SELECT
			ra.RepaymentAgreementID,
			'R' as 'RecordType',
			p.FirstName,
			p.LastName,
			ISNULL(u.HudUnitNumber, u.Number) as UnitNumber,
			ra.AgreementID,
			ra.AgreementStartDate,
			ra.AgreementEndDate,
			ra.AgreementType as 'TransactionType',
			ras.HUDStatus,
			ras.BeginningAgreementAmount,
			ras.AgreementChangeAmount,
			ras.EndingAgreementAmount,
			ras.BeginningBalance,
			ras.TotalPayment,
			ras.EndingBalance,
			ras.AmountRetained,
			ras.AmountRequested,
			NULL as 'OAVendorData'
		FROM RepaymentAgreementSubmission ras
			INNER JOIN AffordableSubmissionItem asi on ras.RepaymentAgreementSubmissionID = asi.ObjectID
			INNER JOIN RepaymentAgreement ra on ra.RepaymentAgreementID = ras.RepaymentAgreementID
			INNER JOIN Lease l on ra.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut on u.UnitTypeID = ut.UnitTypeID
			INNER JOIN PersonLease pl on pl.LeaseID = l.LeaseID AND pl.HouseholdStatus = 'Head of Household'
			INNER JOIN Person p on pl.PersonID = p.PersonID
		WHERE ras.AccountID = @accountID AND asi.AffordableSubmissionID = @affordableSubmissionID
	END
	ELSE
	BEGIN

		INSERT @repaymentAgreementIDs SELECT RepaymentAgreementID FROM RepaymentAgreement ra
										INNER JOIN Lease l on ra.LeaseID = l.LeaseID
										INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										INNER JOIN Unit u on ulg.UnitID = u.UnitID
										INNER JOIN UnitType ut on ut.UnitTypeID = u.UnitTypeID
									   WHERE ut.PropertyID = @propertyID

		INSERT INTO #RepaymentSchedulesPayments EXEC GetRepaymentSchedules @accountID, @repaymentAgreementIDs

		INSERT #RepaymentPaymentsSum SELECT RepaymentAgreementID, SUM(ISNULL(PaymentMade, 0)), SUM(ISNULL(AmountRetained, 0)) 
									 FROM #RepaymentSchedulesPayments GROUP BY RepaymentAgreementID

		SELECT
			ra.RepaymentAgreementID,
			'R' as 'RecordType',
			p.FirstName,
			p.LastName,
			ISNULL(u.HudUnitNumber, u.Number) as 'UnitNumber',
			ra.AgreementID,
			ra.AgreementStartDate as 'AgreementDate',
			ra.AgreementEndDate,
			ra.AgreementType as 'TransactionType',
			ra.HUDStatus as 'Status',
			ISNULL(ls.EndingAgreementAmount, 0) as 'BeginningAgreementAmount',
			ra.TotalRequestedAmount - ISNULL(ls.EndingAgreementAmount, 0) as 'AgreementChangeAmount',
			ra.TotalRequestedAmount as 'EndingAgreementAmount',
			ISNULL(ls.EndingBalance, 0) as 'BeginningBalance',
			CASE WHEN ra.HUDStatus = 'Final - Reversed' THEN 0
			ELSE
			CAST(ROUND(ISNULL(#rps.PaymentMade, 0), 0) as int) - ISNULL(lssum.TotalPayment, 0)
			END as 'TotalPayment',
			CASE WHEN ra.HUDStatus = 'Final - Reversed' THEN ra.TotalRequestedAmount
			ELSE
				CAST(ISNULL(ls.EndingBalance, 0)
						- ROUND((ISNULL(#rps.PaymentMade, 0) - ISNULL(lssum.TotalPayment, 0)), 0)
						+ (ra.TotalRequestedAmount - ISNULL(ls.EndingAgreementAmount, 0)) as int)
			END as 'EndingBalance',
			CASE WHEN ra.HUDStatus = 'Final - Reversed' THEN -ISNULL(lssum.AmountRetained, 0)
			ELSE
			CAST(ROUND(ISNULL(#rps.AmountRetained, 0), 0) as int) - ISNULL(lssum.AmountRetained, 0) 
			END as 'AmountRetained',
			CASE WHEN ra.HUDStatus = 'Final - Reversed' 
			THEN
			(ra.TotalRequestedAmount - ISNULL(ls.EndingAgreementAmount, 0))
				+ ISNULL(lssum.TotalPayment, 0)
				- ISNULL(lssum.AmountRetained, 0)
			ELSE
			(ra.TotalRequestedAmount - ISNULL(ls.EndingAgreementAmount, 0)) 
				- CAST(ROUND(ISNULL(#rps.PaymentMade, 0), 0) - ISNULL(lssum.TotalPayment, 0) as int)
				+ CAST(ROUND(ISNULL(#rps.AmountRetained, 0), 0) - ISNULL(lssum.AmountRetained, 0) as int) 
			END as 'AmountRequested',
			NULL as 'OAVendorData'
		FROM RepaymentAgreement ra
			INNER JOIN Lease l on ra.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut on u.UnitTypeID = ut.UnitTypeID
			INNER JOIN PersonLease pl on pl.LeaseID = l.LeaseID AND pl.HouseholdStatus = 'Head of Household'
			INNER JOIN Person p on pl.PersonID = p.PersonID
			INNER JOIN #RepaymentPaymentsSum #rps on #rps.RepaymentAgreementID = ra.RepaymentAgreementID
			OUTER APPLY
				(SELECT TOP 1 ras.* 
					FROM RepaymentAgreementSubmission ras 
						LEFT JOIN AffordableSubmissionItem asi on asi.ObjectID = ras.RepaymentAgreementSubmissionID
						LEFT JOIN AffordableSubmission sub on asi.AffordableSubmissionID = sub.AffordableSubmissionID
					WHERE (sub.[Status] IN ('Success', 'Corrections Needed') OR asi.ObjectID IS NULL) 
						AND ras.RepaymentAgreementID = ra.RepaymentAgreementID							
					ORDER BY sub.DateSubmitted DESC) [ls]
			LEFT JOIN
				(SELECT ras.RepaymentAgreementID, SUM(ISNULL(ras.TotalPayment, 0)) TotalPayment, SUM(ISNULL(ras.AmountRetained, 0)) AmountRetained
					FROM RepaymentAgreementSubmission ras
						LEFT JOIN AffordableSubmissionItem asi on asi.ObjectID = ras.RepaymentAgreementSubmissionID
						LEFT JOIN AffordableSubmission sub on asi.AffordableSubmissionID = sub.AffordableSubmissionID
					WHERE sub.[Status] IN ('Success', 'Corrections Needed') or asi.ObjectID IS NULL
					GROUP BY ras.RepaymentAgreementID) lssum ON lssum.RepaymentAgreementID = ra.RepaymentAgreementID
		WHERE ra.InternalStatus <> 'Inactive' AND
			((ls.RepaymentAgreementSubmissionID IS NULL AND ra.HUDStatus != 'Final - Reversed')
			OR (ls.RepaymentAgreementSubmissionID IS NOT NULL 
				AND NOT (ls.HUDStatus IN ('Final - Completed', 'Final - Reversed', 'Final - Terminated', 'Final - Moved-out Inactive')
				AND ra.HUDStatus = ls.HUDStatus))) AND
			ut.PropertyID = @propertyID

	END

END
GO
