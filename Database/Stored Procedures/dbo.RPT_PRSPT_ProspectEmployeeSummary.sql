SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[RPT_PRSPT_ProspectEmployeeSummary] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@hideTerminatedEmployees bit = 0,
	@accountingPeriodID uniqueidentifier = null,
	@includeNonQualified bit = 1
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	
	
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	CREATE TABLE #ProspectEmployeeSummary (
		PersonID uniqueidentifier not null,
		PropertyName nvarchar(500) not null,
		PropertyID uniqueidentifier not null,
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
		EmployeePersonID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		ResponsiblePersonTypePropertyID uniqueidentifier not null,
		ProspectID uniqueidentifier null,
		MainPersonID uniqueidentifier not null,
		RoomieID uniqueidentifier null,
		UnitShownDate date,
		LeaseStatus nvarchar(100))

	DECLARE @accountID bigint
	SELECT @accountID = AccountID
		FROM Property 
		WHERE PropertyID IN (SELECT Value FROM @propertyIDs)

	DECLARE @start datetime = getdate()
	DECLARE @diff bigint = 0
	
	INSERT #ProspectEmployeeSummary
		SELECT  DISTINCT				
				p.PersonID AS 'PersonID', 
				pro.Name AS 'PropertyName',
				--ptp.PersonTypePropertyID AS 'CreatedByPersonTypePropertyID',
				pro.PropertyID AS 'PropertyID',
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
				INNER JOIN Employee e ON e.PersonID = p.PersonID
				INNER JOIN #PropertyIDs #pids on #pids.PropertyID = ptp.PropertyID
			WHERE 
				  pt.[Type] = 'Employee'			
				  AND ((@hideTerminatedEmployees = 0) OR (e.QuitDate IS NULL))
	UNION
		SELECT 
			'00000000-0000-0000-0000-000000000000',
			pro.Name AS 'PropertyName',
				--ptp.PersonTypePropertyID AS 'CreatedByPersonTypePropertyID',
				pro.PropertyID AS 'PropertyID',
				'Outside Source' AS 'EmployeeName',
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
			FROM #PropertyIDs #pids				
				INNER JOIN Property pro ON pro.PropertyID = #pids.PropertyID

		
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Load people - ' + CONVERT(nvarchar(100 ), @diff)
	--SET @start = GetDate()


	
	UPDATE #ProspectEmployeeSummary SET ChatContacts = (SELECT COUNT(*)
				FROM PersonNote pn
				INNER JOIN Prospect p ON p.PersonID = pn.PersonID
				INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
				LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID					
				WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
				  AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
					   (pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))
				  AND ContactType = 'Chat'
				  AND PersonType = 'Prospect'
				  AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
				    OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
				-- Make sure this contact is a qualified contact 
			      AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0))))
				  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Chats - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
				  
	UPDATE #ProspectEmployeeSummary SET EmailContacts = (SELECT COUNT(*)
				FROM PersonNote pn
				INNER JOIN Prospect p ON p.PersonID = pn.PersonID
				INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
				LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
				  AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
					   (pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))
				  AND pn.ContactType = 'Email'
				  AND pn.PersonType = 'Prospect'
				  AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
				    OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
					
				  -- Make sure this contact is a qualified contact 
			      AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0))))
			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Emails - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET PhoneContacts = (SELECT COUNT(*)
				FROM PersonNote pn
				INNER JOIN Prospect p ON p.PersonID = pn.PersonID
				INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
				LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
				  AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
					   (pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))
				  AND pn.ContactType = 'Phone'
				  AND pn.PersonType = 'Prospect'
				  AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
				    OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
				  
				  -- Make sure this contact is a qualified contact 
			      AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0))))
							  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Phone - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET TextContacts = (SELECT COUNT(*)
				FROM PersonNote pn
				INNER JOIN Prospect p ON p.PersonID = pn.PersonID
				INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
				LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
				  AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
					   (pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))
				  AND pn.ContactType = 'Text Message'
				  AND pn.PersonType = 'Prospect'
				  AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
				    OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
					
				  -- Make sure this contact is a qualified contact 
			      AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0))))
				  			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Text - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET FaceToFaceContacts = (SELECT COUNT(*)
																FROM PersonNote pn
																INNER JOIN Prospect p ON p.PersonID = pn.PersonID
																INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
																LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
																WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
																	AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
																		(pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))
																	AND pn.ContactType = 'Face-to-Face'
																	AND pn.PersonType = 'Prospect'
																	AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
																	OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
																	
																  -- Make sure this contact is a qualified contact 
																	 AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0))))	  			  
																  			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'FtF - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	-- Only count the first unit shown interaction
	UPDATE #ProspectEmployeeSummary SET NewUnitsShown = (SELECT COUNT(DISTINCT pn.PersonID)
															FROM PersonNote pn
															INNER JOIN Prospect p ON p.PersonID = pn.PersonID
															INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
															LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
															WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
																AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
																	(pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))
																AND pn.PersonType = 'Prospect'
																AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
																	OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
															
															-- Make sure this contact is a qualified contact 
																AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0)))
															
																AND pn.InteractionType IN ('Unit Shown', 'Application')
																AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																					 FROM PersonNote pn2 	
																					 INNER JOIN Prospect p2 ON p2.PersonID = pn2.PersonID																					
																					 WHERE pn2.PropertyID = #ProspectEmployeeSummary.PropertyID
																						   AND pn2.PersonID = pn.PersonID 																						   
																						   AND pn2.PersonType = 'Prospect'
																						   AND pn2.InteractionType IN ('Unit Shown', 'Application')
																					 ORDER BY [Date], DateCreated))

			  			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Units Shown - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	UPDATE #ProspectEmployeeSummary SET DistinctProspectCount = (SELECT COUNT(DISTINCT pn.PersonID)
																FROM PersonNote pn
																INNER JOIN Prospect p ON p.PersonID = pn.PersonID
																INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
																LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
																WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
																	AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
																		(pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))
																	AND pn.PersonType = 'Prospect'
																	AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
																	OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
																	
																 -- Make sure this contact is a qualified contact 
																	AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0))))
								  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Distinct prospect count - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()					  	

	UPDATE #ProspectEmployeeSummary SET NewFaceToFaceProspectCount = (SELECT COUNT(*)
																	FROM PersonNote pn			
																	INNER JOIN Prospect p ON p.PersonID = pn.PersonID														
																	INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
																	LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
																	WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
																		AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
																			(pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))

																		AND pn.PersonType = 'Prospect'
																		AND pn.ContactType = 'Face-to-Face'																	  
																		AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
																		OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))

																	  -- Make sure this contact is a qualified contact 
																		AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0)))

																	  -- Make sure this Face-to-Face contact is the first Face-to-Face contact
																		AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																							 FROM PersonNote pn2 
																							 INNER JOIN Prospect p2 ON p2.PersonID = pn2.PersonID
																							 WHERE pn2.PropertyID = #ProspectEmployeeSummary.PropertyID
																								   AND pn2.PersonID = pn.PersonID 
																								   AND pn2.PersonType = 'Prospect'
																								   AND pn2.ContactType = 'Face-to-Face'																								   
																							 ORDER BY [Date], DateCreated))

			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'New face to face - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
