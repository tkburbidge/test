SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_PRSPT_GeneralData]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
	@accountingPeriodID uniqueidentifier = null,
	@filters StringCollection READONLY,
	@fields StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
	CREATE TABLE #PropertiesAndDates (	
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)


	INSERT #PropertiesAndDates 
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID


	CREATE TABLE #AllProspects (
		PropertyID uniqueidentifier,
		MainPersonID uniqueidentifier,	
		FirstContactDate datetime,	
		LastContactDate datetime,	
		LostDate datetime
	)

	CREATE TABLE #FilteredProspects (
		PropertyID uniqueidentifier,
		MainPersonID uniqueidentifier,	
		FirstContactDate datetime,	
		LastContactDate datetime,	
		LostDate datetime,
		RecordType nvarchar(100)
	)


	INSERT INTO #AllProspects
		SELECT DISTINCT
					p.PropertyID,
					prst.PersonID,
					fpn.[Date],
					lpn.[Date],
					--(SELECT TOP 1 [Date] 
					--	FROM PersonNote 
					--	WHERE PersonID = prst.PersonID
					--	  AND PropertyID = p.PropertyID
					--	  AND PersonType = 'Prospect'
					--	  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
					--	ORDER BY [Date] ASC, [DateCreated] ASC) AS 'FirstContactDate',
					--(SELECT TOP 1 [Date] 
					--	FROM PersonNote 
					--	WHERE PersonID = prst.PersonID
					--	  AND PropertyID = p.PropertyID
					--	  AND PersonType = 'Prospect'
					--	  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
					--	ORDER BY [Date] DESC, [DateCreated] DESC) AS 'LastContactDate',
					prst.LostDate				
				FROM Prospect prst
					INNER JOIN PersonNote fpn ON fpn.PersonNoteID = prst.FirstPersonNoteID
					INNER JOIN PersonNote lpn ON lpn.PersonNoteID = prst.LastPersonNoteID
					INNER JOIN PropertyProspectSource pps ON prst.PropertyProspectSourceID = pps.PropertyProspectSourceID
					INNER JOIN Property p ON pps.PropertyID = p.PropertyID					
					INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = p.PropertyID
				WHERE prst.AccountID = @accountID
				--GROUP BY p.PropertyID, prst.PersonID, prst.LostDate


	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'FirstContactDate'))
	BEGIN
		INSERT INTO #FilteredProspects
			SELECT #ap.*, 'FirstContact'
			FROM #AllProspects #ap
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #ap.PropertyID
			WHERE  #ap.FirstContactDate >= #pad.StartDate 
				AND #ap.FirstContactDate <= #pad.EndDate
			
	END

	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'LastContactDate'))
	BEGIN
		INSERT INTO #FilteredProspects
			SELECT #ap.*, 'LastContact'
			FROM #AllProspects #ap
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #ap.PropertyID
			WHERE  #ap.LastContactDate >= #pad.StartDate 
				AND #ap.LastContactDate <= #pad.EndDate
			
	END

	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'LostDate'))
	BEGIN
		INSERT INTO #FilteredProspects
			SELECT #ap.*, 'Lost'
			FROM #AllProspects #ap
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #ap.PropertyID
			WHERE #ap.LostDate IS NOT NULL
				AND #ap.LostDate >= #pad.StartDate 
				AND #ap.LostDate <= #pad.EndDate
			
	END


		
	CREATE TABLE #ProspectData (
		PropertyID uniqueidentifier,
		ProspectID uniqueidentifier,
		MainPersonID uniqueidentifier,
		RecordType nvarchar(100),
		FirstName nvarchar(30),
		LastName nvarchar(50),
		PhoneNumber nvarchar(100),
		Email nvarchar(256),
		StreetAddress nvarchar(500),
		City nvarchar(50),
		[State] nvarchar(50),
		Zip nvarchar(20),
		ProspectSource nvarchar(50),
		MovingFrom nvarchar(50),
		ReasonForMoving nvarchar(50),
		DateNeeded datetime,
		Occupants int,
		DesiredMinBedrooms int,
		DesiredMaxBedrooms int,
		DesiredMinBathrooms int,
		DesiredMaxBathrooms int,
		UnitTypePreference nvarchar(max),
		UnitPreference nvarchar(max),
		DesiredAmenities nvarchar(max),
		BuildingPreference nvarchar(20),
		FloorPreference nvarchar(20),
		DesiredRent int,
		OtherPreferences nvarchar(4000),
		FirstContactDate datetime,
		LastContactDate datetime,
		LeasingAgent nvarchar(210),
		UnitShown bit,
		LostDate datetime,
		LostReason nvarchar(50),
		LostReasonNotes nvarchar(1000),
		OnlineApplicationSent bit,
		AppliedToUnitID uniqueidentifier
	)

	INSERT INTO #ProspectData
		SELECT
			#fp.PropertyID,
			prst.ProspectID,
			#fp.MainPersonID,
			#fp.RecordType,
			p.FirstName,
			p.LastName,
			p.Phone1,
			p.Email,
			ad.StreetAddress,
			ad.City,
			ad.[State],
			ad.Zip,
			ps.Name AS 'ProspectSource',
			prst.MovingFrom,
			rfm.Name AS 'ReasonForMoving',
			prst.DateNeeded,
			prst.Occupants,
			prst.DesiredBedroomsMin,
			prst.DesiredBedroomsMax,
			prst.DesiredBathroomsMin,
			prst.DesiredBathroomsMax,
			null,
			null,
			null,
			prst.Building,
			prst.[Floor],
			prst.MaxRent,
			prst.OtherPreferences,
			#fp.FirstContactDate,
			#fp.LastContactDate,
			lap.PreferredName + ' ' + lap.LastName AS 'LeasingAgent',
			CASE WHEN (SELECT COUNT(*) 
						FROM PersonNote 
						WHERE PersonID = prst.PersonID
						  AND PropertyID = #fp.PropertyID
						  AND PersonNote.InteractionType = 'Unit Shown') > 0 THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit)
			END AS 'UnitShown',
			#fp.LostDate,
			lr.Name AS 'LostReason',
			prst.LostReasonNotes,
			prst.OnlineApplicationSent,
			null
		FROM #FilteredProspects #fp
			INNER JOIN Prospect prst ON prst.PersonID = #fp.MainPersonID
			INNER JOIN Person p ON p.PersonID = #fp.MainPersonID
			INNER JOIN PropertyProspectSource pps ON prst.PropertyProspectSourceID = pps.PropertyProspectSourceID
			INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
			LEFT JOIN PersonTypeProperty laptp ON laptp.PersonTypePropertyID = prst.ResponsiblePersonTypePropertyID
			LEFT JOIN PersonType lapt ON lapt.PersonTypeID = laptp.PersonTypeID
			LEFT JOIN Person lap ON lap.PersonID = lapt.PersonID
			LEFT JOIN [Address] ad ON ad.ObjectID = p.PersonID AND ad.AddressType = 'Prospect'
			LEFT JOIN PickListItem rfm ON rfm.PickListItemID = prst.ReasonForMovingPickListItemID
			LEFT JOIN PickListItem lr ON lr.PickListItemID = prst.LostReasonPickListItemID


	UPDATE #ProspectData SET UnitTypePreference = (STUFF((SELECT ', ' + (ut.Name)
													FROM ProspectUnitType put 
														INNER JOIN UnitType ut ON ut.UnitTypeID = put.UnitTypeID		
													WHERE put.AccountID = @accountID
													  AND put.ProspectID = #ProspectData.ProspectID	
													ORDER BY ut.Name ASC		   			   
													FOR XML PATH ('')), 1, 2, ''))

	UPDATE #ProspectData SET UnitPreference = (STUFF((SELECT ', ' + (u.Number)
												FROM ProspectUnit pu 
													INNER JOIN Unit u ON u.UnitID = pu.UnitID		
												WHERE pu.AccountID = @accountID
													AND pu.ProspectID = #ProspectData.ProspectID
												ORDER BY u.PaddedNumber ASC			   			   
												FOR XML PATH ('')), 1, 2, ''))

	UPDATE #ProspectData SET DesiredAmenities = (STUFF((SELECT ', ' + (a.Name)
													FROM ProspectAmenity pa 
														INNER JOIN Amenity a ON a.AmenityID = pa.AmenityID		
													WHERE pa.AccountID = @accountID
														AND pa.ProspectID = #ProspectData.ProspectID
													ORDER BY a.Name ASC			   			   
													FOR XML PATH ('')), 1, 2, ''))

	UPDATE #ProspectData SET AppliedToUnitID = (SELECT TOP 1 u.UnitID
												FROM PersonLease pl
													INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
													INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
													INNER JOIN Unit u ON u.UnitID = ulg.UnitID
												WHERE pl.AccountID = @accountID
												  AND pl.PersonID = #ProspectData.MainPersonID
												ORDER BY l.DateCreated)


	-- return Prospect data
	SELECT *
	FROM #ProspectData	#pd


	-- return Unit data
	SELECT
		u.UnitID AS 'UnitID',
		b.BuildingID AS 'BuildingID',
		u.UnitTypeID AS 'UnitTypeID',
		u.Number AS 'Number',
		u.PaddedNumber AS 'PaddedNumber',
		ad.StreetAddress AS 'StreetAddress',
		ad.City AS 'City',
		ad.[State] AS 'State',
		ad.Zip AS 'Zip',
		u.SquareFootage AS 'SquareFootage',
		u.[Floor] AS 'Floor'
	FROM Unit u
		INNER JOIN Building b ON u.BuildingID = b.BuildingID
		LEFT JOIN [Address] ad ON u.AddressID = ad.AddressID
		INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
	WHERE u.AccountID = @accountID	  


	 -- return communication log data
    SELECT DISTINCT
        #pd.MainPersonID AS 'PersonID',
        pn.[Date],
        pn.InteractionType AS 'ContactMethod',
        pn.ContactType,
        emp.PreferredName + ' ' + emp.LastName AS 'Employee',
        pn.[Description],
        pn.Note,
		pn.DateCreated
    FROM #ProspectData #pd
        INNER JOIN PersonNote pn ON pn.PersonID = #pd.MainPersonID
        INNER JOIN Person emp ON emp.PersonID = pn.CreatedByPersonID
	WHERE pn.PropertyID = #pd.PropertyID
		AND pn.PersonType = 'Prospect'
    ORDER BY #pd.MainPersonID ASC, pn.[Date] DESC, pn.DateCreated DESC

END


GO
