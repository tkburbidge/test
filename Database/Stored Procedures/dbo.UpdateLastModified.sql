SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Forrest Tait
-- Create date: Jan 27, 2016
-- Description:	Updates the Person's last modified date to the current date
-- =============================================

CREATE PROCEDURE [dbo].[UpdateLastModified]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@propertyID uniqueidentifier
AS
BEGIN
	UPDATE Person SET LastModified = GETDATE() WHERE PersonID IN (
	SELECT p.PersonID 
	FROM Person p 
		INNER JOIN PersonLease pl ON pl.PersonID = p.PersonID
		INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID =ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
	WHERE b.PropertyID = @propertyID)		

	UPDATE Person SET LastModified = GETDATE() WHERE PersonID IN (
	SELECT p.PersonID 
	FROM Person p 
		INNER JOIN PersonType pt ON pt.PersonId = p.PersonID AND pt.[Type] = 'Non-Resident Account'
		INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID		
	WHERE ptp.PropertyID = @propertyID)		
END
GO
