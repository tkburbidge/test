SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 7, 2012
-- Description:	Gets the data for the Prospects Report.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_AllProspects] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@communicationLog nvarchar(20) = null,
	@newProspects bit = 0,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #PropertyAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL)
	
	CREATE TABLE #Prospects (
		ID int identity,
		ProspectID uniqueidentifier NOT NULL,
		PropertyName nvarchar(50) NOT NULL,
		PropertyID uniqueidentifier NOT NULL,
		PersonID uniqueidentifier NOT NULL,
		LastContact date NULL,
		LastContactType nvarchar(20) NULL,
		Name nvarchar(210) NULL,
		Phone nvarchar(35) NULL,
		ProspectSource nvarchar(50) NULL,
		MovingFrom nvarchar(50) NULL,
		DateNeeded date NULL,
		UnitTypePreferences  nvarchar(max) NULL,
		MaxRent int NULL,
		LeasingAgent nvarchar(210) NULL,
		UnitLeased nvarchar(20) NULL,
		UnitShown bit NULL,
		Email nvarchar(150) NULL,
		FirstContact date NULL,
		FirstContactType nvarchar(20) NULL
		)

	CREATE TABLE #CommunicationLogs (
		PropertyID uniqueidentifier NOT NULL,
		PersonID uniqueidentifier NOT NULL,
		LogEntry nvarchar(max) NULL,
		[Date] date NOT NULL,
		DateCreated datetime NOT NULL)

	IF (@accountingPeriodID IS NOT NULL)
	BEGIN		
		INSERT #PropertyAndDates
			SELECT pids.Value, pap.StartDate, pap.EndDate
				FROM @propertyIDs pids
					INNER JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	END
	ELSE
	BEGIN
		INSERT #PropertyAndDates
			SELECT pids.Value, @startDate, @endDate
				FROM @propertyIDs pids
	END

	INSERT #Prospects
		SELECT DISTINCT				
				prst.ProspectID,
				p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				prst.PersonID AS 'PersonID',
				(SELECT TOP 1 [Date] 
					FROM PersonNote 
					WHERE PersonID = prst.PersonID
					  --AND CreatedByPersonTypePropertyID IN (SELECT PersonTypePropertyID FROM PersonTypeProperty WHERE PropertyID = p.PropertyID)
					  AND PropertyID = p.PropertyID
					  AND PersonType = 'Prospect'
					  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
					ORDER BY
						CASE WHEN (@newProspects = 0) THEN [Date] END DESC,
						CASE WHEN (@newProspects = 0) THEN [DateCreated] END DESC,
						CASE WHEN (@newProspects = 1) THEN [Date] END ASC,
						CASE WHEN (@newProspects = 1) THEN [DateCreated] END ASC) AS 'LastContact',
				(SELECT TOP 1 PersonNote.ContactType
					FROM PersonNote 
					WHERE PersonID = prst.PersonID
					  --AND CreatedByPersonTypePropertyID IN (SELECT PersonTypePropertyID FROM PersonTypeProperty WHERE PropertyID = p.PropertyID)
					  AND PropertyID = p.PropertyID
					  AND PersonType = 'Prospect'
					  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
					ORDER BY
						CASE WHEN (@newProspects = 0) THEN [Date] END DESC,
						CASE WHEN (@newProspects = 0) THEN [DateCreated] END DESC,
						CASE WHEN (@newProspects = 1) THEN [Date] END ASC,
						CASE WHEN (@newProspects = 1) THEN [DateCreated] END ASC) AS 'LastContactType',
				pr.PreferredName + ' ' + pr.LastName AS 'Name',
				pr.Phone1 AS 'Phone',
				ps.Name AS 'ProspectSource',
				prst.MovingFrom AS 'MovingFrom',
				prst.DateNeeded AS 'DateNeeded',
				STUFF((SELECT ', ' + Name
					FROM UnitType
						INNER JOIN ProspectUnitType put ON put.UnitTypeID = UnitType.UnitTypeID
					WHERE put.ProspectID = prst.ProspectID
					FOR XML PATH ('')), 1, 2, '') AS 'UnitTypePreferences',
				prst.MaxRent AS 'MaxRent',
				lap.PreferredName + ' ' + lap.LastName AS 'LeasingAgent',
				u.Number AS 'UnitLeased',
				CASE WHEN (SELECT COUNT(*) 
							FROM PersonNote 
							WHERE PersonID = prst.PersonID
								--AND CreatedByPersonTypePropertyID IN (SELECT PersonTypePropertyID FROM PersonTypeProperty WHERE PropertyID = p.PropertyID)
								AND PropertyID = p.PropertyID
								AND PersonNote.InteractionType = 'Unit Shown') > 0 THEN CAST(1 AS bit)
					ELSE CAST(0 AS bit)
				END AS 'UnitShown',
				--CASE WHEN (@communicationLog = 'First') 
				--		 THEN (SELECT TOP 1 Note	
				--				   FROM PersonNote
				--				   WHERE PersonID = pr.PersonID 
				--					 AND PersonType = 'Prospect'
				--					 AND PropertyID = p.PropertyID
				--				   ORDER BY [Date], DateCreated)
				--	 WHEN (@communicationLog = 'Last') 
				--		 THEN (SELECT TOP 1 Note	
				--				   FROM PersonNote
				--				   WHERE PersonID = pr.PersonID 
				--					 AND PersonType = 'Prospect'
				--					 AND PropertyID = p.PropertyID
				--				   ORDER BY [Date] DESC, DateCreated DESC)	
				--	ELSE null END AS 'LogEntry'	
				pr.Email AS 'Email',
				fpn.[Date] AS 'FirstContact',
				fpn.ContactType AS 'FirstContactType'
			FROM Prospect prst
				INNER JOIN Person pr ON prst.PersonID = pr.PersonID


				INNER JOIN PersonType prosPT ON prst.PersonID = prosPT.PersonID --AND prosPT.[Type] = 'Prospect'
				INNER JOIN PersonTypeProperty ptp ON prosPT.PersonTypeID = ptp.PersonTypeID					
				INNER JOIN PropertyProspectSource pps ON prst.PropertyProspectSourceID = pps.PropertyProspectSourceID
				INNER JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
				INNER JOIN Property p ON pps.PropertyID = p.PropertyID
				INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
				INNER JOIN Person respr ON pt.PersonID = respr.PersonID
				LEFT JOIN PersonTypeProperty laptp ON laptp.PersonTypePropertyID = prst.ResponsiblePersonTypePropertyID
				LEFT JOIN PersonType lapt ON lapt.PersonTypeID = laptp.PersonTypeID
				LEFT JOIN Person lap ON lap.PersonID = lapt.PersonID
				LEFT JOIN PersonLease pl ON pr.PersonID = pl.PersonID
				LEFT JOIN Lease l ON pl.LeaseID = l.LeaseID
				LEFT JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN #PropertyAndDates #pad ON #pad.PropertyID = p.PropertyID
				LEFT JOIN PersonNote fpn ON fpn.PersonNoteID = prst.FirstPersonNoteID
			WHERE (#pad.StartDate <= (SELECT TOP 1 pn1.[Date] 
										FROM PersonNote pn1	
										  --INNER JOIN PersonTypeProperty ptp1 ON pn1.CreatedByPersonTypePropertyID = ptp1.PersonTypePropertyID AND ptp1.PropertyID = p.PropertyID								
										WHERE pn1.PersonID = prst.PersonID
										  AND pn1.PropertyID = p.PropertyID
										  AND PersonType = 'Prospect'
										  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
										ORDER BY 
											CASE WHEN (@newProspects = 0) THEN [Date] END DESC,
											CASE WHEN (@newProspects = 0) THEN [DateCreated] END DESC,
											CASE WHEN (@newProspects = 1) THEN [Date] END ASC,
											CASE WHEN (@newProspects = 1) THEN [DateCreated] END ASC))
			  AND (#pad.EndDate >= (SELECT TOP 1 pn1.[Date] 
										FROM PersonNote pn1	
										  --INNER JOIN PersonTypeProperty ptp1 ON pn1.CreatedByPersonTypePropertyID = ptp1.PersonTypePropertyID AND ptp1.PropertyID = p.PropertyID								
										WHERE pn1.PersonID = prst.PersonID
										  AND pn1.PropertyID = p.PropertyID
										  AND PersonType = 'Prospect'
										  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
										ORDER BY 
											CASE WHEN (@newProspects = 0) THEN [Date] END DESC,
											CASE WHEN (@newProspects = 0) THEN [DateCreated] END DESC,
											CASE WHEN (@newProspects = 1) THEN [Date] END ASC,
											CASE WHEN (@newProspects = 1) THEN [DateCreated] END ASC))	
			ORDER BY 'LastContact'																
	
	-- If the prospect applied to two units, get the last one
	DELETE #p2
		FROM #Prospects #p1
			INNER JOIN #Prospects #p2 ON #p2.PersonID = #p1.PersonID AND #p2.ProspectID = #p1.ProspectID AND #p1.ID < #p2.ID

	-- First or Last Communication Logs Entry
	INSERT #CommunicationLogs
		SELECT
			#prst.PropertyID,
			#prst.PersonID,
			pn1.Note AS 'LogEntry',
			pn1.[Date],
			pn1.DateCreated	
		FROM  #Prospects #prst
			INNER JOIN PersonNote pn1 ON #prst.PropertyID = pn1.PropertyID AND #prst.PersonID = pn1.PersonID
		WHERE
			pn1.PersonNoteID IN (CASE WHEN (@communicationLog = 'First') 
											 THEN (SELECT TOP 1 pn2.PersonNoteID	
													   FROM PersonNote pn2
													   WHERE pn2.PersonID = #prst.PersonID 
														 AND pn2.PersonType = 'Prospect'
														 AND pn2.PropertyID = #prst.PropertyID
													   ORDER BY pn2.[Date], pn2.DateCreated)
										 WHEN (@communicationLog = 'Last') 
											 THEN (SELECT TOP 1 pn2.PersonNoteID	
													   FROM PersonNote pn2
													   WHERE pn2.PersonID = #prst.PersonID 
														 AND pn2.PersonType = 'Prospect'
														 AND pn2.PropertyID = #prst.PropertyID
													   ORDER BY pn2.[Date] DESC, pn2.DateCreated DESC)
										ELSE null END)
		ORDER BY PropertyID, PersonID, [Date] DESC, DateCreated DESC
	
	-- All Communication Log Entries
	INSERT #CommunicationLogs
		SELECT
			#prst.PropertyID,
			#prst.PersonID,
			pn1.Note AS 'LogEntry',
			pn1.[Date],
			pn1.DateCreated	
		FROM  #Prospects #prst
			INNER JOIN PersonNote pn1 ON #prst.PropertyID = pn1.PropertyID AND #prst.PersonID = pn1.PersonID
		WHERE pn1.PersonType = 'Prospect'
		  AND @communicationLog = 'All'
		ORDER BY PropertyID, PersonID, [Date] DESC, DateCreated DESC


	SELECT * FROM #Prospects
	SELECT * FROM #CommunicationLogs

END
GO