UPDATE #ProspectEmployeeSummary SET ReturnedFaceToFaceProspectCount = (SELECT COUNT(*)
                                                                            FROM PersonNote pn                            
                                                                            INNER JOIN Prospect p ON p.PersonID = pn.PersonID   
                                                                            LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID                                                
                                                                            WHERE pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID
																				AND pn.PropertyID = #ProspectEmployeeSummary.PropertyID
																				AND pn.PersonType = 'Prospect'
																				AND pn.ContactType = 'Face-to-Face'                                                                              
																				AND (((@accountingPeriodID IS NULL) AND ([Date] >= @startDate) AND ([Date] <= @endDate))
																				OR ((@accountingPeriodID IS NOT NULL) AND ([Date] >= pap.StartDate) AND ([Date] <= pap.EndDate)))
                                                                              
																				-- Make sure this contact is a qualified contact 
																				AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0)))

																				-- Make sure this Face-to-Face contact is the first Face-to-Face contact
																				AND pn.PersonNoteID <> (SELECT TOP 1 pn2.PersonNoteID 
																					                     FROM PersonNote pn2 
																						                 INNER JOIN Prospect p2 ON p2.PersonID = pn2.PersonID
																							              WHERE pn2.PropertyID = #ProspectEmployeeSummary.PropertyID
																							               AND pn2.PersonID = pn.PersonID 
                                                                                                           AND pn2.ContactType = 'Face-to-Face'
                                                                                                           AND pn2.PersonType = 'Prospect'
																								         ORDER BY [Date], DateCreated))
						  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'return ftf - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()							 				  
						
												
	UPDATE #ProspectEmployeeSummary SET FaceToFaceConversion = (SELECT COUNT(*)
																FROM PersonNote pn		
																	INNER JOIN Prospect p ON p.PersonID = pn.PersonID														
																	LEFT JOIN PersonNote pn3 ON pn3.PersonID = pn.PersonID AND pn3.ContactType <> 'Face-to-Face' AND pn3.PersonType = 'Prospect' AND pn3.[Date] <= pn.[Date]																					
																	INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
																	LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
																WHERE pn.PropertyID = #ProspectEmployeeSummary.PropertyID 
																	AND ((pt.[Type] = 'Employee' AND pn.CreatedByPersonID = #ProspectEmployeeSummary.PersonID) OR
																		(pt.[Type] = 'Prospect' AND #ProspectEmployeeSummary.PersonID = '00000000-0000-0000-0000-000000000000'))

																  --AND p.Name = #ProspectEmployeeSummary.PropertyName
																	AND pn.PersonType = 'Prospect'
																	AND pn.ContactType = 'Face-to-Face'																  
																	AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
																	OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))

																	-- Make sure this contact is a qualified contact 
																	AND ((@includeNonQualified = 1) OR ((@includeNonQualified = 0) AND (p.Unqualified IS NULL OR p.Unqualified = 0)))

																  -- Make sure this Face-to-Face contact is the first Face-to-Face contact
																	AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																							 FROM PersonNote pn2 
																							 INNER JOIN Prospect p2 ON p2.PersonID = pn2.PersonID	
																							 WHERE pn2.PropertyID = #ProspectEmployeeSummary.PropertyID
																								AND pn2.PersonID = pn.PersonID 
																								AND pn2.PersonType = 'Prospect'
																								AND pn2.ContactType = 'Face-to-Face'																							   
																							 ORDER BY [Date], DateCreated)
																  ---- Ensure there was a non-face-to-face contact made before the
																  ---- face-to-face contact	
																	AND pn3.PersonNoteID = (SELECT TOP 1 pn4.PersonNoteID 
																							 FROM PersonNote pn4 
																							 INNER JOIN Prospect p3 ON p3.PersonID = pn4.PersonID	
																							 WHERE pn4.PropertyID = #ProspectEmployeeSummary.PropertyID
																								AND pn4.PersonID = pn.PersonID 
																								AND pn4.PersonType = 'Prospect'
																								AND pn4.ContactType <> 'Face-to-Face'																							   
																								AND pn3.[Date] <= pn.[Date]
																							 ORDER BY [Date], DateCreated)
																	AND pn3.PersonNoteID IS NOT NULL)										 				 
																  
		
	
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'ftf conv - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()							 				  
			
	CREATE TABLE #NewLeasesRick (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		--PersonLeaseID uniqueidentifier not null,
		--PersonID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		ApplicationDate date null,
		LeaseStatus nvarchar(50) null,
		LeasingAgentPersonID uniqueidentifier null,
		ProspectID uniqueidentifier null,
		UnitShownDate date null)		
									
		  
	INSERT #NewLeasesRick
		SELECT b.PropertyID,
			   l.LeaseID,
			   ulg.UnitID,  
			   (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'ApplicationDate',
			   l.LeaseStatus,
			   l.LeasingAgentPersonID,
			   null, -- ProspectID
			   null -- Unit Shown Date
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertyIDs #pids on #pids.PropertyID = b.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON b.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE 		
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)				
				-- Ensure we only get leases that actually applied during the date range
				AND (((@accountingPeriodID IS NULL)
					AND (@startDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
					AND (@endDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)))
				  OR ((@accountingPeriodID IS NOT NULL)
					AND (pap.StartDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
					AND (pap.EndDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))))
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL					  
		  		
	-- Update prospect id for main prospects
		UPDATE #NewLeasesRick SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												 FROM Prospect pr													  
													  INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													  INNER JOIN PersonLease pl ON pl.LeaseID = #NewLeasesRick.LeaseID AND pr.PersonID = pl.PersonID
												 WHERE pps.PropertyID = #NewLeasesRick.PropertyID)
													   	
													 
		-- Update prospect id for roommates											 
		UPDATE #NewLeasesRick SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												FROM Prospect pr	
													INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #NewLeasesRick.LeaseID AND proroom.PersonID = pl.PersonID
												WHERE pps.PropertyID = #NewLeasesRick.PropertyID)
		WHERE #NewLeasesRick.ProspectID IS NULL


		UPDATE #NewLeasesRick SET UnitShownDate = (SELECT TOP 1 pn.[Date] 
													FROM PersonNote pn
														INNER JOIN Prospect pro ON pro.PersonID = pn.PersonID AND pro.ProspectID = #NewLeasesRick.ProspectID																																														
													WHERE 
														pn.PersonType = 'Prospect'											   
														AND pn.InteractionType IN ('Unit Shown', 'Application')
														AND pn.PropertyID = #NewLeasesRick.PropertyID
													ORDER BY [Date], DateCreated)				  						

		UPDATE #NewLeasesRick SET UnitShownDate = ApplicationDate WHERE UnitShownDate IS NULL
		  		
	 
				  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'RM Leases - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
		
	UPDATE #ProspectEmployeeSummary SET NewLeases = (SELECT COUNT (DISTINCT LeaseID) 
						FROM #NewLeasesRick
						WHERE LeasingAgentPersonID = #ProspectEmployeeSummary.PersonID
							AND PropertyID = #ProspectEmployeeSummary.PropertyID
							AND UnitShownDate >= @startDate)
							
	UPDATE #ProspectEmployeeSummary SET LeasedUponReturn = (SELECT COUNT (DISTINCT LeaseID) 
						FROM #NewLeasesRick
						WHERE LeasingAgentPersonID = #ProspectEmployeeSummary.PersonID
							AND PropertyID = #ProspectEmployeeSummary.PropertyID
							AND UnitShownDate < @startDate)							
						
			  
	--SET @diff = (SELECT DATEDIFF(millisecond, @start, getDate()))
	--PRINT 'Leases - ' +CONVERT(nvarchar(100), @diff)
	--SET @start = GetDate()
	
	CREATE TABLE #CancelledLeases
	(
		LeaseID uniqueidentifier,
		ResponsiblePersonID uniqueidentifier,
		ResponsiblePropertyID uniqueidentifier
	)
	
	INSERT #CancelledLeases 
		SELECT	l.LeaseID AS 'LeaseID', 				
				l.LeasingAgentPersonID AS 'ResponsiblePersonID',
				b.PropertyID AS 'ResponsiblePropertyID'
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID		
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertyIDs #pids on #pids.PropertyID = b.PropertyID		
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID		
			WHERE 
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
				AND l.LeaseStatus IN ('Cancelled', 'Denied')
				-- Ensure we only get leases that actually applied during the date range
				AND (((@accountingPeriodID IS NULL)
					AND (@startDate <= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
					AND (@endDate >= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)))
				  OR ((@accountingPeriodID IS NOT NULL)
					AND (pap.StartDate <= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
					AND (pap.EndDate >= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))))
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL
	
	UPDATE #ProspectEmployeeSummary SET LeasesCancelled = (SELECT COUNT (DISTINCT LeaseID) 
						FROM #CancelledLeases
						WHERE ResponsiblePersonID = #ProspectEmployeeSummary.PersonID
						  AND ResponsiblePropertyID = #ProspectEmployeeSummary.PropertyID)
	
							  
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
