SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 1/21/2013
-- Description:	update units associated to an amenity
-- =============================================
CREATE PROCEDURE [dbo].[UpdateUnitAmenities] 
	-- Add the parameters for the stored procedure here
	@amenityID UNIQUEIDENTIFIER,
	@accountID bigint,
	@unitIDs  GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DELETE FROM UnitAmenity WHERE AmenityID = @amenityID and AccountID = AccountID
    
    IF ((SELECT COUNT(*) FROM @unitIDs) > 0)
	BEGIN
		insert into UnitAmenity (UnitAmenityID, UnitID, AmenityID, AccountID)
		select NEWID(), VALUE, @amenityID, @accountID
		from @unitIDs
	END
END
GO
