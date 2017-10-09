SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Craig Perkins
-- Create date: October 7, 2013
-- Description:	Finds prospects, preferences, and person notes based on search criteria
-- =============================================
CREATE PROCEDURE [dbo].[API_SearchProspects] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier,
	@firstName nvarchar(30) = null,
	@lastName nvarchar(50) = null,
	@phone nvarchar(35) = null,
	@email nvarchar(150) = null,
	@address nvarchar(500) = null,
	@startDate DATE = null,
	@endDate DATE = null,
	@prospectID uniqueidentifier = null,
	@personID uniqueidentifier = null,
	@modifiedStartDateTime DATETIME = null,
	@modifiedEndDateTime DATETIME = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Get a list of PropsectIDs that match the search criteria

	CREATE TABLE #ProspectIDs ( ProspectID uniqueidentifier )

	CREATE TABLE #ProspectPeople(
		ProspectID uniqueidentifier,
		LeaseID uniqueidentifier,
		PersonID uniqueidentifier,
		Email nvarchar(150),
		FirstName nvarchar(35),
		MiddleName nvarchar(35),
		LastName nvarchar(50),
		Phone1 nvarchar(35),
		Phone1Type nvarchar(10),
		Phone2 nvarchar(35),
		Phone2Type nvarchar(10),
		Phone3 nvarchar(35),
		Phone3Type nvarchar(10),
		Birthdate DATE,
		StreetAddress nvarchar(500),
		City nvarchar(50),
		[State] nvarchar(50),
		Country nvarchar(50),
		Zip nvarchar(20),
		CustomerType nvarchar(50),
		LostDate date null)

	CREATE TABLE #ProspectPreferences(
		ProspectID uniqueidentifier,
		DateNeeded DATE,
		Building nvarchar(20),
		[Floor] nvarchar(20),
		MaxRent int,
		DesiredBedroomsMin int,
		DesiredBedroomsMax int,
		DesiredBathroomsMin int,
		DesiredBathroomsMax int,
		PropertyProspectSourceID uniqueidentifier)

	CREATE TABLE #DesiredUnits(
		ProspectID uniqueidentifier,
		MarketingName nvarchar(50))

	CREATE TABLE #ProspectPersonNotes(
		ProspectID uniqueidentifier,
		PersonNoteID uniqueidentifier,
		[Date] DATE,
		DateCreated DATE,
		[Description] nvarchar(200),
		Note nvarchar(max),
		MITSEventType nvarchar(50),
		PersonTypePropertyID uniqueidentifier,
		AgentFirstName nvarchar(35),
		AgentLastName nvarchar(50),
		UnitShownUnits nvarchar(max))

	CREATE TABLE #ProspectPets(
		ProspectID uniqueidentifier,
		[Type] nvarchar(20),
		Name nvarchar(50),
		Notes nvarchar(4000),
		[Weight] int)

	CREATE TABLE #ProspectEvents(
		ProspectID uniqueidentifier,
		EventID uniqueidentifier,
		[Date] datetime,
		Title nvarchar(255),
		[Description] nvarchar(max),
		AgentPersonID uniqueidentifier null,
		AgentFirstName nvarchar(35) null,
		AgentLastName nvarchar(50) null)

	INSERT INTO #ProspectIDs
		SELECT DISTINCT pro.ProspectID
		FROM Prospect pro
		INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pro.PropertyProspectSourceID
		INNER JOIN Person mp ON pro.PersonID = mp.PersonID
		LEFT JOIN ProspectRoommate prm on prm.ProspectID = pro.ProspectID
		LEFT JOIN Person prmp ON prmp.PersonID = prm.PersonID
		-- Main person's address
		LEFT JOIN [Address] mpa ON mpa.ObjectID = mp.PersonID AND mpa.AddressType = 'Prospect'
		-- Roommate's Address
		LEFT JOIN [Address] prma ON prma.ObjectID = prmp.PersonID AND prma.AddressType = 'Prospect'

		WHERE pps.PropertyID = @propertyID
		AND pps.AccountID = @accountID
		AND -- Matching on name
			((@firstName IS NULL)
			 OR (mp.FirstName = @firstName)
			 OR (prmp.FirstName = @firstName))
		AND -- Matching on name
			((@lastName IS NULL)
			 OR (mp.LastName = @lastName)
			 OR (prmp.LastName = @lastName))			 
		AND -- Matching on Email
			(@email IS NULL
			OR mp.Email = @email
			OR prmp.Email = @email)
		AND -- Matching on Phone
			(@phone IS NULL

			OR (dbo.RemoveNonNumericCharacters(mp.Phone1) = @phone 
			    OR dbo.RemoveNonNumericCharacters(mp.Phone2) = @phone
			    OR dbo.RemoveNonNumericCharacters(mp.Phone3) = @phone
			    OR dbo.RemoveNonNumericCharacters(prmp.Phone1) = @phone
			    OR dbo.RemoveNonNumericCharacters(prmp.Phone2) = @phone
			    OR dbo.RemoveNonNumericCharacters(prmp.Phone3) = @phone))
		AND -- Matching on Address
			(@address IS NULL
			OR mpa.StreetAddress = @address
			OR prma.StreetAddress = @address)
		AND -- Matching on ProspectID
			(@prospectID IS NULL
			OR pro.ProspectID = @prospectID)
		AND -- Matching on PersonID
			(@personID IS NULL
			OR pro.PersonID = @personID
			OR prm.PersonID = @personID)
		AND -- Matching on LastModified
			(@modifiedStartDateTime IS NULL
			OR (pro.LastModified >= @modifiedStartDateTime
				OR mp.LastModified >= @modifiedStartDateTime))
		AND -- Matching on LastModified
			(@modifiedEndDateTime IS NULL
			OR (pro.LastModified <= @modifiedEndDateTime
				OR mp.LastModified <= @modifiedEndDateTime))


	-- Insert all the person info into the ProspectPerson temp table
	INSERT INTO #ProspectPeople
		SELECT pro.ProspectID,
			null,
			mp.PersonID,
			mp.Email,
			mp.FirstName,
			mp.MiddleName,
			mp.LastName,
			mp.Phone1,
			mp.Phone1Type,
			mp.Phone2,
			mp.Phone2Type,
			mp.Phone3,
			mp.Phone3Type,
			mp.Birthdate,
			mpa.StreetAddress,
			mpa.City,
			mpa.[State],
			mpa.Country,
			mpa.Zip,
			null,
			pro.LostDate
		FROM Prospect pro
		INNER JOIN Person mp ON pro.PersonID = mp.PersonID
		LEFT JOIN [Address] mpa ON mpa.ObjectID = mp.PersonID AND mpa.AddressType = 'Prospect'
		WHERE pro.ProspectID IN (SELECT ProspectID FROM #ProspectIDs)
		--AND (@firstName IS NULL
		--	OR mp.FirstName = @firstName)
		--AND (@lastName IS NULL
		--	OR mp.LastName = @lastName)
		--AND -- Matching on Phone
		--	(@phone IS NULL
		--	OR (dbo.RemoveNonNumericCharacters(mp.Phone1) = @phone 
		--	    OR dbo.RemoveNonNumericCharacters(mp.Phone2) = @phone
		--	    OR dbo.RemoveNonNumericCharacters(mp.Phone3) = @phone))
		--AND (@email IS NULL 
		--	OR mp.Email = @email)
		--AND (@address IS NULL
		--	OR mpa.StreetAddress = @address)
	
	INSERT INTO #ProspectPeople
		SELECT prm.ProspectID,
			null,
			prmp.PersonID,
			prmp.Email,
			prmp.FirstName,
			prmp.MiddleName,
			prmp.LastName,
			prmp.Phone1,
			prmp.Phone1Type,
			prmp.Phone2,
			prmp.Phone2Type,
			prmp.Phone3,
			prmp.Phone3Type,
			prmp.Birthdate,
			prma.StreetAddress,
			prma.City,
			prma.[State],
			prma.Country,
			prma.Zip,
			null,
			pro.LostDate
		FROM ProspectRoommate prm
		INNER JOIN Prospect pro ON pro.ProspectID = prm.ProspectID
		INNER JOIN Person prmp ON prmp.PersonID = prm.PersonID
		LEFT JOIN [Address] prma ON prma.ObjectID = prmp.PersonID AND prma.AddressType = 'Prospect'
		WHERE prm.ProspectID IN (SELECT ProspectID FROM #ProspectIDs)
		--AND (@firstName IS NULL
		--	OR prmp.FirstName = @firstName)
		--AND (@lastName IS NULL
		--	OR prmp.LastName = @lastName)
		--AND -- Matching on Phone
		--	(@phone IS NULL
		--	OR (dbo.RemoveNonNumericCharacters(prmp.Phone1) = @phone
		--	    OR dbo.RemoveNonNumericCharacters(prmp.Phone2) = @phone
		--	    OR dbo.RemoveNonNumericCharacters(prmp.Phone3) = @phone))
		--AND (@email IS NULL 
		--	OR prmp.Email = @email)
		--AND (@address IS NULL
		--	OR prma.StreetAddress = @address)

--prospect - No lease
--applicant - Pending lease
--current_resident - current lease
--former_resident - former lease
-- lost = prospect that is lost

	UPDATE #pp
	SET #pp.CustomerType = rs.CustomerType,
		#pp.LeaseID = rs.LeaseID
	FROM #ProspectPeople #pp
		INNER JOIN (SELECT pl.PersonID, pl.LeaseID,
							(CASE WHEN pl.ResidencyStatus IN ('Current', 'Pending Renewal', 'Pending Transfer', 'Under Eviction') THEN 'current_resident'
								  WHEN pl.ResidencyStatus IN ('Pending', 'Approved') THEN 'applicant'
								  WHEN pl.ResidencyStatus IN ('Former', 'Evicted')  THEN 'former_resident'								 
								  ELSE 'prospect'
							 END) AS 'CustomerType'
					FROM PersonLease pl
					WHERE pl.PersonID IN (SELECT PersonID FROM #ProspectPeople)
						AND pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
												 FROM PersonLease pl2
														INNER JOIN Ordering o ON o.Value = pl2.ResidencyStatus AND o.[Type] = 'ResidencyStatus'
													 WHERE pl2.PersonID = pl.PersonID
													 ORDER BY o.OrderBy)) rs ON rs.PersonID = #pp.PersonID


	UPDATE #ProspectPeople SET CustomerType = 'prospect' WHERE CustomerType IS NULL

	UPDATE #ProspectPeople SET CustomerType = 'lost' WHERE CustomerType  = 'prospect' AND LostDate IS NOT NULL

	-- Preferenes : similar to abvoe
	INSERT INTO #ProspectPreferences
		SELECT pro.ProspectID,
			pro.DateNeeded,
			pro.Building,
			pro.[Floor],
			pro.MaxRent,
			pro.DesiredBedroomsMin,
			pro.DesiredBedroomsMax,
			pro.DesiredBathroomsMin,
			pro.DesiredBathroomsMax,
			pro.PropertyProspectSourceID
		FROM Prospect pro
		WHERE pro.ProspectID IN (SELECT ProspectID FROM #ProspectIDs)
	
	-- PersonNotes - Each PersonNote is going to be tied to the MainPerson
	INSERT INTO #ProspectPersonNotes
		SELECT pro.ProspectID,
			pn.PersonNoteID,
			pn.[Date],
			pn.DateCreated,
			pn.[Description],
			pn.Note,
			COALESCE(pn.MITSEventType, pn.[InteractionType]),
			ptp.PersonTypePropertyID,
			ag.FirstName,
			ag.LastName,
			(STUFF((SELECT ', ' + u.Number
						FROM PersonNoteUnit pnu
							INNER JOIN Unit u ON pnu.UnitID = u.UnitID
						WHERE pnu.AccountID = @accountID
							AND pnu.PersonNoteID = pn.PersonNoteID
						ORDER BY u.PaddedNumber
						FOR XML PATH ('')), 1, 2, ''))	
		FROM PersonNote pn
		INNER JOIN Prospect pro ON pro.PersonID = pn.PersonID
		INNER JOIN PersonType pt ON pt.PersonID = pn.CreatedByPersonID
		INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID AND ptp.PropertyID = pn.PropertyID
		-- Employee tied to the note, leasing agent
		LEFT JOIN Person ag ON ag.PersonID = pn.CreatedByPersonID
		WHERE pro.ProspectID IN (SELECT ProspectID FROM #ProspectIDs)
		AND (@startDate IS NULL
			OR pn.[Date] >=  @startDate)
		AND (@endDate IS NULL
			OR pn.[Date] <= @endDate)
		AND pn.PropertyID = @propertyID
		AND pt.[Type] = 'Employee'
		ORDER BY pn.[Date], pn.DateCreated

	-- Pets
	INSERT INTO #ProspectPets
		SELECT pro.ProspectID,
		pet.[Type],
		pet.Name,
		pet.Notes,
		pet.[Weight]
		FROM Pet pet
		INNER JOIN Person per on per.PersonID = pet.PersonID
		INNER JOIN Prospect pro on pro.PersonID = per.PersonID
		WHERE pro.ProspectID IN (SELECT ProspectID FROM #ProspectIDs)

	-- Desired Units
	INSERT INTO #DesiredUnits
		SELECT pro.ProspectID,
		u.[Number]
		FROM Prospect pro
		INNER JOIN ProspectUnit pu on pro.ProspectID = pu.ProspectID
		INNER JOIN Unit u on pu.UnitID = u.UnitID
		WHERE pro.ProspectID IN (SELECT ProspectID FROM #ProspectIDs)

	-- Events
	INSERT INTO #ProspectEvents
		SELECT pro.ProspectID,
		e.EventID,
		e.Start,
		e.Title,
		e.[Description],
		person.PersonID AS 'AgentPersonID',
		person.FirstName AS 'AgentFirstName',
		person.LastName AS 'AgentLastName'
		FROM Prospect pro
		INNER JOIN [Event] e ON pro.PersonID = e.ObjectID
		OUTER APPLY (SELECT TOP 1 p.PersonID, p.FirstName, p.LastName
					 FROM EventAttendee ea
					 LEFT JOIN [User] u ON ea.ObjectID = u.UserID
					 LEFT JOIN Person p ON u.PersonID = p.PersonID
					 WHERE ea.EventID = e.EventID) AS person
		WHERE e.ObjectType = 'Prospect'
			AND pro.ProspectID IN (SELECT ProspectID FROM #ProspectIDs)

	SELECT *
	FROM #ProspectPeople

	SELECT *
	FROM #ProspectPreferences

	SELECT *
	FROM #ProspectPersonNotes

	SELECT * 
	FROM #ProspectPets

	SELECT *
	FROM #DesiredUnits

	SELECT *
	FROM #ProspectEvents
	
END
GO
