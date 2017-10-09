SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 4/3/2014
-- Description:	Gets a persons leads
-- =============================================
CREATE PROCEDURE [dbo].[GetLeads] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@employeePersonID uniqueidentifier,
	@leadPersonID uniqueidentifier,
	@unitTypeID uniqueidentifier,
	@propertyIDs GuidCollection READONLY,
	@lastActivity int = null,
	@localDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	CREATE TABLE #PersonTypePropertyIDs ( PersonTypePropertyID uniqueidentifier)
	INSERT INTO #PersonTypePropertyIDs
		SELECT ptp.PersonTypePropertyID 
		FROM PersonTypeProperty ptp
		INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
		INNER JOIN #PropertyIDs #pids ON ptp.PropertyID = #pids.PropertyID
		WHERE ptp.HasAccess = 1
		  AND pt.[Type] = 'Employee'
		  AND (@employeePersonID IS NULL OR pt.PersonID = @employeePersonID)

	--select * from #PersonTypePropertyIDs

	CREATE TABLE #Leads
	(
		PropertyID uniqueidentifier not null,
		PropertyAbbreviation nvarchar(10) not null,
		PersonID uniqueidentifier null,
		[Status] nvarchar(20) not null,
		Unit nvarchar(50) null,
		UnitID uniqueidentifier null,
		DateReceivedOrApplied date not null,
		MoveInDate date null,
		LastActivity date not null,
		LastNote nvarchar(max) null,
		LastNoteDescription nvarchar(200) null,
		LastContactType nvarchar(20) null,
		NextFollowUpDueDate date null,
		NextFollowUpDescription nvarchar(250) null,
		NextFollowUpTaskID uniqueidentifier null,
		Name nvarchar(250) not null,
		Phone nvarchar(50) null,
		Email nvarchar(200) null,
		ObjectID uniqueidentifier not null,
		PersonType nvarchar(20) not null,
		IsScreened bit not null,
		HasSignedLease bit not null,
		LeaseIsCreated bit not null,
		UnitLeaseGroupID uniqueidentifier null
	)
	
	-- Gets all prospects assigned to the person
	INSERT INTO #Leads
		SELECT DISTINCT
			   prop.PropertyID,
			   prop.Abbreviation AS 'PropertyAbbreviation',
			   Person.PersonID AS 'PersonID',
			   'Prospect' AS 'Status',
			   NULL AS 'Unit',
			   NULL AS 'UnitID',
			   firstNote.[Date] AS 'DateReceivedOrApplied',
			   Prospect.DateNeeded AS 'MoveInDate',
			   lastNote.[Date] AS 'LastActivity',
			   --DATEDIFF(DAY, lastNote.[Date], @localDate) AS 'LastActivity',
			   lastNote.Note AS 'LastNote',
			   lastNote.[Description] AS 'LastNoteDescription',
			   lastNote.ContactType AS 'LastContactType',
			   at.DateDue AS 'NextFollowUpDueDate',
			   at.[Subject] AS 'NextFollowUpDescription',
			   at.AlertTaskID AS 'NextFollowUpTaskID',
			  (Person.LastName + ', ' + Person.PreferredName) AS 'Name',
			   Person.Phone1 AS 'Phone',
			   Person.Email,
			   Prospect.ProspectID AS 'ObjectID',
			   'Prospect' AS 'PersonType',
			   0 AS 'IsScreened',
		       0 AS 'HasSignedLease',
			   0 AS 'LeaseIsCreated',
			   NULL AS 'UnitLeaseGroupID'
		FROM Prospect
			INNER JOIN #PersonTypePropertyIDs #ptpids ON Prospect.ResponsiblePersonTypePropertyID = #ptpids.PersonTypePropertyID
			INNER JOIN Person on Person.PersonID = Prospect.PersonID
			INNER JOIN PropertyProspectSource pps on pps.PropertyProspectSourceID = Prospect.PropertyProspectSourceID
			INNER JOIN Property prop on pps.PropertyID = prop.PropertyID
			INNER JOIN PersonNote lastNote on lastNote.PersonNoteID = Prospect.LastPersonNoteID
			INNER JOIN PersonNote firstNote on firstNote.PersonNoteID = Prospect.FirstPersonNoteID
			LEFT JOIN ProspectUnitType put ON put.ProspectID = Prospect.ProspectID
			LEFT JOIN AlertTask at on at.AlertTaskID = Prospect.NextAlertTaskID
			-- Checking to make sure the prospect wasn't converted to an applicant/resident
			-- at this same property
			LEFT JOIN PersonType residentPT ON residentPT.PersonID = Person.PersonID AND residentPT.[Type] = 'Resident'
			LEFT JOIN PersonTypeProperty rptp ON rptp.PersonTypeID = residentPT.PersonTypeID AND rptp.PropertyID = pps.PropertyID
			INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = prop.PropertyID
		WHERE Prospect.LostReasonPickListItemID is null
		  AND (@leadPersonID IS NULL OR Person.PersonID = @leadPersonID)
		  AND (@unitTypeID IS NULL OR put.UnitTypeID = @unitTypeID)
		  -- Make sure there is no Resident PersonType
		  AND rptp.PersonTypePropertyID IS NULL
		  AND (@lastActivity IS NULL
			   OR
			   DATEDIFF(DAY, lastNote.[Date], @localDate) <= @lastActivity)	
		 
		 
	-- Get applicants
	INSERT INTO #Leads
		SELECT DISTINCT
			p.PropertyID AS 'PropertyID',
			p.Abbreviation AS 'PropertyAbbreviation',
			mainPL.PersonID AS 'PersonID',
			CASE 
				WHEN 
				   (SELECT COUNT(*)
					FROM PersonLease pl
					WHERE pl.LeaseID = l.LeaseID
					 AND pl.ResidencyStatus = 'Approved') = 0
				THEN 'Pending'
				ELSE 'Approved'
			END AS 'Status',
			u.Number AS 'Unit',
			u.UnitID AS 'UnitID',
		   (SELECT MIN(pl.ApplicationDate)
			FROM PersonLease pl
			WHERE pl.LeaseID = l.LeaseID) AS 'DateReceivedOrApplied',
		   (SELECT MIN(pl.MoveInDate)
		    FROM PersonLease pl
		    WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
			ISNULL(lastNote.[Date], l.DateCreated) AS 'LastActivity', 
			--DATEDIFF(DAY, ISNULL(lastNote.[Date], l.DateCreated), @localDate) AS 'LastActivity',
			lastNote.Note AS 'LastNote',
			lastNote.[Description] AS 'LastNoteDescription',
			lastNote.ContactType AS 'LastContactType',
			at.DateDue AS 'NextFollowUpDueDate',
			at.[Subject] AS 'NextFollowUpDescription',
			at.AlertTaskID AS 'NextFollowUpTaskID',
			LEFT(STUFF(ISNULL((SELECT '; ' + (p2.LastName + ', ' + p2.PreferredName)
							   FROM Person p2
								   INNER JOIN PersonLease pl2 ON p2.PersonID = pl2.PersonID		
							   WHERE pl2.LeaseID = l.LeaseID
						         AND pl2.MainContact = 1				   
							   FOR XML PATH ('')), 
							   --If there were no main contacts then we need to just get everyone.
							  (SELECT '; ' + (p2.LastName + ', ' + p2.PreferredName)
							   FROM Person p2
								   INNER JOIN PersonLease pl2 ON p2.PersonID = pl2.PersonID		
							   WHERE pl2.LeaseID = l.LeaseID			   
							   FOR XML PATH (''))), 1, 2, ''), 250) AS 'Name',
		   mainP.Phone1 AS 'Phone',
		   mainP.Email AS 'Email',
		   l.LeaseID AS 'ObjectID',
		   'Resident' AS 'PersonType',
		   -- Change to check to see if anyone on the PersonLease has been screened
		   CASE 
			WHEN EXISTS (SELECT asp.ApplicantScreeningPersonID
						 FROM ApplicantScreeningPerson asp
						 INNER JOIN PersonLease aspPL ON asp.PersonID = aspPL.PersonID
		 				 WHERE aspPL.LeaseID = l.LeaseID)
			THEN 1
			ELSE 0
			END AS 'IsScreened',
		   -- Change to check to see if anyone on the PersonLease has signed
		   CASE 
			WHEN EXISTS (SELECT LeaseSignedDate
						 FROM PersonLease
						 WHERE LeaseID = l.LeaseID
						   AND LeaseSignedDate IS NOT NULL)
			THEN 1
			ELSE 0
			END AS 'HasSignedLease',
		   (l.LeaseCreated + CASE WHEN ipip.IntegrationPartnerItemPropertyID IS NULL THEN 1 ELSE 0 END) AS 'LeaseIsCreated',
		   l.UnitLeaseGroupID AS 'UnitLeaseGroupID'
		FROM Lease l
			INNER JOIN PersonLease mainPL ON mainPL.LeaseID = l.LeaseID
			INNER JOIN Person mainP ON mainP.PersonID = mainPL.PersonID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
			INNER JOIN #PropertyIDs #pids ON p.PropertyID = #pids.PropertyID
			--LEFT JOIN PersonNote lastNote ON lastNote.PersonID IN (SELECT PersonID FROM PersonLease WHERE LeaseID = l.LeaseID) AND lastNote.PersonType = 'Resident' AND lastNote.PropertyID = p.PropertyID
			LEFT JOIN PersonNote lastNote ON lastNote.PersonNoteID = ulg.LastPersonNoteID
			--LEFT JOIN AlertTask at ON at.ObjectID = l.LeaseID AND at.DateCompleted IS NULL
			LEFT JOIN AlertTask at ON at.AlertTaskID = ulg.NextAlertTaskID
			LEFT JOIN IntegrationPartnerItemProperty ipip ON ipip.PropertyID = p.PropertyID AND ipip.IntegrationPartnerItemID = 27
		WHERE l.LeaseStatus = 'Pending'
		  AND (@leadPersonID IS NULL OR mainP.PersonID = @leadPersonID)
		  AND (@employeePersonID IS NULL OR l.LeasingAgentPersonID = @employeePersonID)
		  AND (@unitTypeID IS NULL OR u.UnitTypeID = @unitTypeID)
		  AND mainPL.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
									  FROM PersonLease
									  WHERE LeaseID = l.LeaseID									    
									  ORDER BY OrderBy)
		  AND (@lastActivity IS NULL
			   OR
			   DATEDIFF(DAY, ISNULL(lastNote.[Date], l.DateCreated), @localDate) <= @lastActivity)	 
									   
			   
	SELECT * FROM #Leads
END


GO
