SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Jordan Betteridge
-- Create date: July 31, 2014
-- Description:	Updates the first and last PersonNoteID of a prospect
-- =============================================
CREATE PROCEDURE [dbo].[UpdateProspectPersonNoteIDsNew] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@personID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@newPersonNoteID uniqueidentifier = null,
	@contactDate DATE = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

			  
	UPDATE p SET FirstPersonNoteID = @newPersonNoteID
	FROM Prospect p
		INNER JOIN PropertyProspectSource pps ON p.PropertyProspectSourceID = pps.PropertyProspectSourceID
		LEFT JOIN PersonNote pn ON p.FirstPersonNoteID = pn.PersonNoteID
	WHERE p.AccountID = @accountID AND
		  p.PersonID = @personID AND
		  pps.PropertyID = @propertyID AND
		  COALESCE(pn.[Date], '2999-1-1') > @contactDate
		  
	UPDATE p SET LastPersonNoteID = @newPersonNoteID
	FROM Prospect p
		INNER JOIN PropertyProspectSource pps ON p.PropertyProspectSourceID = pps.PropertyProspectSourceID
		LEFT JOIN PersonNote pn ON p.LastPersonNoteID = pn.PersonNoteID
	WHERE p.AccountID = @accountID AND
		  p.PersonID = @personID AND
		  pps.PropertyID = @propertyID AND
		  COALESCE(pn.[Date], '1950-1-1') <= @contactDate
END


GO
