SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 21, 2015
-- Description:	Custom Portfolio Occupancy
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_BSR_CustomPortfolioOccupancy] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY
AS

DECLARE @accountingPeriodID uniqueidentifier
DECLARE @date date = GETDATE()
DECLARE @myLittleSetOfPropertyIDs GuidCollection
DECLARE @i int = 1
DECLARE @maxI int

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Portfolio (
		PropertyID uniqueidentifier not null,
		RegionalManagerID uniqueidentifier null,
		UnitCount int null,
		VacantCount int null,
		OccupiedCount int null,
		ApprovedCount int null,
		OnNoticeCount int null,
		VacantReady int null,
		BudgetedOccupancy decimal(9, 3) null,
		CurrentCharged money null,
		CurrentPayments money null)

		
	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		PendingApplicationDate date null,
		PendingMoveInDate date null)
		
	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier null,
		PropertyAccountingPeriodID uniqueidentifier null)

	CREATE TABLE #AccountingPeriodIDs (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier null )

	CREATE TABLE #GLAccountIDs (
		GLAccountID uniqueidentifier not null)

	INSERT #Properties 
		SELECT pIDs.Value, pap.AccountingPeriodID, pap.PropertyAccountingPeriodID
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.StartDate <= @date AND pap.EndDate >= @date

	INSERT #GLAccountIDs
		SELECT GLAccountID
			FROM GLAccount
			WHERE Number IN ('5115', '5125', '5220', '5234', '5240', '5245', '5250', '6320', '6321')
			  AND AccountID = @accountID

	INSERT #AccountingPeriodIDs
		SELECT DISTINCT AccountingPeriodID 
			FROM #Properties

	SET @maxI = (SELECT MAX(Sequence) FROM #AccountingPeriodIDs)
	WHILE (@i <= @maxI)
	BEGIN
		SET @accountingPeriodID = (SELECT AccountingPeriodID FROM #AccountingPeriodIDs WHERE [Sequence] = @i)

		INSERT @myLittleSetOfPropertyIDs 
			SELECT PropertyID 
				FROM #Properties
				WHERE AccountingPeriodID = @accountingPeriodID
		
		INSERT #LeasesAndUnits
			EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @myLittleSetOfPropertyIDs	

		SET @i = @i + 1
		DELETE @myLittleSetOfPropertyIDs
	END

	INSERT #Portfolio
		SELECT #prop.PropertyID, null, null, null, null, null, null, null, null, null, null
			FROM #Properties #prop

	UPDATE #Portfolio SET UnitCount = (SELECT COUNT(u.UnitID)
											FROM Unit u
												INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											WHERE #Portfolio.PropertyID = ut.PropertyID
											  AND u.ExcludedFromOccupancy = 0
											  AND (u.DateRemoved IS NULL OR u.DateRemoved > GETDATE()))
											  

	UPDATE #Portfolio SET VacantCount = (SELECT COUNT(*)
											FROM #LeasesAndUnits #lau
												INNER JOIN Unit u ON #lau.UnitID = u.UnitID
											WHERE #Portfolio.PropertyID = #lau.PropertyID
											  AND #lau.OccupiedUnitLeaseGroupID IS NULL
											  AND u.ExcludedFromOccupancy = 0
											  AND (u.DateRemoved IS NULL OR u.DateRemoved > GETDATE()))

	UPDATE #Portfolio SET OccupiedCount = (SELECT COUNT(*)
												FROM #LeasesAndUnits #lau
												WHERE #Portfolio.PropertyID = #lau.PropertyID
												  AND #lau.OccupiedUnitLeaseGroupID IS NOT NULL)

	UPDATE #Portfolio SET ApprovedCount = (SELECT COUNT(DISTINCT #lau.PendingUnitLeaseGroupID)
												FROM #LeasesAndUnits #lau
													INNER JOIN Lease l ON #lau.PendingUnitLeaseGroupID = l.UnitLeaseGroupID
													INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApprovalStatus IN ('Approved')
												WHERE #Portfolio.PropertyID = #lau.PropertyID)

	UPDATE #Portfolio SET OnNoticeCount = (SELECT COUNT(DISTINCT #lau.OccupiedUnitLeaseGroupID)
												FROM #LeasesAndUnits #lau
												WHERE #Portfolio.PropertyID = #lau.PropertyID
												  AND #lau.OccupiedUnitLeaseGroupID IS NOT NULL
												  AND #lau.OccupiedNTVDate IS NOT NULL)

	UPDATE #Portfolio SET VacantReady = (SELECT COUNT(#lau.UnitID)
												FROM #LeasesAndUnits #lau
													CROSS APPLY GetUnitStatusByUnitID(#lau.UnitID, @date) AS [UStatus]
												WHERE #lau.OccupiedUnitLeaseGroupID IS NULL
												  AND #Portfolio.PropertyID = #lau.PropertyID
												  AND [UStatus].[Status] IN ('Ready'))

	UPDATE #Portfolio SET CurrentCharged = (SELECT SUM(t.Amount)
												FROM [Transaction] t
													INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Charge') AND tt.[Group] IN ('Lease')
													INNER JOIN #Properties #prop ON t.PropertyID = #prop.PropertyID
													INNER JOIN PropertyAccountingPeriod pap ON #prop.PropertyID = pap.PropertyID AND #prop.AccountingPeriodID = pap.AccountingPeriodID
													--LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
												WHERE #Portfolio.PropertyID = t.PropertyID
												  --AND tr.TransactionID IS NULL
												  AND (pap.StartDate <= t.TransactionDate AND pap.EndDate >= t.TransactionDate))

	UPDATE #Portfolio SET CurrentPayments = (SELECT SUM(Amount)
											FROM
											(SELECT DISTINCT p.PaymentID, p.Amount
												FROM [Transaction] t
													INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment') AND tt.[Group] IN ('Lease')
													INNER JOIN PaymentTransaction pt ON pt.TransactionID = t.TransactionID
													INNER JOIN Payment p ON p.PaymentID = pt.PaymentID
													INNER JOIN #Properties #prop ON t.PropertyID = #prop.PropertyID
													INNER JOIN PropertyAccountingPeriod pap ON #prop.PropertyID = pap.PropertyID AND #prop.AccountingPeriodID = pap.AccountingPeriodID
													--LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
												WHERE #Portfolio.PropertyID = t.PropertyID
												  --AND tr.TransactionID IS NULL
												  AND (pap.StartDate <= p.[Date] AND pap.EndDate >= p.[Date])) Payments)

	UPDATE #Portfolio SET BudgetedOccupancy = (SELECT SUM(ISNULL(bud.AccrualBudget, 0))
												   FROM Budget bud
													   INNER JOIN #Properties #prop ON bud.PropertyAccountingPeriodID = #prop.PropertyAccountingPeriodID
													   INNER JOIN #GLAccountIDs #glas ON bud.GLAccountID = #glas.GLAccountID
												   WHERE #Portfolio.PropertyID = #prop.PropertyID)

	UPDATE #Portfolio SET BudgetedOccupancy = (SELECT CAST(BudgetedOccupancy AS decimal(9, 3)) /ISNULL(CAST(bud.AccrualBudget AS decimal(9, 3)), 1.0)
												   FROM Budget bud
													   INNER JOIN #Properties #prop ON bud.PropertyAccountingPeriodID = #prop.PropertyAccountingPeriodID
												   WHERE bud.GLAccountID = (SELECT GLAccountID FROM GLAccount WHERE Number = '5115' AND AccountID = @accountID)
												     AND #Portfolio.PropertyID = #prop.PropertyID)

	SELECT	#port.PropertyID,
			prop.Abbreviation AS 'PropertyAbbreviation',
			prop.Name AS 'PropertyName',
			prop.RegionalManagerPersonID,
			per.FirstName AS 'RegionalManagerName',
			#port.UnitCount,
			#port.VacantCount,
			#port.OccupiedCount,
			#port.ApprovedCount,
			#port.OnNoticeCount,
			ISNULL(#port.BudgetedOccupancy, 0.00) AS 'BudgetedOccupancy',	
			#port.VacantReady,
			#port.CurrentCharged,
			#port.CurrentPayments
		FROM #Portfolio #port
			INNER JOIN Property prop ON #port.PropertyID = prop.PropertyID
			INNER JOIN Person per ON prop.RegionalManagerPersonID = per.PersonID

				
END

GO
