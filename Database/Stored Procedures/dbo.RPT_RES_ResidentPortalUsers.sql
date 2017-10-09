SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 14, 2015
-- Description:	Gets the info for the Resident Portal Usage Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_ResidentPortalUsers] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@mainContactsOnly bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	DISTINCT
			l.LeaseID,
			u.Number AS 'UnitNumber',
			per.PreferredName AS 'FirstName',
			per.LastName AS 'LastName',
			us.Username AS 'Username',
			per.Email,
			pl.MoveInDate,
			pl.MoveOutDate,
			us.LastLoginDate
		FROM Lease l 
			INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
			INNER JOIN Person per ON pl.PersonID = per.PersonID
			INNER JOIN [User] us ON per.PersonID = us.PersonID AND us.IsResident = 1
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
		WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
		  AND ((@mainContactsOnly IS NULL) OR (@mainContactsOnly = 0) OR ((@mainContactsOnly = 1) AND (pl.MainContact = 1)))
	
	
END

GO
