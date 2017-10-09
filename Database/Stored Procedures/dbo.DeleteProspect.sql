SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 05/19/2014
-- Description:	Delete a prospect and all of the information related to them, unless they are tied to more than one property.
-- =============================================
CREATE PROCEDURE [dbo].[DeleteProspect] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@prospectID uniqueidentifier,
	@propertyID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    	  
	CREATE TABLE #Person
	(
		PersonID uniqueidentifier,
		PropertyTies int null,
		SamePropertyTies int null
	)
	
	--Get the Prospects personID
	INSERT #Person (PersonID)
		SELECT p.PersonID
			FROM Prospect p
				INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
			WHERE p.AccountID = @accountID 
			  AND p.ProspectID = @prospectID
			  AND pps.PropertyID = @propertyID
		  
	--Get the prospect roommate personIDs
	INSERT #Person (PersonID)
		SELECT pr.PersonID
			FROM ProspectRoommate pr
				INNER JOIN Prospect p ON p.ProspectID = pr.ProspectID
				INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
			WHERE pr.AccountID = @accountID 
			  AND pr.ProspectID = @prospectID
			  AND pps.PropertyID = @propertyID
	
	IF (SELECT COUNT(*) FROM #Person) > 0
	BEGIN
				  
		--Find out if these people are tied to more than one property in any way
		--People who only have 1 PropertyTie can be completely deleted.
		--People who have more than 1 SamePropertyTies should only have the prospect record deleted (it is a duplicate prospect)
		UPDATE #Person
			SET PropertyTies = (SELECT COUNT(*)
									FROM PersonTypeProperty ptp
										INNER JOIN PersonType pt ON pt.PersonTypeID = ptp.PersonTypeID
									WHERE #Person.PersonID = pt.PersonID),
				SamePropertyTies = (SELECT COUNT(*)
									FROM PersonTypeProperty ptp
										INNER JOIN PersonType pt ON pt.PersonTypeID = ptp.PersonTypeID
									WHERE #Person.PersonID = pt.PersonID
									  AND ptp.PropertyID = @propertyID)
		
					
		--Start deleting things		
					  
		DELETE FROM AlertTask
			WHERE AccountID = @accountID
			  AND (ObjectID = @prospectID
				   OR EXISTS (SELECT * 
								FROM #Person #p
								WHERE #p.PersonID = AlertTask.ObjectID
								  AND #p.PropertyTies = 1))

		DELETE FROM Pet
			WHERE AccountID = @accountID
			  AND EXISTS 
					(SELECT * 
						FROM #Person #p
						WHERE #p.PersonID = Pet.PersonID
						  AND #p.PropertyTies = 1)
		
		DELETE FROM Employment 
			WHERE AccountID = @accountID
			  AND EXISTS 
					(SELECT * 
						FROM #Person #p
						WHERE #p.PersonID = Employment.PersonID
						  AND #p.PropertyTies = 1)
		
		DELETE FROM EventAttendee
			WHERE AccountID = @accountID
			  AND EXISTS
			   (SELECT e.EventID
					FROM [Event] e
						INNER JOIN #Person #p ON #p.PersonID = e.ObjectID
					WHERE EventAttendee.EventID = e.EventID
					  AND #p.PropertyTies = 1)
		
		DELETE FROM [Event]
			WHERE AccountID = @accountID
			  AND EXISTS 
					(SELECT * 
						FROM #Person #p
						WHERE #p.PersonID = [Event].ObjectID
						  AND #p.PropertyTies = 1)
			
		DELETE FROM [Address]
			WHERE AccountID = @accountID
			  AND EXISTS 
					(SELECT * 
						FROM #Person #p
						WHERE #p.PersonID = [Address].ObjectID
						  AND #p.PropertyTies = 1)
		
		DELETE FROM ProspectAmenity
			WHERE EXISTS
			   (SELECT a.AmenityID
					FROM Amenity a
					WHERE a.PropertyID = @propertyID
					  AND ProspectAmenity.AccountID = @accountID
					  AND ProspectAmenity.AmenityID = a.AmenityID
					  AND ProspectAmenity.ProspectID = @prospectID)
		  
		DELETE FROM ProspectUnit
			WHERE EXISTS
			   (SELECT u.UnitID
					FROM Unit u
						INNER JOIN Building b ON b.BuildingID = u.BuildingID
					WHERE b.PropertyID = @propertyID
					  AND ProspectUnit.AccountID = @accountID
					  AND ProspectUnit.UnitID = u.UnitID
					  AND ProspectUnit.ProspectID = @prospectID)
		
		DELETE FROM ProspectUnitType
			WHERE EXISTS
			   (SELECT ut.UnitTypeID
					FROM UnitType ut
					WHERE ut.PropertyID = @propertyID
					  AND ProspectUnitType.AccountID = @accountID
					  AND ProspectUnitType.UnitTypeID = ut.UnitTypeID
					  AND ProspectUnitType.ProspectID = @prospectID)
		
		DELETE FROM WaitingListNote
			WHERE EXISTS
			   (SELECT pn.PersonNoteID
					FROM PersonNote pn
						INNER JOIN #Person #p ON #p.PersonID = pn.PersonID
					WHERE WaitingListNote.AccountID = @accountID
					  AND WaitingListNote.PersonNoteID = pn.PersonNoteID
					  AND pn.PropertyID = @propertyID
					  AND #p.SamePropertyTies = 1) --only delete WaitingListNotes if the prospect isn't a duplicate on this prop
		
		DELETE FROM WaitingList
			WHERE EXISTS
			   (SELECT wl.WaitingListID
					FROM WaitingList wl
						INNER JOIN #Person #p ON #p.PersonID = wl.PersonID
						LEFT JOIN Unit u ON u.UnitID = wl.ObjectID
						LEFT JOIN UnitType ut ON (ut.UnitTypeID = wl.ObjectID OR ut.UnitTypeID = u.UnitTypeID)
						LEFT JOIN LedgerItem li ON li.LedgerItemID = wl.ObjectID
						LEFT JOIN LedgerItemPool lip ON (lip.LedgerItemPoolID = wl.ObjectID OR lip.LedgerItemPoolID = li.LedgerItemPoolID)
					WHERE WaitingList.WaitingListID = wl.WaitingListID
					  AND WaitingList.AccountID = @accountID
					  AND (ut.PropertyID = @propertyID
						  OR lip.PropertyID = @propertyID)
					  AND #p.SamePropertyTies = 1) -- only delete WaitingLists if the prospect isn't a duplicate on this property
		
		DELETE FROM EmailRecipient
			WHERE EXISTS
			   (SELECT *
					FROM EmailJob ej
						INNER JOIN #Person #p ON #p.PersonID = EmailRecipient.PersonID
					WHERE EmailRecipient.EmailJobID = ej.EmailJobID
					  AND ej.PropertyID = @propertyID
					  AND EmailRecipient.AccountID = @accountID
					  AND #p.SamePropertyTies = 1)

		DELETE FROM ProspectRoommate
			WHERE ProspectID = @prospectID
			  AND AccountID = @accountID
			  
		DELETE FROM PersonNote 
			WHERE AccountID = @accountID
			  AND PropertyID = @propertyID
			  AND EXISTS 
					(SELECT * 
						FROM #Person #p
						WHERE #p.PersonID = PersonNote.PersonID
						  AND #p.SamePropertyTies = 1)
	    
		--PersonTypeProperties that are duplicated for a property are indistinguishable. 
		--  Option 1: Add checks in app to prevent prospects from being transferred twice.
		--  Option 2: Just delete one of the PersonTypeProperties
		--  Option 3: Forget about handling the case when there are duplicates.
		--Choosing Option 2 for now.
		DELETE FROM PersonTypeProperty
			WHERE PersonTypeProperty.PersonTypePropertyID = (SELECT TOP 1 ptp.PersonTypePropertyID
																FROM PersonTypeProperty ptp
																	INNER JOIN PersonType pt ON pt.PersonTypeID = ptp.PersonTypeID
																	INNER JOIN #Person #p ON #p.PersonID = pt.PersonID
																WHERE ptp.AccountID = @accountID
																  AND ptp.PropertyID = @propertyID
																  AND pt.[Type] = 'Prospect'
																  AND PersonTypeProperty.PersonTypeID = pt.PersonTypeID
																ORDER BY ptp.PersonTypePropertyID)
			
		--Delete PersonTypes that were only tied to one PersonTypeProperty
		DELETE FROM PersonType
			WHERE AccountID = @accountID
			  AND EXISTS 
					(SELECT * 
						FROM #Person #p
						WHERE #p.PersonID = PersonType.PersonID
						  AND #p.PropertyTies = 1)
			    
		DELETE FROM Prospect
			WHERE ProspectID = @prospectID
			  AND AccountID = @accountID
			  
			  
		DELETE FROM Person
			WHERE AccountID = @accountID
			  AND EXISTS 
					(SELECT * 
						FROM #Person #p
						WHERE #p.PersonID = Person.PersonID
						  AND #p.PropertyTies = 1)
	END
END
GO
