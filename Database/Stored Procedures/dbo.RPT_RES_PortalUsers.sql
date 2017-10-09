SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 14, 2015
-- Description:	Gets the info for the Resident Portal Usage Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_PortalUsers] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@mainContactsOnly bit = 0,
	@includeRegisteredUsers bit = 0,
	@includeNonRegisteredUsers bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	DISTINCT
			p.PropertyID,
			p.Name AS 'PropertyName',
			CASE WHEN (us.UserID IS NULL)
				THEN CAST(0 AS BIT)
				ELSE CAST(1 AS BIT) END AS 'Registered',
			l.LeaseID,
			u.Number AS 'UnitNumber',
			u.PaddedNumber AS 'PaddedUnitNumber',
			per.PreferredName AS 'FirstName',
			per.LastName AS 'LastName',
			us.Username AS 'Username',
			per.Email,
			per.Phone1 AS 'Phone',
			pl.MoveInDate,
			pl.MoveOutDate,
			us.LastLoginDate
		FROM Lease l 
			INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
			INNER JOIN Person per ON pl.PersonID = per.PersonID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			LEFT JOIN [User] us ON per.PersonID = us.PersonID AND us.IsResident = 1
		WHERE l.AccountID = @accountID
		  AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND l.LeaseStatus IN ('Current', 'Under Eviction')
		  AND ((@mainContactsOnly IS NULL) OR (@mainContactsOnly = 0) OR ((@mainContactsOnly = 1) AND (pl.MainContact = 1)))
		  AND ((@includeRegisteredUsers IS NULL) OR (@includeRegisteredUsers = 1) OR ((@includeRegisteredUsers = 0) AND (us.UserID IS NULL)))
		  AND ((@includeNonRegisteredUsers IS NULL) OR (@includeNonRegisteredUsers = 1) OR ((@includeNonRegisteredUsers = 0) AND (us.UserID IS NOT NULL)))
	
	
END
GO
