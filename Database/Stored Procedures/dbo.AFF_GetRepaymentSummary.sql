SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Tony Morgan
-- Create date: 4/13/2017
-- Description:	Gets totals for repayments for a list of properties
-- =============================================
CREATE PROCEDURE [dbo].[AFF_GetRepaymentSummary]
	@accountID bigint,
	@propertyIDs guidcollection READONLY,
	@date date,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		EndDate [Date] NOT NULL)

    CREATE TABLE #Repayments
	(
		RepaymentAgreementID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		TotalRequestedAmount int not null,
		PaidAmount int null,
		FeesRetained int null,
		AmountDue int null
	)

	DECLARE @repaymentIDs guidcollection

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

	INSERT #PropertiesAndDates 
		SELECT #pids.PropertyID, COALESCE(pap.EndDate, @date)
			FROM #PropertyIDs #pids 
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #Repayments
		SELECT ra.RepaymentAgreementID,
			   p.PropertyID,
			   p.Name,
			   ra.TotalRequestedAmount,
			   null,
			   null,
			   null
		FROM Property p
			INNER JOIN UnitType ut on ut.PropertyID = p.PropertyID
			INNER JOIN Unit u on u.UnitTypeID = ut.UnitTypeID
			INNER JOIN UnitLeaseGroup ulg on ulg.UnitID = u.UnitID
			INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN RepaymentAgreement ra on ra.LeaseID = l.LeaseID AND ra.HUDStatus IN ('Active', 'Moved-out Active')
		WHERE p.PropertyID IN (SELECT PropertyID FROM #PropertiesAndDates) AND p.AccountID = @accountID

	INSERT @repaymentIDs SELECT RepaymentAgreementID FROM #Repayments

	INSERT INTO #RepaymentSchedulesPayments EXEC GetRepaymentSchedules @accountID, @repaymentIDs

	UPDATE #r
		SET #r.PaidAmount = #rsp.PaymentMade,
			#r.FeesRetained = #rsp.AmountRetained
	FROM #Repayments #r
		INNER JOIN #RepaymentSchedulesPayments #rsp on #rsp.RepaymentAgreementID = #r.RepaymentAgreementID

	UPDATE #r
		SET #r.AmountDue = (SELECT SUM(ras.Amount) 
							FROM RepaymentAgreementSchedule ras
								INNER JOIN RepaymentAgreement ra ON ras.RepaymentAgreementID = ra.RepaymentAgreementID
								INNER JOIN Lease l ON ra.LeaseID = l.LeaseID
								INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								INNER JOIN Unit u ON ulg.UnitID = u.UnitID
								INNER JOIN Building b ON u.BuildingID = b.BuildingID
								INNER JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
							WHERE ras.AccountID = @accountID 
								AND ras.RepaymentAgreementID = #r.RepaymentAgreementID
								AND ras.DueDate <= #pad.EndDate)
		FROM #Repayments #r

	SELECT
		MAX(PropertyID) AS 'PropertyID',
		MAX(PropertyName) as 'PropertyName',
		COUNT(RepaymentAgreementID) as 'AgreementCount',
		SUM(TotalRequestedAmount) as 'TotalRepaymentAmount',
		SUM(TotalRequestedAmount) - SUM(PaidAmount) as 'RepaymentBalance',
		SUM(ISNULL(FeesRetained, 0)) as 'TotalFeesRetained',
		CASE WHEN SUM(AmountDue) - SUM(PaidAmount) > 0 THEN SUM(AmountDue) - SUM(PaidAmount) ELSE 0 END as 'TotalDelinquent'
	FROM #Repayments
	GROUP BY PropertyID
	ORDER BY PropertyName
END
GO
