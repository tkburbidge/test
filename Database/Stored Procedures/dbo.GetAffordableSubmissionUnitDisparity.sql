SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetAffordableSubmissionUnitDisparity] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyID uniqueidentifier,
	@affordableProgramAllocationID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- We have to use this crazy thing to get the current date
-- This gives us the very last second of the day, that way we don't have to worry about timezones
-- and stuff like that, so the very last status of the day will always be selected
DECLARE @date datetime = DATEADD(ms, -2, DATEADD(dd, 1, DATEDIFF(dd, 0, GetDate())))

DECLARE @HUDUnitStatuses as table(
	UnitID uniqueidentifier,
	PropertyID uniqueidentifier,
	HUDStatus nvarchar(1)
)

INSERT INTO @HUDUnitStatuses EXEC GetHUDUnitStatusesByDate @accountID, @propertyID, @date

-- Find all units for this property and account that are not exempt and store in a temp table so that we 
-- don't have to keep repeating the same query over and over again for the same data
SELECT u.UnitID,
		u.Number,
		u.SquareFootage,
		u.HearingAccessibility,
		u.MobilityAccessibility,
		u.VisualAccessibility,
		ut.Bedrooms,
		a.StreetAddress,
		a.City,
		a.[State],
		a.Zip,
		b.IdentificationNumber,
		u.IsMarket,
		asi.AffordableSubmissionItemID,
		s.HUDStatus,
		u.HudUnitNumber,
		u.PaddedNumber
INTO #UnitTempTable 
FROM Unit u
INNER JOIN Building b ON u.BuildingID = b.BuildingID
INNER JOIN Property p ON b.PropertyID = p.PropertyID
INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
INNER JOIN [Address] a ON u.AddressID = a.AddressID
INNER JOIN @HUDUnitStatuses s ON s.UnitID = u.UnitID
LEFT OUTER JOIN AffordableSubmissionItem asi ON u.UnitID = asi.ObjectID
WHERE u.AccountID = @accountID
		AND b.PropertyID = @propertyID
		AND u.IsExempt = 0
		AND u.IsHoldingUnit = 0
		AND p.ConfirmUnitBaseline = 1

-- We also have to use a temp table for the disparities because we have to keep track of what disparities we're 
-- sending so we can compare them to the affordable submission item things we're sending, we compare the two to 
-- make sure that we're only ever sending in one transaction per unit
CREATE TABLE #Disparities(
	UnitID uniqueidentifier,
	Number nvarchar(20),
	TransactionType nvarchar(10),
	[Status] nvarchar(10),
	HudUnitNumber nvarchar(10),
	PaddedNumber nvarchar(20)
)

-- A re-numbering takes precendence over an update, it should happen and be successful first before we attempt to send 
-- an update for the same unit so to account for that we fill the disparities table with the re-numbers first and then 
-- make sure that no updates get added to the table if there is already a re-number for the same unit

/* ------------------------------------ Find the unit re-numbers ------------------------------------ */
INSERT INTO #Disparities
SELECT u.UnitID,
		u.Number,
		'Renumber' AS TransactionType,
		NULL AS [Status],
		u.HudUnitNumber,
		u.PaddedNumber
FROM #UnitTempTable u
INNER JOIN AffordableSubmissionUnit asu ON u.UnitID = asu.UnitID
LEFT OUTER JOIN AffordableSubmissionItem asi ON u.UnitID = asi.ObjectID AND asi.TransactionType = 'Renumber'
INNER JOIN UnitAffordableProgramDesignation uapd ON u.UnitID = uapd.UnitID
WHERE ((u.HudUnitNumber IS NULL AND u.Number != asu.OldUnitNumber) OR (u.HudUnitNumber IS NOT NULL AND u.HudUnitNumber != asu.OldUnitNumber))
		AND (asu.NewUnitNumber IS NULL OR u.Number != asu.NewUnitNumber)
		AND asi.AffordableSubmissionItemID IS NULL
		AND @affordableProgramAllocationID = uapd.AffordableProgramAllocationID

-- Now that we have the re-numbers add updates only if there isn't a re-number for the same unit
/* ------------------------------------ Find the unit updates ------------------------------------ */
INSERT INTO #Disparities
SELECT DISTINCT u.UnitID,
		u.Number,
		'Update' AS TransactionType,
		NULL AS [Status],
		u.HudUnitNumber,
		u.PaddedNumber
