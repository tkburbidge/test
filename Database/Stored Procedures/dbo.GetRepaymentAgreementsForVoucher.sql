SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetRepaymentAgreementsForVoucher] 
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

	CREATE TABLE #RepaymentAgreements
	(
		RepaymentAgreementID uniqueidentifier,
		RepaymentAgreementSubmissionID uniqueidentifier null,
		UnitNumber nvarchar(20),
		AgreementType nvarchar(100),
		TotalRequestedAmount int,
		AgreementChangeAmount int null,
		Payment int null,
		[Status] nvarchar(30),
		UnitLeaseGroupID uniqueidentifier,
		LeaseID uniqueidentifier,
		Paid int null,
		HasInvalidStatus bit null,
		PaddedUnitNumber nvarchar(20)
	)

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

	IF(@voucherLock = 1)
	BEGIN
		INSERT #RepaymentAgreements
		SELECT 
			ras.RepaymentAgreementID,
			ras.RepaymentAgreementSubmissionID,
			u.Number,
			ra.AgreementType,
			ras.EndingAgreementAmount,
			ras.AgreementChangeAmount,
			ras.TotalPayment,
			ras.HUDStatus,
			ulg.UnitLeaseGroupID,
			ra.LeaseID,
			asi.PaidAmount,
			0,
			u.PaddedNumber
		FROM RepaymentAgreementSubmission ras
			INNER JOIN RepaymentAgreement ra on ras.RepaymentAgreementID = ra.RepaymentAgreementID
			INNER JOIN Lease l on ra.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN AffordableSubmissionItem asi on asi.ObjectID = ras.RepaymentAgreementSubmissionID
		WHERE
			ras.AccountID = @accountID AND
			asi.AffordableSubmissionID = @affordableSubmissionID
	END
	ELSE
	BEGIN
		DECLARE @repaymentAgreementIDs GuidCollection

		INSERT @repaymentAgreementIDs SELECT RepaymentAgreementID FROM RepaymentAgreement ra
										INNER JOIN Lease l on ra.LeaseID = l.LeaseID
										INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										INNER JOIN Unit u on ulg.UnitID = u.UnitID
										INNER JOIN UnitType ut on ut.UnitTypeID = u.UnitTypeID
									   WHERE ut.PropertyID = @propertyID

		INSERT INTO #RepaymentSchedulesPayments EXEC GetRepaymentSchedules @accountID, @repaymentAgreementIDs

		INSERT #RepaymentAgreements
		SELECT
			ra.RepaymentAgreementID,
			null,
			u.Number,
			ra.AgreementType,
			ra.TotalRequestedAmount,
			ra.TotalRequestedAmount - ISNULL(ls.EndingAgreementAmount, 0),
			CASE WHEN ra.HUDStatus = 'Final - Reversed' THEN -ISNULL(lssum.TotalPayment, 0)
			ELSE
			(SELECT ISNULL(SUM(#rsp.PaymentMade), 0) - ISNULL(lssum.TotalPayment, 0)
						FROM #RepaymentSchedulesPayments #rsp
						WHERE #rsp.RepaymentAgreementID = ra.RepaymentAgreementID)
			END,
			ra.HUDStatus,
			ulg.UnitLeaseGroupID,
			l.LeaseID,
			NULL AS 'Paid',
			NULL AS 'HasInvalidStatus',
			u.PaddedNumber
		FROM RepaymentAgreement ra
			INNER JOIN Lease l on ra.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut on u.UnitTypeID = ut.UnitTypeID
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
					WHERE sub.[Status] IN ('Success', 'Corrections Needed') OR asi.ObjectID IS NULL
					GROUP BY ras.RepaymentAgreementID) lssum ON lssum.RepaymentAgreementID = ra.RepaymentAgreementID
		WHERE ra.InternalStatus <> 'Inactive' AND
			((ls.RepaymentAgreementSubmissionID IS NULL AND ra.HUDStatus != 'Final - Reversed')
			OR (ls.RepaymentAgreementSubmissionID IS NOT NULL 
				AND NOT (ls.HUDStatus IN ('Final - Completed', 'Final - Reversed', 'Final - Terminated', 'Final - Moved-out Inactive')
				AND ra.HUDStatus = ls.HUDStatus))) AND
			ut.PropertyID = @propertyID					
	END

	UPDATE #ra
	SET #ra.HasInvalidStatus = CASE WHEN #ra.Payment > 0 AND #ra.[Status] IN ('Final - Moved-out Inactive', 'Inactive') THEN 1
							   WHEN 
									#ra.[Status] IN ('Active', 'Moved-out Active') AND #ra.Payment <= 0 AND
									(SELECT COUNT(*) FROM (SELECT TOP 3 ras.TotalPayment 
															FROM RepaymentAgreementSubmission ras 
																INNER JOIN AffordableSubmissionItem asi on asi.ObjectID = ras.RepaymentAgreementSubmissionID
																INNER JOIN AffordableSubmission sub on asi.AffordableSubmissionID = sub.AffordableSubmissionID and sub.[Status] IN ('Success', 'Corrections Needed')
															WHERE ras.RepaymentAgreementID = #ra.RepaymentAgreementID
															ORDER BY sub.DateSubmitted DESC) as t
									WHERE t.TotalPayment <= 0) = 3 THEN 1
							   ELSE 0 END
	FROM #RepaymentAgreements #ra

	SELECT * FROM #RepaymentAgreements
END
GO
