SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO














-- =============================================
-- Author:		Nick Olsen
-- Create date: March 13, 2012
-- Description:	Gets a pages list of prospects
-- =============================================
CREATE PROCEDURE [dbo].[GetListProspects]	
	@propertyID uniqueidentifier,
	@startDate date,
	@endDate date,
	@letter char(1),
	@pageSize int,
	@page int,	
	@totalCount int OUTPUT,
	@sortBy nvarchar(50) = null,
	@sortOrderIsAsc bit = null,
	@includeLost bit,
	@includeApplied bit = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #Prospects
	(
		MainPersonID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		PropertyAbbreviation nvarchar(10) not null,
		PersonID uniqueidentifier null,
		LastContact date not null,
		Name nvarchar(100) not null,
		MovingFrom nvarchar(100) null,
		Phone nvarchar(50) null,
		Email nvarchar(200) null,
		LeasingAgent nvarchar(200) null,
		LeasingAgentID uniqueidentifier null,
		LostProspect bit not null,
		ProspectID uniqueidentifier not null,
		Applied bit null,
		DateNeeded date null,
		PhoneType nvarchar(10) null
	)
	
	INSERT INTO #Prospects
		SELECT Prospect.PersonID AS 'MainPersonID',
			   prop.PropertyID,
			   prop.Abbreviation AS 'PropertyAbbreviation',
			   Person.PersonID,
			   pn.[Date] AS 'LastContact',
			  (Person.LastName + ', ' + Person.PreferredName) AS 'Name',
			   Prospect.MovingFrom,
			   Person.Phone1 AS 'Phone',
			   Person.Email,
			  (la.PreferredName + ' ' + la.LastName) AS 'LeasingAgent',
			   la.PersonID as 'LeasingAgentID',
			  case when prospect.LostReasonPickListItemID is null then cast(0 as bit) else
					cast (1 as bit) end as 'LostProspect',
				Prospect.ProspectID,
				0 AS 'Applied',
				Prospect.DateNeeded,
				Person.Phone1Type AS 'PhoneType'
		FROM Prospect
		INNER JOIN Person on Person.PersonID = Prospect.PersonID
		INNER JOIN PropertyProspectSource pps on pps.PropertyProspectSourceID = Prospect.PropertyProspectSourceID
		INNER JOIN Property prop on pps.PropertyID = prop.PropertyID
		INNER JOIN PersonNote pn on pn.PersonID = Person.PersonID
		LEFT JOIN PersonTypeProperty ptp on ptp.PersonTypePropertyID = Prospect.ResponsiblePersonTypePropertyID
		LEFT JOIN PersonType pt on ptp.PersonTypeID = pt.PersonTypeID
		LEFT JOIN Person la on la.PersonID = pt.PersonID
		WHERE prop.PropertyID = @propertyID 
			  AND pn.[Date] >= @startDate
			  AND pn.[Date] <= @endDate	
			  -- Either no letter is specified or the last name starts with the given letter
			  AND ((@letter IS NULL) OR (Person.LastName LIKE (@letter + '%')))
			  -- Only select the latest person note
			  AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID
									 FROM PersonNote pn2
										--INNER JOIN PersonTypeProperty ptp2 ON ptp2.PersonTypePropertyID = pn2.CreatedByPersonTypePropertyID
									 WHERE pn2.PersonID = Person.PersonID
										   --AND ptp2.PropertyID = @propertyID
										   AND pn2.PropertyID = @propertyID
										   AND pn2.PersonType = 'Prospect'
										   --AND pn2.InteractionType IN ('Unit Not Shown','Follow-Up','Unit Shown', 'Email')
										   AND (pn2.ContactType <> 'N/A' OR pn2.InteractionType = 'Transfer') -- Do not include notes that were not contacts
									 ORDER BY pn2.[Date] DESC)
			 AND ((@includeLost = 1) or (Prospect.LostReasonPickListItemID is null))

	INSERT INTO #Prospects
		SELECT Prospect.PersonID AS 'MainPersonID',
			   prop.PropertyID,
			   prop.Abbreviation AS 'PropertyAbbreviation',
			   Person.PersonID,
			   pn.[Date] AS 'LastContact',
			  (Person.LastName + ', ' + Person.PreferredName) AS 'Name',
			   Prospect.MovingFrom,
			   Person.Phone1 AS 'Phone',
			   Person.Email,
			  (la.PreferredName + ' ' + la.LastName) AS 'LeasingAgent',
			   la.PersonID as 'LeasingAgentID',
			  case when prospect.LostReasonPickListItemID is null then cast(0 as bit) else
					cast (1 as bit) end as 'LostProspect',
				Prospect.ProspectID,
				0 AS 'Applied',
				Prospect.DateNeeded,
				Person.Phone1Type AS 'PhoneType'
		FROM ProspectRoommate	
		INNER JOIN Person on Person.PersonID = ProspectRoommate.PersonID
		INNER JOIN Prospect on ProspectRoommate.ProspectID = Prospect.ProspectID
		INNER JOIN PropertyProspectSource pps on pps.PropertyProspectSourceID = Prospect.PropertyProspectSourceID
		INNER JOIN Property prop on pps.PropertyID = prop.PropertyID
		INNER JOIN PersonNote pn on pn.PersonID = Prospect.PersonID
		LEFT JOIN PersonTypeProperty ptp on ptp.PersonTypePropertyID = Prospect.ResponsiblePersonTypePropertyID
		LEFT JOIN PersonType pt on ptp.PersonTypeID = pt.PersonTypeID
		LEFT JOIN Person la on la.PersonID = pt.PersonID
		WHERE prop.PropertyID = @propertyID 

			  AND pn.[Date] >= @startDate
			  AND pn.[Date] <= @endDate
			  -- Either no letter is specified or the last name starts with the given letter
			  AND ((@letter IS NULL) OR (Person.LastName LIKE (@letter + '%')))
			  -- Only select the latest person note
			  AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID
									 FROM PersonNote pn2
										--INNER JOIN PersonTypeProperty ptp2 ON ptp2.PersonTypePropertyID = pn2.CreatedByPersonTypePropertyID
									 WHERE pn2.PersonID = Prospect.PersonID
										   AND pn2.PersonType = 'Prospect'
										   AND pn2.PropertyID = @propertyID
										   --AND pn2.InteractionType IN ('Unit Not Shown','Follow-Up','Unit Shown', 'Email')
										   AND (pn2.ContactType <> 'N/A' OR pn2.InteractionType = 'Transfer') -- Do not include notes that were not contacts
									 ORDER BY pn2.[Date] DESC)
				AND ((@includeLost = 1) or (Prospect.LostReasonPickListItemID is null))
				
	--IF ((@includeLeased IS NULL) OR (@includeLeased = 0))
	--BEGIN
	-- [Table]1 is the main person
	-- [Table] is the roommate
	-- 3/27/2014: Even if the lease was cancelled, we want to show the person as applied
		UPDATE #pros SET #pros.Applied = 1
			FROM #Prospects #pros
				LEFT JOIN PersonLease pl ON #pros.PersonID = pl.PersonID-- AND pl.ResidencyStatus NOT IN ('Cancelled')
				LEFT JOIN PersonLease pl1 ON #pros.MainPersonID = pl1.PersonID-- AND pl1.ResidencyStatus NOT IN ('Cancelled')
				LEFT JOIN Lease l ON pl.LeaseID = l.LeaseID
				LEFT JOIN Lease l1 ON pl1.LeaseID = l1.LeaseID
				LEFT JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				LEFT JOIN UnitLeaseGroup ulg1 ON l1.UnitLeaseGroupID = ulg1.UnitLeaseGroupID 
				LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
				LEFT JOIN Unit u1 ON ulg1.UnitID = u1.UnitID
				LEFT JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
				LEFT JOIN UnitType ut1 ON u1.UnitTypeID = ut1.UnitTypeID AND ut1.PropertyID = @propertyID
			WHERE ut.UnitTypeID IS NOT NULL
			   OR ut1.UnitTypeID IS NOT NULL
	--END
				
	CREATE TABLE #Prospects2
	(
		id int identity,
		MainPersonID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		PropertyAbbreviation nvarchar(10) not null,
		PersonID uniqueidentifier null,
		LastContact date not null,
		Name nvarchar(100) not null,
		MovingFrom nvarchar(100) null,
		Phone nvarchar(50) null,
		Email nvarchar(200) null,
		LeasingAgent nvarchar(200) null,
		LeasingAgentID uniqueidentifier null,
		LostProspect bit not null,
		ProspectID uniqueidentifier not null,
		Applied bit not null,
		DateNeeded Date null,
		PhoneType nvarchar(10) null
	)
	INSERT INTO #Prospects2 
		SELECT * 
		FROM #Prospects
		WHERE (@includeApplied = 1 OR #Prospects.Applied = 0)
		ORDER BY
			CASE WHEN @sortBy = 'Name' and @sortOrderIsAsc = 1  THEN [Name] END ASC,
			CASE WHEN @sortBy = 'Name' and @sortOrderIsAsc = 0  THEN [Name] END DESC,
			CASE WHEN @sortBy = 'LastContact' and @sortOrderIsAsc = 1  THEN [LastContact] END ASC,
			CASE WHEN @sortBy = 'LastContact' and @sortOrderIsAsc = 0  THEN [LastContact] END DESC,
			CASE WHEN @sortBy = 'MovingFrom' and @sortOrderIsAsc = 1  THEN [MovingFrom] END ASC,
			CASE WHEN @sortBy = 'MovingFrom' and @sortOrderIsAsc = 0  THEN [MovingFrom] END DESC,
			CASE WHEN @sortBy = 'PhoneNumber' and @sortOrderIsAsc = 1  THEN [Phone] END ASC,
			CASE WHEN @sortBy = 'PhoneNumber' and @sortOrderIsAsc = 0  THEN [Phone] END DESC,
			CASE WHEN @sortBy = 'Email' and @sortOrderIsAsc = 1  THEN [Email] END ASC,
			CASE WHEN @sortBy = 'Email' and @sortOrderIsAsc = 0  THEN [Email] END DESC,
			CASE WHEN @sortBy = 'LeasingAgent' and @sortOrderIsAsc = 1  THEN [LeasingAgent] END ASC,
			CASE WHEN @sortBy = 'LeasingAgent' and @sortOrderIsAsc = 0  THEN [LeasingAgent] END DESC,
			CASE WHEN @sortBy = 'LostProspect' and @sortOrderIsAsc = 1  THEN [LostProspect] END ASC,
			CASE WHEN @sortBy = 'LostProspect' and @sortOrderIsAsc = 0  THEN [LostProspect] END DESC,
			CASE WHEN @sortBy = 'AppliedProspect' and @sortOrderIsAsc = 1  THEN [Applied] END ASC,
			CASE WHEN @sortBy = 'AppliedProspect' and @sortOrderIsAsc = 0  THEN [Applied] END DESC,
			CASE WHEN @sortBy = 'DateNeeded' and @sortOrderIsAsc = 1 THEN [DateNeeded] END ASC,
			CASE WHEN @sortBy = 'DateNeeded' and @sortOrderIsAsc = 0 THEN [DateNeeded] END DESC, 
			CASE WHEN (@sortBy is NULL OR @sortBy = '') and @sortOrderIsAsc = 1  THEN [Name] END ASC,
			CASE WHEN (@sortBy is NULL OR @sortBy = '') and @sortOrderIsAsc = 0  THEN [Name] END DESC

	SET @totalCount = (SELECT COUNT(*) FROM #Prospects2)

	SELECT TOP (@pageSize) * FROM 
	(SELECT *, row_number() OVER (ORDER BY id) AS [rownumber] 
	 FROM #Prospects2) AS PagedProspects	 
	WHERE PagedProspects.rownumber > (((@page - 1) * @pageSize))
	
END
GO
