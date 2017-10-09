SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		The Great Ponytail
-- Create date: Sept. 13, 2016
-- Description:	Gets the data for the Prepaid Depletion Report for Wasatch
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_SHARBO_PrepaidDepletions] 
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS

DECLARE @accountID bigint

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #AgedReceivablesByPonytail (	
		ReportDate date NOT NULL,
		PropertyName nvarchar(100) NOT NULL,	
		PropertyID uniqueidentifier NOT NULL,
		Unit nvarchar(50) NULL,
		PaddedUnit nvarchar(50) NULL,
		ObjectID uniqueidentifier NOT NULL,
		ObjectType nvarchar(25) NOT NULL,	
		LeaseID uniqueidentifier NOT NULL,
		Names nvarchar(250) NULL,	
		TransactionID uniqueidentifier NULL,
		PaymentID uniqueidentifier NULL,
		TransactionType nvarchar(50) NOT NULL,		
		TransactionDate datetime NOT NULL,
		LedgerItemType nvarchar(50) NULL,
		Total money NULL,		
		PrepaymentsCredits money NULL,
		Reason nvarchar(500) NULL)

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier NOT NULL)

	CREATE TABLE #PrepaidPonytailCutting (
		PropertyID uniqueidentifier NOT NULL,
		PropertyName nvarchar(100) NOT NULL,
		Unit nvarchar(50) NULL,
		PaddedUnit nvarchar(50) NULL,
		ObjectID uniqueidentifier NOT NULL,							-- Transaction.ObjectID
		ObjectType nvarchar(50) NOT NULL,
		ResidentNames nvarchar(500) NULL,
		PrepayAmount money NULL,									-- Run RPT_TNS_AgedReceivables and sum up PrepaymentsAndCredits column by ObjectID where TransactionType IN (Payment, Prepayment)
		PaymentDate date NULL,										-- Earliest date from each transaction from above
		RecurringChargesTotal money NULL							-- Get the Lease in effect on the date (See RPT_TNS_RentRoll lines 465 to 505) and get the net sum of LeaseLedgerItems (Charges - Credits)
		)

	INSERT #Properties
		SELECT Value FROM @propertyIDs

	INSERT #AgedReceivablesByPonytail
		EXEC RPT_TNS_AgedReceivables @date, @propertyIDs
	
	INSERT #PrepaidPonytailCutting
		SELECT	PropertyID,
				PropertyName,
				Unit,
				PaddedUnit,
				ObjectID,
				ObjectType,
				Names,
				null,
				null,
				null
			FROM #AgedReceivablesByPonytail 
	
	UPDATE #PrepaidPonytailCutting SET PrepayAmount = (SELECT SUM(PrepaymentsCredits)
														   FROM #AgedReceivablesByPonytail
														   WHERE TransactionType IN ('Payment', 'Prepayment')
														     AND ObjectID = #PrepaidPonytailCutting.ObjectID)

	UPDATE #PrepaidPonytailCutting SET PaymentDate = (SELECT TOP 1 TransactionDate
														  FROM #AgedReceivablesByPonytail
														  WHERE ObjectID = #PrepaidPonytailCutting.ObjectID
														  ORDER BY TransactionDate)

	CREATE TABLE #RROccupants 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null,
		LeaseID uniqueidentifier null			
	)

	CREATE TABLE #RROccupants2 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null				
	)

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #Properties))

	INSERT INTO #RROccupants2
		EXEC GetOccupantsByDate @accountID, @date, @propertyIDs
						

	INSERT INTO #RROccupants
		SELECT *, null FROM #RROccupants2

	-- Get the last lease where the date is in the lease date range
	UPDATE rro
			SET LeaseID = l.LeaseID				 
	FROM #RROccupants rro
		INNER JOIN Lease l ON l.UnitLeaseGroupID = rro.UnitLeaseGroupID
	WHERE rro.UnitLeaseGroupID IS NOT NULL
		AND (l.LeaseID = (SELECT TOP 1 LeaseID			
							FROM Lease 								
							WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
								AND LeaseStartDate <= @date
								AND LeaseEndDate >= @date
								AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
							ORDER BY DateCreated DESC))
		
	-- Get the last lease where the EndDate <= @date (Month-to-Month Leases) 
	UPDATE rro
			SET LeaseID = l.LeaseID				 
	FROM #RROccupants rro
		INNER JOIN Lease l ON l.UnitLeaseGroupID = rro.UnitLeaseGroupID
	WHERE rro.UnitLeaseGroupID IS NOT NULL
		AND rro.LeaseID IS NULL
		AND (l.LeaseID = (SELECT TOP 1 LeaseID			
							FROM Lease 								
							WHERE UnitLeaseGroupID = l.UnitLeaseGroupID								  
								AND LeaseEndDate <= @date
								AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
							ORDER BY LeaseEndDate DESC))
		 

	-- For the messed up lease entries, grab the first lease
	-- associated with the UnitLeaseGroup
	UPDATE rro
			SET LeaseID = l.LeaseID				 				 
	FROM #RROccupants rro
		INNER JOIN Lease l ON l.UnitLeaseGroupID = rro.UnitLeaseGroupID
	WHERE rro.UnitLeaseGroupID IS NOT NULL
		AND rro.LeaseID IS NULL
		AND (l.LeaseID = (SELECT TOP 1 LeaseID			
							FROM Lease 
							WHERE UnitLeaseGroupID = l.UnitLeaseGroupID							 
							AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
							ORDER BY LeaseStartDate))	
							
	UPDATE #PrepaidPonytailCutting SET RecurringChargesTotal = ((ISNULL((SELECT SUM(lli.Amount)
																			 FROM LeaseLedgerItem lli
																				 INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																				 INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
																				 INNER JOIN #RROccupants #rro ON lli.LeaseID = #rro.LeaseID
																			 WHERE #rro.UnitLeaseGroupID = #PrepaidPonytailCutting.ObjectID
																			   AND lli.StartDate <= @date
																			   --AND lli.EndDate >= @date
																			   AND lit.IsRent = 1), 0))
																- ISNULL((SELECT SUM(lli.Amount)
																			 FROM LeaseLedgerItem lli
																				 INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																				 INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
																				 INNER JOIN #RROccupants #rro ON lli.LeaseID = #rro.LeaseID
																			 WHERE #rro.UnitLeaseGroupID = #PrepaidPonytailCutting.ObjectID
																			   AND lli.StartDate <= @date
																			   --AND lli.EndDate >= @date
																			   AND lit.IsCredit = 1), 0))
																 
	SELECT	DISTINCT
			PropertyID,
			PropertyName,
			Unit,
			PaddedUnit,
			ObjectID,
			ObjectType,
			ResidentNames,
			ISNULL(PrepayAmount, 0) AS 'PrepayAmount',
			PaymentDate,
			ISNULL(RecurringChargesTotal, 0) AS 'RecurringChargesTotal'
		FROM #PrepaidPonytailCutting
		ORDER BY PropertyName, PaddedUnit
																	 		 

END
GO
