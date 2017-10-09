SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[DeleteAmenity]
	@accountID bigint,
	@amenityID uniqueidentifier
AS
BEGIN
	
	UPDATE lli
		SET lli.AmenityChargeID = NULL
		FROM LeaseLedgerItem lli 
			INNER JOIN AmenityCharge ac ON ac.AmenityChargeID = lli.AmenityChargeID
		WHERE lli.AccountID = @accountID
		  AND ac.AmenityID = @amenityID

	DELETE AmenityCharge
		WHERE AccountID = @accountID
		  AND AmenityID = @amenityID
	
	DELETE UnitAmenity
		WHERE AccountID = @accountID
		  AND AmenityID = @amenityID	  

	DELETE ProspectAmenity
		WHERE AccountID = @accountID
		  AND AmenityID = @amenityID
		  
	DELETE Amenity
		WHERE AccountID = @accountID
		  AND AmenityID = @amenityID
END
GO
