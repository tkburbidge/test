SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Jordan Betteridge
-- Create date: August 5, 2014
-- Description:	Updates the first and last PersonNoteID of a resident
-- =============================================
CREATE PROCEDURE [dbo].[UpdateResidentPersonNoteIDs] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@personID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@personNoteID uniqueidentifier = null,
	@date DATE = null,
	@action nvarchar(10) = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
			  
	
	-- Add PersonNotes	  
	UPDATE ulg SET LastPersonNoteID = @personNoteID
	FROM UnitLeaseGroup ulg
		INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		INNER JOIN PersonLease pl on pl.LeaseID = l.LeaseID
		INNER JOIN Unit u on u.UnitID = ulg.UnitID
		INNER JOIN Building b on b.BuildingID = u.BuildingID
		LEFT JOIN PersonNote pn ON ulg.LastPersonNoteID = pn.PersonNoteID
	WHERE ulg.AccountID = @accountID AND
		  pl.PersonID = @personID AND
		  b.PropertyID = @propertyID AND
		  (pn.PersonNoteID IS NULL OR pn.[Date] <= @date) AND
		  @action = 'Add'
	
	-- Update PersonNotes
	DECLARE @tmpPersonNoteID uniqueidentifier
	SET @tmpPersonNoteID = (SELECT TOP 1 pn.PersonNoteID
							FROM PersonNote pn
								INNER JOIN PersonLease pl ON pl.PersonID = pn.PersonID
								INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
								INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
								INNER JOIN Unit u ON u.UnitID = ulg.UnitID
								INNER JOIN Building b ON b.BuildingID = u.BuildingID
							WHERE pn.AccountID = @accountID
							  AND pl.PersonID = @personID
							  AND b.PropertyID = @propertyID
							  AND pn.PersonNoteID != @personNoteID
							  AND pn.PersonType = 'Resident'
							  AND pn.[Date] > @date
							ORDER BY pn.[Date] DESC, pn.DateCreated DESC)
	
	UPDATE ulg SET LastPersonNoteID = CASE WHEN @tmpPersonNoteID IS NULL THEN @personNoteID ELSE @tmpPersonNoteID END								
	FROM UnitLeaseGroup ulg
		INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		INNER JOIN PersonLease pl on pl.LeaseID = l.LeaseID
		INNER JOIN Unit u on u.UnitID = ulg.UnitID
		INNER JOIN Building b on b.BuildingID = u.BuildingID
	WHERE ulg.AccountID = @accountID AND
		pl.PersonID = @personID AND
		b.PropertyID = @propertyID AND
		@action = 'Update'
	
	-- Delete PersonNotes
	UPDATE ulg SET LastPersonNoteID = (SELECT TOP 1 pn.PersonNoteID
										FROM PersonNote pn
											INNER JOIN PersonLease pl ON pl.PersonID = pn.PersonID
											INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
											INNER JOIN UnitLeaseGroup ulg2 ON ulg2.UnitLeaseGroupID = l.UnitLeaseGroupID
											INNER JOIN Unit u ON u.UnitID = ulg2.UnitID
											INNER JOIN Building b ON b.BuildingID = u.BuildingID
										WHERE pn.AccountID = @accountID AND
											b.PropertyID = @propertyID AND
											ulg2.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND
											pn.PersonNoteID != @personNoteID AND
											pn.PersonType = 'Resident'
										ORDER BY pn.[Date] DESC, pn.DateCreated DESC)
	FROM UnitLeaseGroup ulg
		INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		INNER JOIN PersonLease pl on pl.LeaseID = l.LeaseID
		INNER JOIN Unit u on u.UnitID = ulg.UnitID
		INNER JOIN Building b on b.BuildingID = u.BuildingID
	WHERE ulg.AccountID = @accountID AND
		pl.PersonID = @personID AND
		b.PropertyID = @propertyID AND
		@action = 'Delete'
		
	  
END



GO
