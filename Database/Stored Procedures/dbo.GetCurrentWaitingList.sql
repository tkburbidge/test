SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 23, 2012
-- Description:	Generates data for the CurrentWaitingList reports
-- =============================================
CREATE PROCEDURE [dbo].[GetCurrentWaitingList] 
	-- Add the parameters for the stored procedure here
	@objectID uniqueidentifier = null, 
	@objectType nvarchar(50) = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF (@objectType IS NULL)
	BEGIN
		SELECT DISTINCT
				wl.WaitingListID AS 'WaitingListID', wl.ObjectID AS 'ObjectID', wl.ObjectType AS 'ObjectType',
				wl.DateCreated AS 'DateAdded', p.PreferredName + ' ' + p.LastName AS 'PersonName', pn.PersonType AS 'PersonType',
				p.Phone1 AS 'PhoneNumber', p.Email AS 'Email', wl.DateNeeded AS 'DateNeeded', pn.Note AS 'Notes'
			FROM WaitingList wl
				INNER JOIN Person p ON wl.PersonID = p.PersonID
				INNER JOIN WaitingListNote wln ON wl.WaitingListID = wln.WaitingListID
				INNER JOIN PersonNote pn ON wln.PersonNoteID = pn.PersonNoteID
			WHERE wl.ObjectID = @objectID
			  AND pn.InteractionType = 'Waiting List'
			  AND wl.DateRemoved IS NULL
			  AND wl.DateSatisfied IS NULL
	END
	ELSE
	BEGIN
		SELECT DISTINCT
				wl.WaitingListID AS 'WaitingListID', wl.ObjectID AS 'ObjectID', wl.ObjectType AS 'ObjectType',
				wl.DateCreated AS 'DateAdded', p.PreferredName + ' ' + p.LastName AS 'PersonName', pn.PersonType AS 'PersonType',
				p.Phone1 AS 'PhoneNumber', p.Email AS 'Email', wl.DateNeeded AS 'DateNeeded', pn.Note AS 'Notes'
			FROM WaitingList wl
				INNER JOIN Person p ON wl.PersonID = p.PersonID
				INNER JOIN WaitingListNote wln ON wl.WaitingListID = wln.WaitingListID
				INNER JOIN PersonNote pn ON wln.PersonNoteID = pn.PersonNoteID
			WHERE wl.ObjectType = @objectType
			  AND pn.InteractionType = 'Waiting List'
			  AND wl.DateRemoved IS NULL
			  AND wl.DateSatisfied IS NULL
	END	
END
GO
