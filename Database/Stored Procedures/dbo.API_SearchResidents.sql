SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Craig Perkins
-- Create date: October 29, 2013
-- Description:	Finds residents and leasing information based on search criteria
-- =============================================
CREATE PROCEDURE [dbo].[API_SearchResidents] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier,
	@unit nvarchar(30) = null,
	@firstName nvarchar(30) = null,
	@lastName nvarchar(50) = null,
	@phone nvarchar(35) = null,
	@email nvarchar(150) = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT DISTINCT
	ulg.UnitLeaseGroupID AS 'LeaseID',
	ulg.UnitLeaseGroupID,
	p.PersonID,
	u.Number AS 'Unit',
	p.FirstName,
	p.LastName,
	CASE WHEN (p.Phone1Type = 'Mobile') THEN p.Phone1
			WHEN (p.Phone2Type = 'Mobile') THEN p.Phone2
			WHEN (p.Phone3Type = 'Mobile') THEN p.Phone3
			ELSE null END AS 'MobilePhone',
	CASE WHEN (p.Phone1Type = 'Home') THEN p.Phone1
			WHEN (p.Phone2Type = 'Home') THEN p.Phone2
			WHEN (p.Phone3Type = 'Home') THEN p.Phone3
			ELSE null END AS 'HomePhone',
	CASE WHEN (p.Phone1Type = 'Work') THEN p.Phone1
			WHEN (p.Phone2Type = 'Work') THEN p.Phone2
			WHEN (p.Phone3Type = 'Work') THEN p.Phone3
			ELSE null END AS 'WorkPhone',
	p.Email,	
	l.LeaseStartDate,
	l.LeaseEndDate,	
	pl.MoveInDate,
	pl.MoveOutDate,
	null     
	FROM Person p
		INNER JOIN PersonLease pl ON pl.PersonID = p.PersonID
		INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
	WHERE p.AccountID = @accountID
		AND b.PropertyID = @propertyID
		AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
							FROM Lease l2
							INNER JOIN Ordering o ON o.Value = l2.LeaseStatus
							WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							ORDER BY OrderBy)
		AND -- Matching on Unit
			(@unit IS NULL
			OR u.Number = @unit)
		AND -- Matching on First Name
			(@firstName IS NULL
			OR p.FirstName = @firstName)
		AND -- Matching on Last Name
			(@lastName IS NULL
			OR p.LastName = @lastName)
		AND -- Matching on Phone
			(@phone IS NULL
			OR (dbo.RemoveNonNumericCharacters(p.Phone1) = @phone 
			    OR dbo.RemoveNonNumericCharacters(p.Phone2) = @phone
			    OR dbo.RemoveNonNumericCharacters(p.Phone3) = @phone))
		AND -- Matching on Email
			(@email IS NULL
			OR p.Email = @email)

END

GO
