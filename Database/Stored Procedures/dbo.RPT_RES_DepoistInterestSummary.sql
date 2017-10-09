SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 15, 2016
-- Description:	Gets the data for the Deposit Interest Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_DepoistInterestSummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@date date = null,
	@leaseStatuses StringCollection READONLY,
	@objectTypes StringCollection READONLY
AS

DECLARE @ObjectIDs GuidCollection
DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @propertyID uniqueidentifier

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Properties (
		[Sequence] int identity,
		PropertyID uniqueidentifier not null)

	CREATE TABLE #ObjectsAndBalances (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) null,
		ObjectID uniqueidentifier null,
		UnitNumber nvarchar(50) null,
		PaddedNumber nvarchar(100) null,
		Residents nvarchar(500) null,
		MoveInDate date null,
		MoveOutDate date null,
		LeaseID uniqueidentifier null,
		LeaseExpiresDate date null,
		DepositsHeld money null,
		InterestAccrued money null,
		InterestPaidOut money null,
		InterestHeld money null,
		ObjectType nvarchar(50) null,
		LeaseStatus nvarchar(50) null,
		ImportDepositsPaidOut money null)
		
	CREATE TABLE #InterestHeld (
		ObjectID uniqueidentifier null,
		TotalInterestDue money null,
		DepositsHeld money null,
		ConversionDepositInterestRefund money null,
		)

	INSERT #Properties
		SELECT Value FROM @propertyIDs
	
	INSERT #ObjectsAndBalances
		SELECT	#prop.PropertyID, p.Name, ulg.UnitLeaseGroupID, u.Number, u.PaddedNumber, null, null, null, l.LeaseID, l.LeaseEndDate, null, null, null, null, 'Lease', l.LeaseStatus, ulg.ConversionDepositInterestRefund
			FROM #Properties #prop
				INNER JOIN Property p ON #prop.PropertyID = p.PropertyID
				INNER JOIN UnitType ut ON #prop.PropertyID = ut.PropertyID
				INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			WHERE l.LeaseID = (SELECT TOP 1 LeaseID	
								   FROM Lease
								   INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = Lease.LeaseStatus
								   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								     AND l.LeaseStatus IN (SELECT Value FROM @leaseStatuses)
								   ORDER BY o.OrderBy)
			  AND 'Lease' IN (SELECT Value FROM @objectTypes)

	--INSERT #ObjectsAndBalances
	--	SELECT #prop.PropertyID, p.Name, per.PersonID, null, null, null, null, null, null, null, null, null, null, null, 'Non-Resident Account', null, null
	--		FROM [Transaction] t
	--			INNER JOIN Person per ON t.ObjectID = per.PersonID
	--			INNER JOIN #Properties #prop ON t.PropertyID = #prop.PropertyID
	--			INNER JOIN Property p ON #prop.PropertyID = p.PropertyID
	--		WHERE 'Non-Resident Account' IN (SELECT Value FROM @objectTypes)

	SET @maxCtr = (SELECT MAX([Sequence]) FROM #Properties)

	WHILE (@ctr <= @maxCtr)
	BEGIN
		SET @propertyID = (SELECT PropertyID FROM #Properties WHERE [Sequence] = @ctr)

		INSERT @ObjectIDs 
			SELECT DISTINCT ObjectID FROM #ObjectsAndBalances WHERE PropertyID = @propertyID 

		INSERT #InterestHeld
			EXEC CalculateSecurityDepositInterestTake2 @propertyID, @objectIDs, @date

		DELETE @ObjectIDs
		SET @ctr = @ctr + 1
	END

	UPDATE #oab SET DepositsHeld = #ih.DepositsHeld, InterestAccrued = #ih.TotalInterestDue--, ObjectType = #ih.ObjectType, LeaseStatus = #ih.LeaseStatus 
		FROM #ObjectsAndBalances #oab
			INNER JOIN #InterestHeld #ih ON #oab.ObjectID = #ih.ObjectID

	UPDATE #ObjectsAndBalances SET InterestPaidOut = (ISNULL(ImportDepositsPaidOut, 0)) + ISNULL((SELECT SUM(t.Amount)
																  FROM [Transaction] t
																	  INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Deposit Interest Payment'
																	  LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
																  WHERE tr.TransactionID IS NULL
																	AND t.ReversesTransactionID IS NULL
																	AND t.ObjectID = #ObjectsAndBalances.ObjectID), 0)

	UPDATE #ObjectsAndBalances SET Residents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
														 FROM Person 
															 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
															 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
															 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
														 WHERE PersonLease.LeaseID = #ObjectsAndBalances.LeaseID
															   AND PersonType.[Type] = 'Resident'				   
															   AND PersonLease.MainContact = 1				   
														 FOR XML PATH ('')), 1, 2, '')	
														 
	UPDATE #ObjectsAndBalances SET MoveInDate = (SELECT MIN(pl.MoveInDate)
													FROM PersonLease pl													
													WHERE pl.LeaseID = #ObjectsAndBalances.LeaseID
														AND pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
				
	UPDATE #ObjectsAndBalances SET MoveOutDate = (SELECT TOP 1 pl.MoveOutDate
													FROM PersonLease pl
														LEFT JOIN PersonLease plMONull ON #ObjectsAndBalances.LeaseID = plMONull.LeaseID
																			AND plMONull.MoveOutDate IS NULL
													WHERE pl.LeaseID = #ObjectsAndBalances.LeaseID
														AND plMONull.PersonLeaseID IS NULL
													ORDER BY pl.MoveOutDate DESC)
															
	UPDATE #ObjectsAndBalances SET InterestHeld = ISNULL(InterestAccrued, 0) - ISNULL(InterestPaidOut, 0)-- - ISNULL(ImportDepositsPaidOut, 0)													 			

	SELECT *
		FROM #ObjectsAndBalances
		ORDER BY PropertyName, PaddedNumber

END
GO
