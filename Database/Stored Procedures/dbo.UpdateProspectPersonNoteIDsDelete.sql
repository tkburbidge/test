SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Jordan Betteridge
-- Create date: July 31, 2014
-- Description:	Updates the first and last PersonNoteID of a prospect
-- =============================================
CREATE PROCEDURE [dbo].[UpdateProspectPersonNoteIDsDelete] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@personID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@deletedPersonNoteID uniqueidentifier = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	  

	UPDATE p SET FirstPersonNoteID = (SELECT TOP 1 pn.PersonNoteID
												FROM PersonNote pn													
												WHERE p.PersonID = pn.PersonID 
													AND pn.PropertyID = @propertyID
													AND pn.PersonNoteID <> @deletedPersonNoteID
												ORDER BY pn.[Date] ASC, pn.DateCreated ASC)
	FROM Prospect p
		INNER JOIN PropertyProspectSource pps ON p.PropertyProspectSourceID = pps.PropertyProspectSourceID		
	WHERE p.AccountID = @accountID AND
		  p.PersonID = @personID AND
		  pps.PropertyID = @propertyID AND
		  p.FirstPersonNoteID = @deletedPersonNoteID
	
	
	
	UPDATE p SET LastPersonNoteID = (SELECT TOP 1 pn.PersonNoteID
												FROM PersonNote pn													
												WHERE p.PersonID = pn.PersonID 
													AND pn.PropertyID = @propertyID
													AND pn.PersonNoteID <> @deletedPersonNoteID
											ORDER BY pn.[Date] DESC, pn.DateCreated DESC)
	FROM Prospect p
		INNER JOIN PropertyProspectSource pps ON p.PropertyProspectSourceID = pps.PropertyProspectSourceID		
	WHERE p.AccountID = @accountID AND
		  p.PersonID = @personID AND
		  pps.PropertyID = @propertyID AND
		  p.LastPersonNoteID = @deletedPersonNoteID
		
	  
END
GO
