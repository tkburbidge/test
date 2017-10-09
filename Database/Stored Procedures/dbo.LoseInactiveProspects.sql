SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 5/6/2014
-- Description:	Finds inactive prospects for all properties that want to automatically lose prospects and marks them as lost.
-- =============================================
CREATE PROCEDURE [dbo].[LoseInactiveProspects] 
	-- Add the parameters for the stored procedure here
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    
    CREATE TABLE #InactiveProspect
    (
		AccountID bigint not null,
		PropertyID uniqueidentifier not null,
		ProspectID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		NoteCreatedByPersonID uniqueidentifier not null,
		LostProspectReasonID uniqueidentifier not null,
		LostProspectReason nvarchar(50) not null,
		LostProspectNotes nvarchar(100) not null
	)
    
    INSERT #InactiveProspect
		SELECT pros.AccountID AS 'AccountID',
			   prop.PropertyID AS 'PropertyID',
			   pros.ProspectID AS 'ProspectID',
			   pros.PersonID AS 'PersonID',
			   ISNULL(responsiblePT.PersonID, pros.PersonID) AS 'NoteCreatedByPersonID',
			   COALESCE(pros.LostReasonPickListItemID ,prop.AutoLostProspectReasonID) AS 'LostProspectReasonID',
			   'Prospect Lost: ' + lostReason.Name AS 'LostProspectReason',
			   'Automatically lost due to inactivity' AS 'LostProspectNotes'
		FROM Prospect pros
		INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
		INNER JOIN Property prop ON pps.PropertyID = prop.PropertyID
		INNER JOIN PersonNote lastNote ON lastNote.PersonID = pros.PersonID
		INNER JOIN PickListItem lostReason ON prop.AutoLostProspectReasonID = lostReason.PickListItemID
		LEFT JOIN PersonTypeProperty responsiblePTP ON pros.ResponsiblePersonTypePropertyID = responsiblePTP.PersonTypePropertyID
		LEFT JOIN PersonType responsiblePT ON responsiblePTP.PersonTypeID = responsiblePT.PersonTypeID
		LEFT JOIN PersonType residentPT ON residentPT.PersonID = pros.PersonID AND residentPT.[Type] = 'Resident'
		LEFT JOIN PersonTypeProperty rptp ON rptp.PersonTypeID = residentPT.PersonTypeID AND rptp.PropertyID = pps.PropertyID
		WHERE prop.MaxProspectInactiveDays IS NOT NULL --Make sure the property wants to auto-lose prospects
		  AND prop.AutoLostProspectReasonID IS NOT NULL --Make sure the property wants to auto-lose prospects
		  AND pros.LostDate IS NULL --Prospects who aren't already lost
		  AND rptp.PersonTypePropertyID IS NULL --Prospects who aren't converted to applicants
		  AND lastNote.PersonNoteID = (SELECT TOP 1 pn.PersonNoteID
									   FROM PersonNote pn
									   WHERE pn.PersonID = pros.PersonID
									     AND pn.PropertyID = prop.PropertyID
									     AND pn.PersonType = 'Prospect'
									   ORDER BY pn.[Date] DESC, pn.DateCreated DESC)
		  AND DATEDIFF(DAY, lastNote.[Date], @date) > prop.MaxProspectInactiveDays --Prospects who don't have a note in the last X days


	--Create a person note for losing the prospect
	INSERT PersonNote (AccountID, PersonNoteID, ContactType, CreatedByPersonID, PropertyID, DateCreated, [Date], InteractionType, [Description], Note, PersonType, PersonID, MITSEventType, NoteRead)
		SELECT AccountID, NEWID(), 'N/A', NoteCreatedByPersonID, PropertyID, @date, @date, 'Other', LostProspectReason, LostProspectNotes, 'Prospect', PersonID, 'Cancel', 0
		FROM #InactiveProspect
		
	--Set the lost prospect fields on the prospect
	UPDATE Prospect SET LostReasonPickListItemID = LostProspectReasonID, LostReasonNotes = LostProspectNotes, LostDate = @date
		FROM #InactiveProspect
		WHERE Prospect.ProspectID = #InactiveProspect.ProspectID
		
	--SELECT COUNT(*) FROM #InactiveProspect
END
GO
