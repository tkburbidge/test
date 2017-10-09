SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_RES_ResidentActivity] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate datetime = null,
	@endDate datetime = null
AS

DECLARE @date date
DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #RAPropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #RAPropertyIDs SELECT Value FROM @propertyIDs

	SET @accountID = (SELECT DISTINCT AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #RAPropertyIDs))

	SET @date = (SELECT COALESCE(EndDate, @endDate)
					FROM AccountingPeriod 
					WHERE AccountingPeriodID = @accountingPeriodID)
	
	CREATE TABLE #ResidentActivity (
		PropertyName nvarchar(50) not null,
		[Type] nvarchar(50) not null,
		Unit nvarchar(50) null,
		OldUnit nvarchar(50) null,
		PaddedUnit nchar(50) null,
		LeaseID uniqueidentifier null,
		ObjectID uniqueidentifier null,
		Name nvarchar(200) null,
		ReasonForLeaving nvarchar(500) null,
		LeaseSignedDate date null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		MoveInDate date null,
		MoveOutDate date null,
		LeaseRequiredDeposit money null,
		DepositPaidIn money null,
		DepositPaidOut money null,
		Balance money null,
		MoveOutNotes nvarchar(500) null,
		RentCharge money null,
		OtherAutobills money null,
		LeasingAgent nvarchar(50) null,
		NoticeGivenDate date null,
		RecurringConcession money null,
		LeaseApproved bit null,
		UnitType nvarchar(100))
	
	CREATE TABLE #ResidentActivityChanges (
		PropertyName nvarchar(50) not null,
		[Type] nvarchar(50) not null,
		UnitType nvarchar(50) null,
		LeaseID uniqueidentifier null,
		LeaseApproved bit null,
		LeaseSignedDate date null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		NoticeGivenDate date null,
		MoveOutReason nvarchar(MAX) null,
		MoveInDate date null,
		Unit nvarchar(50) null,
		Residents nvarchar(200) null,
		DepositsPaidIn money null,
		RentCharge money null,
		AdjustingUserName nvarchar(50) null,
		DateChanged date null,
		OldValue nvarchar(50) null,
		NewValue nvarchar(50) null,
		MarketRent money null,
		MonthToMonthFee money null
		)

	CREATE TABLE #ResidentUnitChangeInformation (
		LeaseID uniqueidentifier not null,
		OtherAutobills money null,
		RecurringConcession money null,
		OriginalRentCharge money null
		)

	CREATE TABLE #VacatorsMaybe (
		[Sequence] int identity,
		PropertyName nvarchar(500) not null,
		LeaseID uniqueidentifier not null,
		[Type] nvarchar(50) null,
		Unit nvarchar(50) null,
		UnitType nvarchar(50) null,
		LeaseEndDate date,
		--BrokeLease bit null,
		MoveInDate date null,
		NoticeGivenDate date null,
		MoveOutDate date null,
		MoveOutReason nvarchar(MAX) null,
		InitialMoveOutDate date null,
		CurrentMoveOutDate date null,
		DepositsPaidIn money,
		DaysOccupied int null,
		ChangedByPerson nvarchar(100) null,
		CreatedDate date null,
		Timestamp datetime,
		Residents nvarchar(100) null
		
		)
	
	DECLARE @maxDate datetime = '2999-12-31'
	
	--IF (@accountingPeriodID IS NOT NULL)
	--BEGIN
	--	SELECT @startDate = StartDate, @endDate = EndDate 
	--		FROM AccountingPeriod 
	--		WHERE AccountingPeriodID = @accountingPeriodID
	--END
	
	INSERT #ResidentActivity
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				'Move In' AS 'Type',
				u.Number AS 'Unit',
				--ou.Number AS 'OldUnit',
				NULL AS 'OldUnit',
				u.PaddedNumber AS 'PaddedUnit',
				l.LeaseID AS 'LeaseID',
				l.UnitLeaseGroupID AS 'ObjectID',
				pr.PreferredName + ' ' + pr.LastName AS 'Name',
				pl.ReasonForLeaving AS 'ReasonForLeaving',
				pl.LeaseSignedDate AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				pl.MoveInDate AS 'MoveInDate',
				pl.MoveOutDate AS 'MoveOutDate',
			   (SELECT SUM(lli.Amount)
					FROM UnitLeaseGroup 
						INNER JOIN Lease on Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
						INNER JOIN LeaseLedgerItem lli on lli.LeaseID = Lease.LeaseID 
						INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
						INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
					WHERE lit.IsDeposit = 1
					  AND UnitLeaseGroup.UnitLeaseGroupID = ulg.UnitLeaseGroupID) AS 'LeaseRequiredDeposit',
				(SELECT ISNULL(SUM(t.Amount), 0)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit', 'Balance Transfer Deposit')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidIn',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidOut',
				--EB.Balance AS 'Balance',
				0.00 AS 'Balance',
				null AS 'MoveOutNotes',
				(SELECT SUM(lli.Amount)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lli.StartDate <= l.LeaseStartDate
					  AND l.LeaseStartDate <= lli.EndDate
					  AND lit.IsRent = 1) AS 'RentCharge',
				ISNULL((SELECT SUM(CASE 
								WHEN lit.IsCredit = 1 THEN -lli.Amount
								ELSE lli.Amount END)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lit.IsRent = 0
					  AND lit.IsDeposit = 0
					  AND lit.IsRecurringMonthlyRentConcession = 0					  
					  AND lit.IsDepositOut = 0), 0) AS 'OtherAutobills',			
				--(SELECT rp.PreferredName + ' ' + rp.LastName
				--	FROM Prospect pros
				--		INNER JOIN PersonTypeProperty ptp ON pros.ResponsiblePersonTypePropertyID = ptp.PersonTypePropertyID
				--		INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
				--		INNER JOIN Person rp ON pt.PersonID = rp.PersonID
				--	WHERE pros.PersonID = pr.PersonID) AS 'LeasingAgent'
				--(SELECT TOP 1 rp.PreferredName + ' ' + rp.LastName
				--FROM Prospect pros
				--	INNER JOIN PersonTypeProperty ptp ON pros.ResponsiblePersonTypePropertyID = ptp.PersonTypePropertyID
				--	INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
				--	INNER JOIN Person rp ON pt.PersonID = rp.PersonID
				--	INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pros.PropertyProspectSourceID AND pps.PropertyID = p.PropertyID
				--WHERE pros.PersonID = pr.PersonID) AS 'LeasingAgent',
				(lap.PreferredName + ' ' + lap.LastName) AS 'LeasingAgent',
				pl.NoticeGivenDate AS 'NoticeGivenDate',
				null AS 'RecurringConcession',
				0 AS 'LeaseApproved',
				ut.Name
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN UnitLeaseGroup pulg ON ulg.PreviousUnitLeaseGroupID = pulg.UnitLeaseGroupID
				--LEFT JOIN Unit ou ON pulg.UnitID = ou.UnitID
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person pr ON pr.PersonID = pl.PersonID
				LEFT JOIN Person lap ON lap.PersonID = l.LeasingAgentPersonID
				INNER JOIN #RAPropertyIDs pids ON p.PropertyID = pids.PropertyID
				--OUTER APPLY GetObjectBalance(null, @maxDate, l.UnitLeaseGroupID, 0, @propertyIDs) AS EB



				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE l.LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')	
			  AND (((@accountingPeriodID IS NULL)
				  AND ((SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= @startDate)
				  AND ((SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= @endDate)
				  AND (pl.MoveInDate >= @startDate)
				  AND (pl.MoveInDate <= @endDate))
				OR ((@accountingPeriodID IS NOT NULL)
				  AND ((SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= pap.StartDate)
				  AND ((SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= pap.EndDate)
				  AND (pl.MoveInDate >= pap.StartDate)
				  AND (pl.MoveInDate <= pap.EndDate)))
			  -- Make sure lease isn't transferred
			  AND pulg.UnitLeaseGroupID IS NULL
			  -- Only get the first lease associated with the UnitLeaseGroup
			  AND l.LeaseID = (SELECT TOP 1 LeaseID 
							   FROM Lease
							   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
									 AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
							   ORDER BY LeaseStartDate)		
													 
		UNION
		
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				(CASE WHEN l.LeaseStatus = 'Evicted' THEN 'Evicted'
					  ELSE 'Move Out'
			     END) AS 'Type',			
				u.Number AS 'Unit',
				null AS 'OldUnit',
				u.PaddedNumber AS 'PaddedUnit',
				l.LeaseID AS 'LeaseID',
				l.UnitLeaseGroupID AS 'ObjectID',
				pr.PreferredName + ' ' + pr.LastName AS 'Name',
				pl.ReasonForLeaving AS 'ReasonForLeaving',
				pl.LeaseSignedDate AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				pl.MoveInDate AS 'MoveInDate',
				pl.MoveOutDate AS 'MoveOutDate',
				 (SELECT SUM(lli.Amount)
					FROM UnitLeaseGroup 
						INNER JOIN Lease on Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
						INNER JOIN LeaseLedgerItem lli on lli.LeaseID = Lease.LeaseID 
						INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
						INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
					WHERE lit.IsDeposit = 1
					  AND UnitLeaseGroup.UnitLeaseGroupID = ulg.UnitLeaseGroupID) AS 'LeaseRequiredDeposit',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit', 'Balance Transfer Deposit')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidIn',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidOut',
				--EB.Balance AS 'Balance',
				0.00 AS 'Balance',
				pl.ReasonForLeaving AS 'MoveOutNotes',
				(SELECT SUM(lli.Amount)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lli.StartDate <= l.LeaseEndDate
					  AND l.LeaseEndDate <= lli.EndDate
					  AND lit.IsRent = 1) AS 'RentCharge',
				ISNULL((SELECT SUM(CASE 
								WHEN lit.IsCredit = 1 THEN -lli.Amount
								ELSE lli.Amount END)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lit.IsRent = 0
					  AND lit.IsDeposit = 0
					  AND lit.IsDepositOut = 0), 0) AS 'OtherAutobills',			
				null AS 'LeasingAgent',
				pl.NoticeGivenDate AS 'NoticeGivenDate',
				null AS 'RecurringConcession',
				0 AS 'LeaseApproved',
				ut.Name
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN UnitLeaseGroup nulg ON nulg.PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID				
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person pr ON pr.PersonID = pl.PersonID
				INNER JOIN #RAPropertyIDs pids ON p.PropertyID = pids.PropertyID				
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE l.LeaseStatus IN ('Former', 'Evicted')
			  -- Ensure there are not residents on the lease
			  -- without a move out date			
			  AND plmo.PersonLeaseID IS NULL
			  AND (((@accountingPeriodID IS NULL)
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= @startDate)
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= @endDate)
				  AND (pl.MoveOutDate >= @startDate)
				  AND (pl.MoveOutDate <= @endDate))
				OR ((@accountingPeriodID IS NOT NULL)
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= pap.StartDate)
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= pap.EndDate)
				  AND (pl.MoveOutDate >= pap.StartDate)
				  AND (pl.MoveOutDate <= pap.EndDate)))
			   AND (nulg.UnitLeaseGroupID IS NULL OR 
					-- Or the transferred lease was cancelled
					((SELECT Count(*) FROM Lease WHERE UnitLeaseGroupID = nulg.UnitLeaseGroupID AND LeaseStatus in ('Cancelled', 'Denied')) > 0)
					-- AND there is not a non-cancelled lease that was transferred
					-- (Scenario: Transfers to a new unit and that lease cancels and transfers again
					--			  to a different unit.  In this scenario the above case will have a count
					--			  greater than zero but it will not take into account the second transfer.					
					AND (SELECT COUNT(*) 
						 FROM UnitLeaseGroup 
						 INNER JOIN Lease ON Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
					     WHERE PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID					     
							AND LeaseStatus NOT IN ('Cancelled', 'Denied')) = 0)
			  -- Get the last lease associated with the 
			  -- UnitLeaseGroup		
			  AND l.LeaseID = (SELECT TOP 1 LeaseID 
							   FROM Lease
							   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
									 AND LeaseStatus IN ('Former', 'Evicted')
							   ORDER BY LeaseEndDate DESC)	
													 

	
		UNION
		
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				'Transfer' AS 'Type',
				u.Number AS 'Unit',
				ou.Number AS 'OldUnit',
				u.PaddedNumber AS 'PaddedUnit',
				l.LeaseID AS 'LeaseID',
				l.UnitLeaseGroupID AS 'ObjectID',
				pr.PreferredName + ' ' + pr.LastName AS 'Name',
				--pl.ReasonForLeaving AS 'ReasonForLeaving',
				NULL AS 'ReasonForLeaving',
				pl.LeaseSignedDate AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				pl.MoveInDate AS 'MoveInDate',
				prevpl.MoveOutDate AS 'MoveOutDate',			
				 (SELECT SUM(lli.Amount)
					FROM UnitLeaseGroup 
						INNER JOIN Lease on Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
						INNER JOIN LeaseLedgerItem lli on lli.LeaseID = Lease.LeaseID 
						INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
						INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
					WHERE lit.IsDeposit = 1
					  AND UnitLeaseGroup.UnitLeaseGroupID = ulg.UnitLeaseGroupID) AS 'LeaseRequiredDeposit',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit', 'Balance Transfer Deposit')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidIn',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidOut',
				--EB.Balance AS 'Balance',
				0.00 AS 'Balance',
				null AS 'MoveOutNotes',
				(SELECT SUM(lli.Amount)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lli.StartDate <= l.LeaseStartDate
					  AND l.LeaseStartDate <= lli.EndDate
					  AND lit.IsRent = 1) AS 'RentCharge',
				ISNULL((SELECT SUM(CASE 
								WHEN lit.IsCredit = 1 THEN -lli.Amount
								ELSE lli.Amount END)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lit.IsRent = 0
					  AND lit.IsDeposit = 0
					  AND lit.IsDepositOut = 0),0) AS 'OtherAutobills',			
				null AS 'LeasingAgent',
				pl.NoticeGivenDate AS 'NoticeGivenDate',
				null AS 'RecurringConcession',
				0 AS 'LeaseApproved',
				ut.Name
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person pr ON pr.PersonID = pl.PersonID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN UnitLeaseGroup pulg ON ulg.PreviousUnitLeaseGroupID = pulg.UnitLeaseGroupID
				LEFT JOIN Unit ou ON pulg.UnitID = ou.UnitID
				LEFT JOIN Lease prevl ON prevl.UnitLeaseGroupID = pulg.UnitLeaseGroupID			
				LEFT JOIN PersonLease prevpl ON prevpl.LeaseID = prevl.LeaseID AND prevpl.PersonID = pr.PersonID			
				INNER JOIN #RAPropertyIDs pids ON p.PropertyID = pids.PropertyID				
				--OUTER APPLY GetObjectBalance(null, @maxDate, l.UnitLeaseGroupID, 0, @propertyIDs) AS EB



				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE l.LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
			  AND (((@accountingPeriodID IS NULL)
				  AND ((SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= @startDate)
				  AND ((SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= @endDate)
				  AND (pl.MoveInDate >= @startDate)
				  AND (pl.MoveInDate <= @endDate)) 
				OR ((@accountingPeriodID IS NOT NULL)
				  AND ((SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= pap.StartDate)
				  AND ((SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= pap.EndDate)
				  AND (pl.MoveInDate >= pap.StartDate)
				  AND (pl.MoveInDate <= pap.EndDate))) 
			  AND pulg.UnitLeaseGroupID IS NOT NULL
			  -- Get the first lease on the new UnitLeaseGroup		  
			  AND l.LeaseID = (SELECT TOP 1 LeaseID 
							   FROM Lease
							   WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
									 AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
								ORDER BY LeaseStartDate)				
			  -- Get the last lease on the old UnitLeaseGroup							
			  AND prevl.LeaseID = (SELECT TOP 1 LeaseID
								   FROM Lease
								   WHERE Lease.UnitLeaseGroupID = pulg.UnitLeaseGroupID
										 AND LeaseStatus IN ('Current', 'Former', 'Under Eviction', 'Evicted')
								   ORDER BY LeaseEndDate DESC)
		UNION
		
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				'Notice to Vacate' AS 'Type',
				u.Number AS 'Unit',
				null AS 'OldUnit',
				u.PaddedNumber AS 'PaddedUnit',
				l.LeaseID AS 'LeaseID',
				l.UnitLeaseGroupID AS 'ObjectID',
				pr.PreferredName + ' ' + pr.LastName AS 'Name',
				pl.ReasonForLeaving AS 'ReasonForLeaving',
				pl.LeaseSignedDate AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				pl.MoveInDate AS 'MoveInDate',
				pl.MoveOutDate AS 'MoveOutDate',
				 (SELECT SUM(lli.Amount)
					FROM UnitLeaseGroup 
						INNER JOIN Lease on Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
						INNER JOIN LeaseLedgerItem lli on lli.LeaseID = Lease.LeaseID 
						INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
						INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
					WHERE lit.IsDeposit = 1
					  AND UnitLeaseGroup.UnitLeaseGroupID = ulg.UnitLeaseGroupID) AS 'LeaseRequiredDeposit',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit', 'Balance Transfer Deposit')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidIn',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidOut',
				--EB.Balance AS 'Balance',
				0.00 AS 'Balance',
				pl.ReasonForLeaving AS 'MoveOutNotes',
				(SELECT SUM(lli.Amount)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lli.StartDate <= l.LeaseEndDate
					  AND l.LeaseEndDate <= lli.EndDate
					  AND lit.IsRent = 1) AS 'RentCharge',
				ISNULL((SELECT SUM(CASE 
								WHEN lit.IsCredit = 1 THEN -lli.Amount
								ELSE lli.Amount END)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lit.IsRent = 0
					  AND lit.IsDeposit = 0
					  AND lit.IsDepositOut = 0), 0) AS 'OtherAutobills',			
				null AS 'LeasingAgent',
				pl.NoticeGivenDate AS 'NoticeGivenDate',
				null AS 'RecurringConcession',
				0 AS 'LeaseApproved',
				ut.Name
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				--LEFT JOIN UnitLeaseGroup nulg ON nulg.PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID
				--LEFT JOIN Unit ou ON pulg.UnitID = ou.UnitID
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.NoticeGivenDate IS NULL AND plmo.ResidencyStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted')
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person pr ON pr.PersonID = pl.PersonID
				INNER JOIN #RAPropertyIDs pids ON p.PropertyID = pids.PropertyID
				--OUTER APPLY GetObjectBalance(null, @maxDate, l.UnitLeaseGroupID, 0, @propertyIDs) AS EB





				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE l.LeaseStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted')
			  -- Ensure there are not residents on the lease
			  -- without a move out date
			  AND plmo.PersonLeaseID IS NULL
			  AND (((@accountingPeriodID IS NULL)
				  AND ((SELECT MAX(NoticeGivenDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= @startDate)
				  AND ((SELECT MAX(NoticeGivenDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= @endDate))
			    OR ((@accountingPeriodID IS NOT NULL)
				  AND ((SELECT MAX(NoticeGivenDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= pap.StartDate)
				  AND ((SELECT MAX(NoticeGivenDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= pap.EndDate)))

			  --AND (nulg.UnitLeaseGroupID IS NULL OR (SELECT Count(*) FROM Lease WHERE UnitLeaseGroupID = nulg.UnitLeaseGroupID AND LeaseStatus = 'Cancelled') > 0)

		UNION 
		
			SELECT	DISTINCT
				p.Name AS 'PropertyName',
				'Renewal' AS 'Type',
				u.Number AS 'Unit',
				null AS 'OldUnit',
				u.PaddedNumber AS 'PaddedUnit',
				l.LeaseID AS 'LeaseID',
				l.UnitLeaseGroupID AS 'ObjectID',
				pr.PreferredName + ' ' + pr.LastName AS 'Name',
				pl.ReasonForLeaving AS 'ReasonForLeaving',
				pl.LeaseSignedDate AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				pl.MoveInDate AS 'MoveInDate',
				null AS 'MoveOutDate',
				 (SELECT SUM(lli.Amount)
					FROM UnitLeaseGroup 
						INNER JOIN Lease on Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
						INNER JOIN LeaseLedgerItem lli on lli.LeaseID = Lease.LeaseID 
						INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
						INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
					WHERE lit.IsDeposit = 1
					  AND UnitLeaseGroup.UnitLeaseGroupID = ulg.UnitLeaseGroupID) AS 'LeaseRequiredDeposit',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit', 'Balance Transfer Deposit')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidIn',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidOut',
				--EB.Balance AS 'Balance',
				0.00 AS 'Balance',
				pl.ReasonForLeaving AS 'MoveOutNotes',
				(SELECT SUM(lli.Amount)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lli.StartDate <= l.LeaseStartDate
					  AND l.LeaseStartDate <= lli.EndDate
					  AND lit.IsRent = 1) AS 'RentCharge',
				ISNULL((SELECT SUM(CASE 
								WHEN lit.IsCredit = 1 THEN -lli.Amount
								ELSE lli.Amount END)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lit.IsRent = 0
					  AND lit.IsDeposit = 0
					  AND lit.IsDepositOut = 0), 0) AS 'OtherAutobills',			
				null AS 'LeasingAgent',
				null AS 'NoticeGivenDate',
				null AS 'RecurringConcession',
				0 AS 'LeaseApproved',
				ut.Name
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID				
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID								
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person pr ON pr.PersonID = pl.PersonID		
				INNER JOIN #RAPropertyIDs pids ON p.PropertyID = pids.PropertyID	
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID	
			WHERE 
			  l.LeaseStatus NOT IN ('Cancelled', 'Pending', 'Pending Renewal', 'Pending Transfer')
			  --AND l.LeaseStartDate >= @startDate 
			  --AND l.LeaseStartDate <= @endDate
			  AND (((@accountingPeriodID IS NULL) AND (l.LeaseStartDate >= @startDate) AND (l.LeaseStartDate <= @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (l.LeaseStartDate >= pap.StartDate) AND (l.LeaseStartDate <= pap.EndDate)))			  
			  -- There is a lease before the lease we are reporting on
			  -- with the same UnitLeaseGroup
			  AND ((SELECT COUNT(prevLease.LeaseID) 
					   FROM Lease prevLease 
					   WHERE prevLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							 AND prevLease.LeaseID <> l.LeaseID 
					         AND prevLease.LeaseStartDate < l.LeaseStartDate) > 0)


		UNION
		
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				'Pending Move-Out Reconcilliation' AS 'Type',
				u.Number AS 'Unit',
				null AS 'OldUnit',
				u.PaddedNumber AS 'PaddedUnit',
				l.LeaseID AS 'LeaseID',
				l.UnitLeaseGroupID AS 'ObjectID',
				pr.PreferredName + ' ' + pr.LastName AS 'Name',
				pl.ReasonForLeaving AS 'ReasonForLeaving',
				pl.LeaseSignedDate AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				pl.MoveInDate AS 'MoveInDate',
				pl.MoveOutDate AS 'MoveOutDate',
				 (SELECT SUM(lli.Amount)
					FROM UnitLeaseGroup 
						INNER JOIN Lease on Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
						INNER JOIN LeaseLedgerItem lli on lli.LeaseID = Lease.LeaseID 
						INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
						INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
					WHERE lit.IsDeposit = 1
					  AND UnitLeaseGroup.UnitLeaseGroupID = ulg.UnitLeaseGroupID) AS 'LeaseRequiredDeposit',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit', 'Balance Transfer Deposit')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidIn',
				(SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance')
					  AND t.ObjectID = ulg.UnitLeaseGroupID) AS 'DepositPaidOut',
				--EB.Balance AS 'Balance',
				0.00 AS 'Balance',
				pl.ReasonForLeaving AS 'MoveOutNotes',
				(SELECT SUM(lli.Amount)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lli.StartDate <= l.LeaseEndDate
					  AND l.LeaseEndDate <= lli.EndDate
					  AND lit.IsRent = 1) AS 'RentCharge',
				ISNULL((SELECT SUM(CASE 
								WHEN lit.IsCredit = 1 THEN -lli.Amount
								ELSE lli.Amount END)
					FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lit.IsRent = 0
					  AND lit.IsDeposit = 0
					  AND lit.IsDepositOut = 0), 0) AS 'OtherAutobills',			
				null AS 'LeasingAgent',
				pl.NoticeGivenDate AS 'NoticeGivenDate',
				null AS 'RecurringConcession',
				0 AS 'LeaseApproved',
				ut.Name
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN UnitLeaseGroup nulg ON nulg.PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID				
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person pr ON pr.PersonID = pl.PersonID
				INNER JOIN #RAPropertyIDs pids ON p.PropertyID = pids.PropertyID				
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE l.LeaseStatus IN ('Former', 'Evicted')
			  -- Ensure there are not residents on the lease
			  -- without a move out date			
			  AND (ulg.MoveOutReconciliationDate IS NULL OR ulg.MoveOutReconciliationDate > @endDate)
			  AND plmo.PersonLeaseID IS NULL
			  AND (((@accountingPeriodID IS NULL)				 
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= @endDate)				  
				  AND (pl.MoveOutDate <= @endDate))
				OR ((@accountingPeriodID IS NOT NULL)				  
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= pap.EndDate)				  
				  AND (pl.MoveOutDate <= pap.EndDate)))
			   AND (nulg.UnitLeaseGroupID IS NULL OR 
					-- Or the transferred lease was cancelled
					((SELECT Count(*) FROM Lease WHERE UnitLeaseGroupID = nulg.UnitLeaseGroupID AND LeaseStatus in ('Cancelled', 'Denied')) > 0)
					-- AND there is not a non-cancelled lease that was transferred
					-- (Scenario: Transfers to a new unit and that lease cancels and transfers again
					--			  to a different unit.  In this scenario the above case will have a count
					--			  greater than zero but it will not take into account the second transfer.					
					AND (SELECT COUNT(*) 
						 FROM UnitLeaseGroup 
						 INNER JOIN Lease ON Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
					     WHERE PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID					     
							AND LeaseStatus NOT IN ('Cancelled', 'Denied')) = 0)
			  -- Get the last lease associated with the 
			  -- UnitLeaseGroup		
			  AND l.LeaseID = (SELECT TOP 1 LeaseID 
							   FROM Lease
							   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
									 AND LeaseStatus IN ('Former', 'Evicted')
							   ORDER BY LeaseEndDate DESC)	
													 



										
	UPDATE #RR SET Balance = Bal.Balance
		FROM #ResidentActivity #RR 	 
			CROSS APPLY GetObjectBalance(null, @maxDate, #RR.ObjectID, 0, @propertyIDs) AS [Bal]  

	UPDATE #ResidentActivity SET RecurringConcession = ISNULL((SELECT SUM(lli.Amount)
																   FROM LeaseLedgerItem lli
																	   INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																	   INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID 
																									AND (lit.IsCredit = 1 OR lit.IsRecurringMonthlyRentConcession = 1)
																   WHERE lli.LeaseID = #ResidentActivity.LeaseID
																     AND lli.StartDate <= #ResidentActivity.LeaseStartDate 
																	 AND lli.EndDate >=  #ResidentActivity.LeaseStartDate), 0)

	UPDATE #ResidentActivity SET LeaseApproved = (SELECT TOP 1 CAST(1 AS bit)
												   FROM Lease l
													   INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
												   WHERE pl.ApprovalStatus IN ('Approved')
												     AND l.LeaseID = #ResidentActivity.LeaseID)





-- Do the extra fun stuff with resident activity changes, the RecordAudit table and that kind of crap!

	INSERT #ResidentActivityChanges
		SELECT	DISTINCT
				p.Name,
				rad.RecordChanged,
				ut.Name,
				l.LeaseID,
				ISNULL((SELECT TOP 1 CAST(1 AS bit)
						FROM Lease l1
							INNER JOIN PersonLease pl ON l1.LeaseID = pl.LeaseID
						WHERE pl.ApprovalStatus IN ('Approved')
							AND l1.LeaseID = l.LeaseID), 0)
					 AS 'LeaseApproved',
				(SELECT MIN(pl.LeaseSignedDate)
						FROM PersonLease pl
						WHERE pl.LeaseID = l.LeaseID) AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				(SELECT MAX(pl.NoticeGivenDate)
					FROM PersonLease pl 
						LEFT JOIN PersonLease plNull ON pl.LeaseID = plNull.LeaseID AND pl.MoveOutDate IS NULL
					WHERE pl.LeaseID = l.LeaseID
					AND plNull.PersonLeaseID IS NULL) AS 'NoticeGivenDate',
				(SELECT TOP 1 pl.ReasonForLeaving
								  FROM PersonLease pl
								  WHERE pl.LeaseID = l.LeaseID) AS 'MoveOutReason',
				(SELECT TOP 1 MIN(pl.MoveInDate)
				FROM PersonLease pl
				WHERE pl.LeaseID = l.LeaseID)AS 'MoveInDate',
				u.Number AS 'Unit',
				null AS 'Residents',			-- AdjustedLeaseEndDate,
				null AS 'DepositsPaidIn',		-- AdjustedMoveIn, AdjustedMoveOut, AdjustedLeaseEndDate
				null AS 'RentCharge',
				per.PreferredName + ' ' + per.LastName AS 'AdjustingUserName',
				ra.CreatedDate AS 'DateChanged',
				rad.OldValue AS 'OldValue',
				rad.NewValue AS 'NewValue',
				null AS 'MarketRent',
				null AS 'MonthToMonthFee'
			FROM RecordAudit ra
				INNER JOIN RecordAuditDetail rad ON ra.RecordAuditID = rad.RecordAuditID
				INNER JOIN Person per ON ra.CreatedByPersonID = per.PersonID
				INNER JOIN Lease l ON ra.ObjectID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE rad.RecordChanged IN ('ChangeOfMoveInDate', 'ChangeOfLeaseStartDate', 'ChangeOfLeaseEndDate')
			  AND (((pap.PropertyAccountingPeriodID IS NULL) AND (ra.CreatedDate >= @startDate AND ra.CreatedDate <= @endDate))
			   OR  ((ra.CreatedDate >= pap.StartDate AND ra.CreatedDate <= pap.EndDate)))
			  AND rad.OldValue IS NOT NULL

	INSERT #ResidentActivityChanges
		SELECT	DISTINCT
				p.Name,
				rad.RecordChanged,
				ut.Name,
				l.LeaseID,
				ISNULL((SELECT TOP 1 CAST(1 AS bit)
						FROM Lease l1
							INNER JOIN PersonLease pl ON l1.LeaseID = pl.LeaseID
						WHERE pl.ApprovalStatus IN ('Approved')
							AND l1.LeaseID = l.LeaseID), 0)
					 AS 'LeaseApproved',
				(SELECT MIN(pl.LeaseSignedDate)
						FROM PersonLease pl
						WHERE pl.LeaseID = l.LeaseID) AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				(SELECT MAX(pl.NoticeGivenDate)
					FROM PersonLease pl 
						LEFT JOIN PersonLease plNull ON pl.LeaseID = plNull.LeaseID AND pl.MoveOutDate IS NULL
					WHERE pl.LeaseID = l.LeaseID
					AND plNull.PersonLeaseID IS NULL) AS 'NoticeGivenDate',
				(SELECT TOP 1 pl.ReasonForLeaving
								  FROM PersonLease pl
								  WHERE pl.LeaseID = l.LeaseID) AS 'MoveOutReason',
				(SELECT TOP 1 MIN(pl.MoveInDate)
				FROM PersonLease pl
				WHERE pl.LeaseID = l.LeaseID)AS 'MoveInDate',
				u.Number AS 'Unit',
				null AS 'Residents',			-- AdjustedLeaseEndDate,
				null AS 'DepositsPaidIn',		-- AdjustedMoveIn, AdjustedMoveOut, AdjustedLeaseEndDate
				null AS 'RentCharge',
				per.PreferredName + ' ' + per.LastName AS 'AdjustingUserName',
				ra.CreatedDate AS 'DateChanged',
				oldUnit.Number AS 'OldValue',
				newUnit.Number AS 'NewValue',
				null AS 'MarketRent',
				null AS 'MonthToMonthFee'
			FROM RecordAudit ra
				INNER JOIN RecordAuditDetail rad ON ra.RecordAuditID = rad.RecordAuditID
				INNER JOIN Person per ON ra.CreatedByPersonID = per.PersonID
				INNER JOIN UnitLeaseGroup ulg ON ra.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN Unit oldUnit ON CAST(rad.OldValue AS uniqueidentifier) = oldUnit.UnitID
				INNER JOIN Unit newUnit ON CAST(rad.NewValue AS uniqueidentifier) = newUnit.UnitID
			WHERE rad.RecordChanged IN ('FirstUnitTransfer')
			  AND (((pap.PropertyAccountingPeriodID IS NULL) AND (ra.CreatedDate >= @startDate AND ra.CreatedDate <= @endDate))
			   OR  ((ra.CreatedDate >= pap.StartDate AND ra.CreatedDate <= pap.EndDate)))


	INSERT #ResidentActivityChanges
		SELECT	DISTINCT
				p.Name,
				rad.RecordChanged,
				ut.Name,
				l.LeaseID,
				ISNULL((SELECT TOP 1 CAST(1 AS bit)
						FROM Lease l1
							INNER JOIN PersonLease pl ON l1.LeaseID = pl.LeaseID
						WHERE pl.ApprovalStatus IN ('Approved')
							AND l1.LeaseID = l.LeaseID), 0)
					 AS 'LeaseApproved',
				(SELECT MIN(pl.LeaseSignedDate)
						FROM PersonLease pl
						WHERE pl.LeaseID = l.LeaseID) AS 'LeaseSignedDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				(SELECT MAX(pl.NoticeGivenDate)
					FROM PersonLease pl 
						LEFT JOIN PersonLease plNull ON pl.LeaseID = plNull.LeaseID AND pl.MoveOutDate IS NULL
					WHERE pl.LeaseID = l.LeaseID
					AND plNull.PersonLeaseID IS NULL) AS 'NoticeGivenDate',
				(SELECT TOP 1 pl.ReasonForLeaving
								  FROM PersonLease pl
								  WHERE pl.LeaseID = l.LeaseID) AS 'MoveOutReason',
				(SELECT TOP 1 MIN(pl.MoveInDate)
				FROM PersonLease pl
				WHERE pl.LeaseID = l.LeaseID)AS 'MoveInDate',
				u.Number AS 'Unit',
				null AS 'Residents',			-- AdjustedLeaseEndDate,
				null AS 'DepositsPaidIn',		-- AdjustedMoveIn, AdjustedMoveOut, AdjustedLeaseEndDate
				null AS 'RentCharge',
				per.PreferredName + ' ' + per.LastName AS 'AdjustingUserName',
				ra.CreatedDate AS 'DateChanged',
				rad.OldValue AS 'OldValue',
				rad.NewValue AS 'NewValue',
				null AS 'MarketRent',
				null AS 'MonthToMonthFee'
			FROM RecordAudit ra
				INNER JOIN RecordAuditDetail rad ON ra.RecordAuditID = rad.RecordAuditID
				INNER JOIN Person per ON ra.CreatedByPersonID = per.PersonID
				INNER JOIN UnitLeaseGroup ulg ON ra.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE rad.RecordChanged IN ('FirstUnitTransferChangeOfRent')
			  AND (((pap.PropertyAccountingPeriodID IS NULL) AND (ra.CreatedDate >= @startDate AND ra.CreatedDate <= @endDate))
			   OR  ((ra.CreatedDate >= pap.StartDate AND ra.CreatedDate <= pap.EndDate)))


	INSERT #ResidentActivityChanges
		SELECT	DISTINCT
				p.Name,
				'LeaseCancelled' AS [Type],
				ut.Name,
				l.LeaseID,
				null AS 'LeaseApproved',
				(SELECT MAX(LeaseSignedDate)
					FROM PersonLease
					WHERE LeaseID = l.LeaseID),
				l.LeaseStartDate,
				l.LeaseEndDate,
				(SELECT MAX(NoticeGivenDate)
					FROM PersonLease
					WHERE LeaseID = l.LeaseID),
				pl.ReasonForLeaving AS 'MoveOutReason',
				pl.MoveInDate,
				u.Number,
				null AS 'Residents',
				null AS 'DepositsPaidIn',
				null AS 'RentCharge',
				leasingPer.PreferredName + ' ' + leasingPer.LastName AS 'AdjustingUserName',
				(SELECT MAX(MoveOutDate)
					FROM PersonLease
					WHERE LeaseID = l.LeaseID),
				null AS 'OldValue',
				null AS 'NewValue',
				null AS 'MarketRent',
				null AS 'MonthToMonthFee'
			FROM Lease l
				INNER JOIN Person leasingPer ON l.LeasingAgentPersonID = leasingPer.PersonID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON p.PropertyID = b.PropertyID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID			
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				--INNER JOIN Person pr ON pr.PersonID = pl.PersonID
				INNER JOIN #RAPropertyIDs #raProp ON p.PropertyID = #raProp.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				--LEFT JOIN Lease prevL ON ulg.UnitLeaseGroupID = prevL.UnitLeaseGroupID AND prevL.LeaseStartDate < l.LeaseStartDate
			WHERE (((@accountingPeriodID IS NULL) AND (pl.MoveOutDate >= @startDate) AND (pl.MoveOutDate <= @endDate))
				OR ((@accountingPeriodID IS NOT NULL) AND (pl.MoveOutDate >= pap.StartDate) AND (pl.MoveOutDate <= pap.EndDate)))		  
			  AND pl.ResidencyStatus IN ('Cancelled')
			  AND l.LeaseStatus IN ('Cancelled')		
			 -- AND prevL.LeaseID IS NULL	


	CREATE TABLE #Occupants  (
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null				
		)

	INSERT INTO #Occupants
		EXEC GetOccupantsByDate @accountID, @date, @propertyIDs

	INSERT #ResidentActivityChanges
		SELECT	DISTINCT
				p.Name,
				'MonthToMonth' AS [Type],
				ut.Name,
				l.LeaseID,
				null AS 'LeaseApproved',
				null AS 'LeaseSignedDate',
				l.LeaseStartDate,
				l.LeaseEndDate,
				null AS 'NoticeGivenDate',
				null AS 'MoveOutReason',
				(SELECT MIN(MoveInDate)
					FROM PersonLease
					WHERE LeaseID = l.LeaseID) AS 'MoveInDate',
				u.Number AS 'Unit',
				null AS 'Residents',
				null AS 'DepositsPaidIn',
				null AS 'RentCharge',
				null AS 'AdjustedUserName',
				null AS 'DateChanged',
				null AS 'OldValue',
				null AS 'NewValue',
				[MarketRent].Amount AS 'MarketRent',
				ISNULL(lli.Amount, 0) AS 'MonthToMonthFee'
			FROM #Occupants #occ
				INNER JOIN Property p ON #occ.PropertyID = p.PropertyID
				INNER JOIN Lease l ON #occ.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Settings s ON p.AccountID = s.AccountID
				INNER JOIN LedgerItemType lit ON s.MonthToMonthFeeLedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN LedgerItem li ON lit.LedgerItemTypeID = li.LedgerItemTypeID
				INNER JOIN Unit u ON #occ.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
				CROSS APPLY dbo.GetMarketRentByDate(u.UnitID, @date, 1) [MarketRent]
				LEFT JOIN LeaseLedgerItem lli ON li.LedgerItemID = lli.LedgerItemID AND lli.LeaseID = l.LeaseID
				LEFT JOIN Lease laterL ON #occ.UnitLeaseGroupID = laterL.UnitLeaseGroupID AND laterL.LeaseStartDate < @date AND laterL.LeaseEndDate > @date
				LEFT JOIN PersonLease plAllMovedOut ON l.LeaseID = plAllMovedOut.LeaseID AND (plAllMovedOut.MoveOutDate IS NULL OR plAllMovedOut.MoveOutDate > @date)
			WHERE laterL.LeaseID IS NULL
			  AND plAllMovedOut.PersonLeaseID IS NULL
			  AND l.LeaseEndDate < @date

	-- Find changes in NTV garbage.  Like NTVCancellations, and changes of MoveOutDates.
	INSERT #VacatorsMaybe
		SELECT	DISTINCT
				p.Name,
				l.LeaseID,
				rad.RecordChanged,
				u.Number,
				ut.Name,
				-- AS 'BrokeLease',
				l.LeaseEndDate,
				null AS 'MoveInDate',
				null AS 'NoticeGivenDate',
				null AS 'MoveOutDate',
				null AS 'MoveOutReason',
				CAST(rad.OldValue AS date) AS 'InitialMoveOutDate',
				CAST(rad.NewValue AS date) AS 'CurrentMoveOutDate',
				null AS 'DepositsPaidIn',
				null AS 'DaysOccupied',
				per.PreferredName + ' ' + per.LastName,
				ra.CreatedDate,
				ra.Timestamp,
				null AS 'Residents'
			FROM RecordAudit ra
				INNER JOIN RecordAuditDetail rad ON ra.RecordAuditID = rad.RecordAuditID
				INNER JOIN Person per ON ra.CreatedByPersonID = per.PersonID
				INNER JOIN Lease l ON ra.ObjectID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID				
			WHERE rad.RecordChanged IN (	'NTVCancellation', 'ChangeOfMoveOutDate')
			  AND (((pap.PropertyAccountingPeriodID IS NULL) AND (ra.CreatedDate >= @startDate AND ra.CreatedDate <= @endDate))
			   OR  ((ra.CreatedDate >= pap.StartDate AND ra.CreatedDate <= pap.EndDate)))
			AND (rad.OldValue IS NOT NULL)
			ORDER BY ra.Timestamp

	-- I think we really only care about the lastest records, provided they are different types.  So, if I change the MoveOutDate, but then cancel the NTV, we only care about
	-- the NTV cancellation.
	-- But, if I change the MoveOutDate a whole bunch of times, we need to know about it everytime, I think!
	DELETE #vm1
		FROM  #VacatorsMaybe #vm1
			INNER JOIN #VacatorsMaybe #vm2 ON #vm1.LeaseID = #vm2.LeaseID
		WHERE #vm1.[Sequence] < #vm2.[Sequence]
		  AND #vm1.[Type] <> #vm2.[Type]
		
	UPDATE #vm SET DepositsPaidIn = #ra.DepositPaidIn
		FROM #VacatorsMaybe #vm
			INNER JOIN #ResidentActivity #ra ON #vm.LeaseID = #ra.LeaseID

	UPDATE #VacatorsMaybe SET DepositsPaidIn = (SELECT SUM(t.Amount)
															  FROM [Transaction] t
																  INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																  INNER JOIN Lease l ON t.ObjectID = l.UnitLeaseGroupID
															  WHERE tt.Name IN ('Deposit', 'Balance Transfer Deposit')
															    AND l.LeaseID = #VacatorsMaybe.LeaseID)
		WHERE DepositsPaidIn IS NULL
	

	UPDATE #VacatorsMaybe SET MoveInDate = (SELECT MIN(pl.MoveInDate)
												FROM PersonLease pl
												WHERE pl.LeaseID = #VacatorsMaybe.LeaseID)

	UPDATE #VacatorsMaybe SET NoticeGivenDate = (SELECT MAX(pl.NoticeGivenDate)
													 FROM PersonLease pl
													 WHERE pl.LeaseID = #VacatorsMaybe.LeaseID)

	UPDATE #VacatorsMaybe SET MoveOutReason = (SELECT TOP 1 ReasonForLeaving
													FROM PersonLease
													WHERE LeaseID = #VacatorsMaybe.LeaseID
														AND ReasonForLeaving IS NOT NULL
													ORDER BY LEN(ReasonForLeaving))

	UPDATE #VacatorsMaybe SET DaysOccupied = ISNULL((SELECT MAX(DATEDIFF(DAY, MoveInDate, CurrentMoveOutDate))
												  FROM #VacatorsMaybe
												  WHERE LeaseID = #VacatorsMaybe.LeaseID), 0)

	UPDATE #VacatorsMaybe SET Residents = (SELECT STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
															 FROM Person 
																 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
																 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
																 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
															 WHERE PersonLease.LeaseID = #VacatorsMaybe.LeaseID
																   AND PersonType.[Type] = 'Resident'				   
																   AND PersonLease.MainContact = 1				   
															 FOR XML PATH ('')), 1, 2, ''))	 

	---- Find Cancellations (LeaseStatus in Cancelled, and it's the first lease on the ULG, no PreviousULG)
	--INSERT #ResidentActivityChanges
	--	SELECT	p.Name,
	--			'LeaseCancelled' AS [Type],
	--			ut.Name,
	--			l.LeaseID,
	--			null AS 'LeaseApproved',
	--			(SELECT MIN(LeaseSignedDate)
	--				FROM PersonLease
	--				WHERE LeaseID = l.LeaseID) AS 'LeaseSignedDate',
	--			l.LeaseStartDate,
	--			l.LeaseEndDate,
	--			null AS 'NoticeToVacate',
	--			null AS 'MoveOutReason',
	--			null AS 'MoveInDate',
	--			u.Number,
	--			null AS 'Residents',
	--			null AS 'DepositsPaidIn',
	--			null AS 'RentCharge',
	--			per.PreferredName + ' ' + per.LastName AS 'AdjustingUserName',
	--			al.[Timestamp] AS 'DateChanged',
	--			null AS 'OldValue',
	--			(SELECT MAX(MoveOutDate)
	--				FROM PersonLease
	--				WHERE LeaseID = l.LeaseID) AS 'NewValue',
	--			null AS 'MarketRent',
	--			null AS 'MonthToMonthFee'
	--		FROM Lease l
	--			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--			INNER JOIN Property p ON ut.PropertyID = p.PropertyID
	--			LEFT JOIN ActivityLog al ON l.LeaseID = al.ObjectID AND al.Activity like '%Cancel%'
	--			LEFT JOIN Person per ON al.ModifiedByPersonID = per.PersonID
	--			LEFT JOIN Lease prevL ON ulg.UnitLeaseGroupID = prevL.UnitLeaseGroupID AND l.LeaseEndDate > prevL.LeaseEndDate
	--		WHERE l.LeaseStatus IN ('Cancelled')
	--		  AND ulg.PreviousUnitLeaseGroupID IS NULL
	--		  AND prevL.LeaseID IS NULL


	UPDATE #rac SET DepositsPaidIn = #ra.DepositPaidIn, RentCharge = #ra.RentCharge, Residents = #ra.Name
		FROM #ResidentActivityChanges #rac
			INNER JOIN #ResidentActivity #ra ON #rac.LeaseID = #ra.LeaseID

	UPDATE #ResidentActivityChanges SET DepositsPaidIn = (SELECT SUM(t.Amount)
															  FROM [Transaction] t
																  INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																  INNER JOIN Lease l ON t.ObjectID = l.UnitLeaseGroupID
															  WHERE tt.Name IN ('Deposit', 'Balance Transfer Deposit')
															    AND l.LeaseID = #ResidentActivityChanges.LeaseID)
		WHERE DepositsPaidIn IS NULL

	UPDATE #ResidentActivityChanges SET RentCharge = (SELECT SUM(lli.Amount)
														  FROM LeaseLedgerItem lli
															  INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
															  INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
															  INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
														  WHERE l.LeaseID = #ResidentActivityChanges.LeaseID
														    AND lli.StartDate <= l.LeaseEndDate
														    AND l.LeaseEndDate <= lli.EndDate
														    AND lit.IsRent = 1)
		WHERE RentCharge IS NULL

	UPDATE #ResidentActivityChanges SET Residents = (SELECT STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
																	 FROM Person 
																		 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
																		 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
																		 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
																	 WHERE PersonLease.LeaseID = #ResidentActivityChanges.LeaseID
																		   AND PersonType.[Type] = 'Resident'				   
																		   AND PersonLease.MainContact = 1				   
																	 FOR XML PATH ('')), 1, 2, ''))	


	
	SELECT * FROM #ResidentActivity

	SELECT * FROM #ResidentActivityChanges

	SELECT * FROM #VacatorsMaybe
		  
END
GO