FROM #UnitTempTable u
INNER JOIN AffordableSubmissionUnit asu ON u.UnitID = asu.UnitID
LEFT OUTER JOIN AffordableSubmissionItem asi ON u.UnitID = asi.ObjectID AND asi.TransactionType = 'Update'
LEFT OUTER JOIN #Disparities d ON d.UnitID = u.UnitID
INNER JOIN UnitAffordableProgramDesignation uapd ON u.UnitID = uapd.UnitID
-- At least one of the fields have to be different from the original and it can't be equal to the new value or
-- that means that we already have an affordable submission item that is trying to change the value to that
WHERE ((u.StreetAddress != asu.OldFirstAddressLine AND (asu.NewFirstAddressLine IS NULL OR u.StreetAddress != asu.NewFirstAddressLine))
		OR (u.City != asu.OldCity AND (asu.NewCity IS NULL OR u.City != asu.NewCity))
		OR (u.[State] != asu.OldState AND (asu.NewState IS NULL OR u.[State] != asu.NewState))
		OR (u.Zip != asu.OldZip AND (asu.NewZip IS NULL OR u.Zip != asu.NewZip)) 
		OR (u.MobilityAccessibility != asu.OldMobilityAccess AND (asu.NewMobilityAccess IS NULL OR u.MobilityAccessibility != asu.NewMobilityAccess))
		OR (u.HearingAccessibility != asu.OldHearingAccess AND (asu.NewHearingAccess IS NULL OR u.HearingAccessibility != asu.NewHearingAccess))
		OR (u.VisualAccessibility != asu.OldVisualAccess AND (asu.NewVisualAccess IS NULL OR u.VisualAccessibility != asu.NewVisualAccess))
		OR (u.Bedrooms != asu.OldNumberOfBedrooms AND (asu.NewNumberOfBedrooms IS NULL OR u.Bedrooms != asu.NewNumberOfBedrooms))
		OR (u.IdentificationNumber != asu.OldBIN AND (asu.NewBIN IS NULL OR u.IdentificationNumber != asu.NewBIN))
		OR (u.SquareFootage != asu.OldSquareFootage AND (asu.NewSquareFootage IS NULL OR u.SquareFootage != asu.NewSquareFootage))
		OR (u.[HUDStatus] != asu.OldUnitStatus AND (asu.NewUnitStatus IS NULL OR u.[HUDStatus] != asu.NewUnitStatus)))
		AND asi.AffordableSubmissionItemID IS NULL
		AND d.UnitID IS NULL
		AND @affordableProgramAllocationID = uapd.AffordableProgramAllocationID

-- Insert other transaction types into the disparities table
/* ------------------------------------ Find new units ------------------------------------ */
INSERT INTO #Disparities
SELECT u.UnitID,
		u.Number,
		'Add' AS TransactionType,
		NULL AS [Status],
		u.HudUnitNumber,
		u.PaddedNumber
FROM #UnitTempTable u
LEFT OUTER JOIN AffordableSubmissionUnit asu ON u.UnitID = asu.UnitID
LEFT OUTER JOIN AffordableSubmissionItem asi ON u.UnitID = asi.ObjectID AND asi.TransactionType = 'Add'
INNER JOIN UnitAffordableProgramDesignation uapd ON u.UnitID = uapd.UnitID
LEFT JOIN AffordableProgramAllocation apa ON uapd.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
LEFT JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID AND ap.IsHUD = 1
WHERE ((asu.AffordableSubmissionUnitID IS NULL
		-- If this is a brand new unit then there shouldn't be any submission items for this
		AND asi.AffordableSubmissionItemID IS NULL)
		OR (asu.AffordableSubmissionUnitID IS NOT NULL
			AND asu.OldAffordableProgramAllocationID <> uapd.AffordableProgramAllocationID))
		AND @affordableProgramAllocationID = uapd.AffordableProgramAllocationID

/* ------------------------------------ Find the unit deletes ------------------------------------ */
UNION ALL
SELECT asu.UnitID,
		asu.OldUnitNumber As 'Number',
		'Deletion' AS TransactionType,
		NULL AS [Status],
		NULL AS 'HudUnitNumber',
		u.PaddedNumber AS 'PaddedUnitNumber'
