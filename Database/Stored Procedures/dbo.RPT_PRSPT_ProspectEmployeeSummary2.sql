SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[RPT_PRSPT_ProspectEmployeeSummary2] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	
	
	CREATE TABLE #ProspectEmployeeSummary (
		PersonID uniqueidentifier not null,
		PropertyName nvarchar(500) not null,
		CreatedByPersonTypePropertyID uniqueidentifier not null,
		EmployeeName nvarchar(100) not null,
		ChatContacts int null,
		EmailContacts int null,
		PhoneContacts int null,
		TextContacts int null,
		FaceToFaceContacts int null,
		NewUnitsShown int null,				
		DistinctProspectCount int null,		
		NewFaceToFaceProspectCount int null,
		ReturnedFaceToFaceProspectCount int null,
		FaceToFaceConversion int null,
		NewLeases int null,
		LeasedUponReturn int null,
		LeasesCancelled int null)
	
	CREATE TABLE #NewLeases (
		LeaseID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		ResponsiblePersonID uniqueidentifier not null,
		ProspectID uniqueidentifier not null,
		MainPersonID uniqueidentifier not null,
		RoomieID uniqueidentifier not null,
		UnitShownDate date,
		LeaseStatus nvarchar(100))
	
	--DECLARE @start datetime = getdate()
	--DECLARE @diff bigint = 0
	
	INSERT #ProspectEmployeeSummary
		SELECT  DISTINCT				
				p.PersonID AS 'PersonID', 
				pro.Name AS 'PropertyName',
				ptp.PersonTypePropertyID AS 'CreatedByPersonTypePropertyID',
				p.PreferredName + ' ' + p.LastName AS 'EmployeeName',
				null AS 'ChatContacts', 
				null AS 'EmailContacts', 
				null AS 'PhoneContacts', 
				null AS 'TextContacts',
				null AS 'FaceToFaceContacts', 
				null AS 'NewUnitsShown',				
				0 AS 'DistinctProspectCount',
				null AS 'NewFaceToFaceProspectCount', 
				null AS 'ReturnedFaceToFaceProspectCount',
				null AS 'FaceToFaceConversion',	
				null AS 'NewLeases', 
				null AS 'LeasedUponReturn', 
				null AS 'LeasesCancelled'
			FROM PersonType pt
				INNER JOIN PersonTypeProperty ptp on pt.PersonTypeID = ptp.PersonTypeID
				INNER JOIN Property pro ON pro.PropertyID = ptp.PropertyID
				INNER JOIN Person p on pt.PersonID = p.PersonID
			WHERE ptp.PropertyID IN (SELECT Value FROM @propertyIDs)	
				  AND pt.[Type] = 'Employee'			
		
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Load people - ' + CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET ChatContacts = (SELECT COUNT(*)
				FROM PersonNote
				WHERE CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
				  AND ContactType = 'Chat'
				  AND PersonType = 'Prospect'
				  AND [Date] >= @startDate
				  AND [Date] <= @endDate)
				  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Chats - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
				  
	UPDATE #ProspectEmployeeSummary SET EmailContacts = (SELECT COUNT(*)
				FROM PersonNote
				WHERE CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
				  AND ContactType = 'Email'
				  AND PersonType = 'Prospect'
				  AND [Date] >= @startDate
				  AND [Date] <= @endDate)
			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Emails - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET PhoneContacts = (SELECT COUNT(*)
				FROM PersonNote
				WHERE CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
				  AND ContactType = 'Phone'
				  AND PersonType = 'Prospect'
				  AND [Date] >= @startDate
				  AND [Date] <= @endDate)
							  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Phone - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET TextContacts = (SELECT COUNT(*)
				FROM PersonNote
				WHERE CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
				  AND ContactType = 'Text Message'
				  AND PersonType = 'Prospect'
				  AND [Date] >= @startDate
				  AND [Date] <= @endDate)
				  			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Text - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET FaceToFaceContacts = (SELECT COUNT(*)
																FROM PersonNote
																WHERE CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
																  AND ContactType = 'Face-to-Face'
																  AND PersonType = 'Prospect'
																  AND [Date] >= @startDate
																  AND [Date] <= @endDate)				  
																  			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'FtF - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	-- Only count the first unit shown interaction
	UPDATE #ProspectEmployeeSummary SET NewUnitsShown = (SELECT COUNT(DISTINCT PersonID)
															FROM PersonNote pn
															WHERE CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID															  
															  AND pn.PersonType = 'Prospect'
															  AND pn.[Date] >= @startDate
															  AND pn.[Date] <= @endDate
															  AND pn.InteractionType IN ('Unit Shown', 'Application')
															  AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																					 FROM PersonNote pn2 
																					 WHERE pn2.PersonID = pn.PersonID 																						   
																						   AND pn2.PersonType = 'Prospect'
																						   AND pn2.InteractionType IN ('Unit Shown', 'Application')
																					 ORDER BY [Date], DateCreated))

			  			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Units Shown - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET DistinctProspectCount = (SELECT COUNT(DISTINCT PersonID)
																FROM PersonNote
																WHERE CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
																  AND PersonType = 'Prospect'
																  AND [Date] >= @startDate
																  AND [Date] <= @endDate)
								  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Distinct prospect count - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()					  	

	UPDATE #ProspectEmployeeSummary SET NewFaceToFaceProspectCount = (SELECT COUNT(*)
																	FROM PersonNote pn
																		INNER JOIN PersonTypeProperty ptp ON pn.CreatedByPersonTypePropertyID = ptp.PersonTypePropertyID
																		--INNER JOIN Property p ON ptp.PropertyID = p.PropertyID
																	WHERE pn.CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
																	  --AND p.Name = #ProspectEmployeeSummary.PropertyName
																	  AND pn.PersonType = 'Prospect'
																	  AND pn.ContactType = 'Face-to-Face'																	  
																	  AND pn.[Date] >= @startDate
																	  AND pn.[Date] <= @endDate
																	  -- Make sure this Face-to-Face contact is the first Face-to-Face contact
																	  AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																							 FROM PersonNote pn2 
																							 WHERE pn2.PersonID = pn.PersonID 
																								   AND pn2.PersonType = 'Prospect'
																								   AND pn2.ContactType = 'Face-to-Face'																								   
																							 ORDER BY [Date], DateCreated))

			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'New face to face - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET ReturnedFaceToFaceProspectCount = (SELECT COUNT(*)
																			FROM PersonNote pn
																				INNER JOIN PersonTypeProperty ptp ON pn.CreatedByPersonTypePropertyID = ptp.PersonTypePropertyID
																				--INNER JOIN Property p ON ptp.PropertyID = p.PropertyID
																			WHERE pn.CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
																			  --AND p.Name = #ProspectEmployeeSummary.PropertyName
																			  AND pn.PersonType = 'Prospect'
																			  AND pn.ContactType = 'Face-to-Face'																			  
																			  AND pn.[Date] >= @startDate
																			  AND pn.[Date] <= @endDate
																			  -- Make sure this Face-to-Face contact is the first Face-to-Face contact
																			  AND pn.PersonNoteID <> (SELECT TOP 1 pn2.PersonNoteID 
																									 FROM PersonNote pn2 
																									 WHERE pn2.PersonID = pn.PersonID 
																										   AND pn2.ContactType = 'Face-to-Face'
																										   AND pn2.PersonType = 'Prospect'
																									 ORDER BY [Date], DateCreated))
						  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'return ftf - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()							 				  
						
												
	UPDATE #ProspectEmployeeSummary SET FaceToFaceConversion = (SELECT COUNT(*)
																FROM PersonNote pn
																	INNER JOIN PersonTypeProperty ptp ON pn.CreatedByPersonTypePropertyID = ptp.PersonTypePropertyID
																	--INNER JOIN Property p ON ptp.PropertyID = p.PropertyID	
																	LEFT JOIN PersonNote pn3 ON pn3.PersonID = pn.PersonID AND pn3.ContactType <> 'Face-to-Face' AND pn3.PersonType = 'Prospect' AND pn3.[Date] <= pn.[Date]				
																WHERE pn.CreatedByPersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
																  --AND p.Name = #ProspectEmployeeSummary.PropertyName
																  AND pn.PersonType = 'Prospect'
																  AND pn.ContactType = 'Face-to-Face'																  
																  AND pn.[Date] >= @startDate
																  AND pn.[Date] <= @endDate
																  -- Make sure this Face-to-Face contact is the first Face-to-Face contact
																  AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																						 FROM PersonNote pn2 
																						 WHERE pn2.PersonID = pn.PersonID 
																							   AND pn2.PersonType = 'Prospect'
																							   AND pn2.ContactType = 'Face-to-Face'																							   
																						 ORDER BY [Date], DateCreated)
																  ---- Ensure there was a non-face-to-face contact made before the
																  ---- face-to-face contact	
																  AND pn3.PersonNoteID = (SELECT TOP 1 pn4.PersonNoteID 
																						 FROM PersonNote pn4 
																						 WHERE pn4.PersonID = pn.PersonID 
																							   AND pn4.PersonType = 'Prospect'
																							   AND pn4.ContactType <> 'Face-to-Face'																							   
																							   AND pn3.[Date] <= pn.[Date]
																						 ORDER BY [Date], DateCreated)
																  AND pn3.PersonNoteID IS NOT NULL)										 				 
																  
								  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'FTF conversion - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()					 				  
	
	-- Get all the prospects that applied for a lease within the date range				  				  
	INSERT #NewLeases 
		SELECT	l.LeaseID AS 'LeaseID', 
				ulg.UnitID AS 'UnitID', 
				ppt.ResponsiblePersonTypePropertyID AS 'ResponsiblePersonID',
				ppt.ProspectID AS 'ProspectID', 
				ppt.PersonID AS 'MainPersonID', 
				ppt.PersonID AS 'RoomieID', 
				-- If the resident wasn't shown a unit then use the Application Date
				-- as the date it was shown
				COALESCE(pn.[Date], pl.ApplicationDate) AS 'UnitShownDate', 
				l.LeaseStatus
			FROM Lease l
				INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID
				INNER JOIN Person p ON pl.PersonID = p.PersonID
				INNER JOIN Prospect ppt	ON p.PersonID = ppt.PersonID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				LEFT JOIN PersonNote pn ON pn.PersonID = p.PersonID	AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																							 FROM PersonNote pn2
																							 WHERE pn2.PersonID = pn.PersonID 
																								   AND pn2.PersonType = 'Prospect'											   
																								   AND pn2.InteractionType IN ('Unit Shown', 'Application')
																							 ORDER BY [Date], DateCreated)						
			WHERE 
				-- Make sure we only take into account the first lease in a given unit lease group
				pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID ORDER BY ApplicationDate)
				AND l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)				
				-- Ensure we only get leases that actually applied during the date range
				AND pl.ApplicationDate >= @startDate
				AND pl.ApplicationDate <= @endDate			  			  			  			  
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL				
			  			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'P Lesaes - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
			  
	INSERT #NewLeases 
		SELECT	l.LeaseID AS 'LeaseID', 
				ulg.UnitID AS 'UnitID', 
				ppt.ResponsiblePersonTypePropertyID AS 'ResponsiblePersonID',
				ppt.ProspectID AS 'ProspectID', 
				ppt.PersonID AS 'MainPersonID', 
				proom.PersonID AS 'RoomieID', 
				-- If the resident wasn't shown a unit then use the Application Date
				-- as the date it was shown
				COALESCE(pn.[Date], pl.ApplicationDate) AS 'UnitShownDate', 
				l.LeaseStatus
			FROM Lease l
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
				INNER JOIN Person p ON pl.PersonID = p.PersonID
				INNER JOIN ProspectRoommate proom ON p.PersonID = proom.PersonID
				INNER JOIN Prospect ppt ON proom.ProspectID = ppt.ProspectID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				LEFT JOIN PersonNote pn ON pn.PersonID = p.PersonID	AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																							 FROM PersonNote pn2
																							 WHERE pn2.PersonID = pn.PersonID 
																								   AND pn2.PersonType = 'Prospect'											   
																								   AND pn2.InteractionType IN ('Unit Shown', 'Application')
																							 ORDER BY [Date], DateCreated)	
			WHERE 
			  -- Make sure we only take into account the first lease in a given unit lease group
			  pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID ORDER BY ApplicationDate)			  
			  AND l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
			  -- Ensure we only get leases that actually applied during the date range
			  AND pl.ApplicationDate >= @startDate
			  AND pl.ApplicationDate <= @endDate				  			  			  
			  -- Make sure we don't take into account transferred residents
			  AND ulg.PreviousUnitLeaseGroupID IS NULL			
				  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'RM Leases - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
		
	UPDATE #ProspectEmployeeSummary SET NewLeases = (SELECT COUNT (DISTINCT LeaseID) 
						FROM #NewLeases
						WHERE ResponsiblePersonID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
							AND #NewLeases.UnitShownDate >= @startDate)
							
	UPDATE #ProspectEmployeeSummary SET LeasedUponReturn = (SELECT COUNT (DISTINCT LeaseID) 
						FROM #NewLeases
						WHERE ResponsiblePersonID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID
							AND #NewLeases.UnitShownDate < @startDate)							
						
			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Leases - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	CREATE TABLE #CancelledLeases
	(
		LeaseID uniqueidentifier,
		ResponsiblePersonTypePropertyID uniqueidentifier
	)
	
	INSERT #CancelledLeases 
		SELECT	l.LeaseID AS 'LeaseID', 				
				ppt.ResponsiblePersonTypePropertyID AS 'ResponsiblePersonID'
			FROM Lease l
				INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID
				INNER JOIN Person p ON pl.PersonID = p.PersonID
				INNER JOIN Prospect ppt	ON p.PersonID = ppt.PersonID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID				
			WHERE 
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
				AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID ORDER BY MoveOutDate DESC)			  
				AND l.LeaseStatus = 'Cancelled'
				-- Ensure we only get leases that actually applied during the date range
				AND pl.MoveOutDate >= @startDate
				AND pl.MoveOutDate <= @endDate
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL
	
	INSERT #CancelledLeases
		SELECT	l.LeaseID AS 'LeaseID', 				
					ppt.ResponsiblePersonTypePropertyID AS 'ResponsiblePersonID'				
				FROM Lease l
					INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
					INNER JOIN Person p ON pl.PersonID = p.PersonID
					INNER JOIN ProspectRoommate proom ON p.PersonID = proom.PersonID
					INNER JOIN Prospect ppt ON proom.ProspectID = ppt.ProspectID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID				
				WHERE 
				  -- Make sure we only take into account the first lease in a given unit lease group
				  pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID ORDER BY MoveOutDate DESC)			  
				  AND l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
				  AND l.LeaseStatus = 'Cancelled'
				  -- Ensure we only get leases that actually cancelled during the date range
				  AND pl.MoveOutDate >= @startDate
				  AND pl.MoveOutDate <= @endDate				  			  			  
				  -- Make sure we don't take into account transferred residents
				  AND ulg.PreviousUnitLeaseGroupID IS NULL			  			  
	
	UPDATE #ProspectEmployeeSummary SET LeasesCancelled = (SELECT COUNT (DISTINCT LeaseID) 
						FROM #CancelledLeases
						WHERE ResponsiblePersonTypePropertyID = #ProspectEmployeeSummary.CreatedByPersonTypePropertyID)
	
							  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Cancelled leases - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()  
	
	SELECT  DISTINCT
			PersonID AS 'PersonID',
			PropertyName As 'PropertyName',
			EmployeeName AS 'EmployeeName',
			ChatContacts AS 'ChatContacts',
			EmailContacts AS 'EmailContacts',
			PhoneContacts AS 'PhoneContacts',
			TextContacts AS 'TextContacts',
			FaceToFaceContacts AS 'FaceToFaceContacts',
			NewUnitsShown AS 'NewUnitsShown',
			--UnitsShownOffset AS 'UnitsShownOffset',
			--AverageContactsPerProspect AS 'AverageContactsPerProspect',
			DistinctProspectCount AS 'DistinctProspectCount',
			NewFaceToFaceProspectCount AS 'NewFaceToFaceProspectCount',
			ReturnedFaceToFaceProspectCount AS 'ReturnedFaceToFaceProspectCount',
			FaceToFaceConversion AS 'FaceToFaceConversion',			
			NewLeases,
			LeasedUponReturn,
			LeasesCancelled AS 'LeasesCancelled'
		FROM #ProspectEmployeeSummary
		WHERE ChatContacts <> 0 
			  OR EmailContacts <> 0
			  OR PhoneContacts <> 0
			  OR TextContacts <> 0
			  OR FaceToFaceContacts <> 0
			  OR NewUnitsShown <> 0
			  --OR UnitsShownOffset <> 0
			  OR DistinctProspectCount <> 0
			  OR NewFaceToFaceProspectCount <> 0
			  OR ReturnedFaceToFaceProspectCount <> 0
			  OR FaceToFaceConversion <> 0
			  OR NewLeases <> 0
			  OR LeasedUponReturn <> 0
			  OR LeasesCancelled <> 0
END
GO
