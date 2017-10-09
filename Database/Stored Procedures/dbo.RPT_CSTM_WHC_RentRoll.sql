SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 22, 2016
-- Description:	Woodsmere Custom Rent Roll Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_WHC_RentRoll] 
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS

DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #RentRoll (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(200) null,
		UnitID uniqueidentifier null,
		PaddedUnit nvarchar(50) null,
		Unit nvarchar(50) null,
		BuildingID uniqueidentifier null,
		BuildingName nvarchar(200) null,
		BuildingStreetAddress nvarchar(50) null,
		BuildingCity nvarchar(50) null,
		BuildingState nvarchar(50) null,
		BuildingZip nvarchar(50) null,
		ResidentNames nvarchar(500) null,
		UnitLeaseGroupID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		SecurityDepositPaidIn money null,
		Rent money null)

	CREATE TABLE #CurrentOccupants (
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,		
		OccupiedUnitLeaseGroupID uniqueidentifier, 
		OccupiedLastLeaseID uniqueidentifier,
		OccupiedMoveInDate date,
		OccupiedNTVDate date,
		OccupiedMoveOutDate date,
		OccupiedIsMovedOut bit,
		PendingUnitLeaseGroupID uniqueidentifier,
		PendingLeaseID uniqueidentifier,
		PendingApplicationDate date,
		PendingMoveInDate date)

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier null)

	INSERT #PropertyIDs
		SELECT Value FROM @propertyIDs

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertyIDs))

	INSERT INTO #CurrentOccupants
		EXEC [GetConsolodatedOccupancyNumbers] @accountID, @date, null, @propertyIDs

	INSERT #RentRoll
		SELECT	DISTINCT
				#co.PropertyID,
				p.Name,
				#co.UnitID,
				u.PaddedNumber,
				#co.UnitNumber,
				b.BuildingID,
				b.Name,
				bAdd.StreetAddress,
				bAdd.City,
				bAdd.[State],
				bAdd.Zip,
				null AS 'ResidentNames',
				#co.OccupiedUnitLeaseGroupID,
				#co.OccupiedLastLeaseID,
				null,
				null
			FROM #CurrentOccupants #co
				INNER JOIN Property p ON #co.PropertyID = p.PropertyID
				INNER JOIN Unit u ON #co.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				LEFT JOIN [Address] bAdd ON b.AddressID = bAdd.AddressID --it's possible a building doesn't have an address entry

	UPDATE #rr SET LeaseID = null, UnitLeaseGroupID = null
		FROM #RentRoll #rr
			INNER JOIN Lease l ON #rr.LeaseID = l.LeaseID AND l.LeaseStatus IN ('Former', 'Evicted')
			INNER JOIN #CurrentOccupants #co ON #rr.LeaseID = #co.OccupiedLastLeaseID AND #co.OccupiedMoveOutDate <= @date

	UPDATE #RentRoll SET ResidentNames = (SELECT TOP 1 p.PreferredName + ' ' + p.LastName
											 FROM Person p
												 INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID		
												 INNER JOIN PersonType pt ON p.PersonID = pt.PersonID												
											 WHERE pl.LeaseID = #RentRoll.LeaseID
												   AND pt.[Type] = 'Resident'				   
												   AND pl.MainContact = 1)				   

	UPDATE #RentRoll SET SecurityDepositPaidIn = (SELECT ISNULL(SUM(t.Amount), 0)
													FROM [Transaction] t
														INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
														INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.LedgerItemTypeID IN ('c8b48b61-9e5d-482f-8263-e7cddc049b98')
													WHERE t.ObjectID = #RentRoll.UnitLeaseGroupID
													  AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Applied to Deposit')
													  AND t.TransactionDate <= @date)

	UPDATE #RentRoll SET Rent = ((ISNULL((SELECT SUM(lli.Amount)
											  FROM LeaseLedgerItem lli
												  INNER JOIN Lease l ON lli.LeaseID = #RentRoll.LeaseID
												  INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
												  INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
												WHERE l.LeaseID = #RentRoll.LeaseID), 0)
									-	ISNULL((SELECT SUM(lli.Amount)
												    FROM LeaseLedgerItem lli
													    INNER JOIN Lease l ON lli.LeaseID = #RentRoll.LeaseID
													    INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
													    INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRecurringMonthlyRentConcession = 1
													WHERE l.LeaseID = #RentRoll.LeaseID), 0)))

	SELECT * 
		FROM #RentRoll
END
GO