FROM AffordableSubmissionUnit asu
LEFT OUTER JOIN #UnitTempTable u ON asu.UnitID = u.UnitID
-- Another submission item that's trying to delete this unit
LEFT OUTER JOIN AffordableSubmissionItem asi ON asu.UnitID = asi.ObjectID AND asi.TransactionType = 'Deletion'
LEFT JOIN UnitAffordableProgramDesignation uapd ON u.UnitID = uapd.UnitID
LEFT JOIN AffordableProgramAllocation apa ON uapd.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
LEFT JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID AND ap.IsHUD = 1
WHERE asu.PropertyID = @propertyID
	AND asu.OldAffordableProgramAllocationID = @affordableProgramAllocationID
	AND (u.UnitID IS NULL
		OR ((SELECT uapd2.AccountID
			 FROM UnitAffordableProgramDesignation uapd2
				 JOIN AffordableProgramAllocation apa2 ON uapd2.AffordableProgramAllocationID = apa2.AffordableProgramAllocationID
				 JOIN AffordableProgram ap2 ON apa2.AffordableProgramID = ap2.AffordableProgramID AND ap2.IsHUD = 1
			 WHERE uapd2.UnitID = u.UnitID) IS NULL)
		OR (asu.OldAffordableProgramAllocationID <> uapd.AffordableProgramAllocationID AND ap.AccountID IS NOT NULL))
	--There isn't another item trying to do this same thing
    AND asi.AffordableSubmissionItemID IS NULL

-- Now our temp table is filled with all possible disparities
-- Now compare those results to what we might be resending from the affordable submission items
/* ------------------------------------ Bring in the Affordable Submission Items ------------------------------------ */
CREATE TABLE #AffordableSubmissionItems(
	UnitID uniqueidentifier,
	Number nvarchar(20),
	TransactionType nvarchar(10),
	[Status] nvarchar(10),
	HudUnitNumber nvarchar(10),
	PaddedUnitNumber nvarchar(20)
)

INSERT INTO #AffordableSubmissionItems
SELECT CASE WHEN u.UnitID IS NULL THEN asu.UnitID ELSE u.UnitID END AS 'UnitID',
		CASE WHEN u.UnitID IS NULL THEN asu.OldUnitNumber ELSE u.Number END AS 'Number',
		asi.TransactionType,
		asi.[Status],
		CASE WHEN u.UnitID IS NULL THEN NULL ELSE u.HudUnitNumber END AS 'HudUnitNumber',
		u.PaddedNumber AS 'PaddedUnitNumber'
FROM AffordableSubmissionItem asi
INNER JOIN AffordableSubmission a ON asi.AffordableSubmissionID = a.AffordableSubmissionID
										AND a.PropertyID = @propertyID
										AND a.HUDSubmissionType = 'MAT15'
										AND a.AffordableProgramAllocationID = @affordableProgramAllocationID
LEFT OUTER JOIN Unit u ON asi.ObjectID = u.UnitID
LEFT OUTER JOIN AffordableSubmissionUnit asu ON asi.ObjectID = asu.UnitID
LEFT OUTER JOIN #Disparities d ON d.UnitID = asi.ObjectID
WHERE (u.UnitID IS NOT NULL OR asu.AffordableSubmissionUnitID IS NOT NULL)
		-- Make sure there wasn't a disparity for the same unit, if there was we'll use that instead and
		-- we'll get rid of this affordable submission item later in the C# code
		-- or if there was a disparity record for this affordable submission item but that disparity is an update and
		-- this affordable submission item is a re-number then we're going to keep the affordable submission item
		-- because it takes precendence over the update
		AND (d.UnitID IS NULL OR (d.UnitID IS NOT NULL AND d.TransactionType = 'Update' AND asi.TransactionType = 'Renumber'))

INSERT INTO #AffordableSubmissionItems
SELECT d.UnitID,
	   d.Number,
	   d.TransactionType,
	   d.[Status],
	   d.HudUnitNumber,
	   d.PaddedNumber
FROM #Disparities d
LEFT OUTER JOIN #AffordableSubmissionItems asi ON d.UnitID = asi.UnitID
-- The disparities that we let appear must either not already be an affordable submission item or 
-- they must be a renumber that overpowers the update affordable submission item
WHERE asi.UnitID IS NULL
	  OR (asi.UnitID IS NOT NULL AND d.TransactionType = 'Renumber' AND asi.TransactionType = 'Update')

-- This name is kind of deceiving because all of the items in this table may not already be affordable submission items,
-- they could just be disparities that we've let through that will soon be affordable submission items
SELECT * FROM #AffordableSubmissionItems

END
GO
