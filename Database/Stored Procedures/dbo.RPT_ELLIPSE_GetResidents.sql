SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 19, 2012
-- Description:	Gets the Ellipse Resident Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ELLIPSE_GetResidents] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	
			per.PersonID AS 'ResId',
			ut.PropertyID AS 'PropId',
			u.UnitID AS 'UnitId',
			per.PreferredName AS 'FirstName',
			per.LastName AS 'LastName',
			per.Email AS 'Email',
			per.Birthdate AS 'Birthday',
			CASE WHEN (per.IsMale = 1) THEN 'M'
				 ELSE 'F' END AS 'Sex',
			per.Phone1 AS 'Phone',
			CASE WHEN (per.Phone1Type = 'Mobile') THEN per.Phone1
				 WHEN (per.Phone2Type = 'Mobile') THEN per.Phone2
			     WHEN (per.Phone3Type = 'Mobile') THEN per.Phone3
			     ELSE null END AS 'Cell',
			CASE WHEN (pl.ResidencyStatus = 'Former') THEN 'Past'
				 ELSE 'Current' END AS 'Status',
			pl.MoveInDate AS 'MoveInDate',
			pl.MoveOutDate AS 'MoveOutDate',
			pl.MainContact AS 'IsPrimary'		
		FROM UnitLeaseGroup ulg
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Former', 'Under Eviction', 'Eviction')
			INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Property pro ON pro.PropertyID = ut.PropertyID
			INNER JOIN Person per ON pl.PersonID = per.PersonID			
		WHERE ((pl.ResidencyStatus = 'Current') OR ((pl.ResidencyStatus = 'Former') AND (pl.MoveOutDate > DATEADD(day, -180, getdate()))))
			AND ut.PropertyID IN (SELECT Value FROM @propertyIDs)
		ORDER BY pro.name, u.paddednumber, per.LastName, per.PreferredName
END
GO
