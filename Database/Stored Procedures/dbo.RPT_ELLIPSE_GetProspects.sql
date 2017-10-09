SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 18, 2012
-- Description:	Ellipse Prospects Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ELLIPSE_GetProspects] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SELECT  per.PersonID AS 'ProspectId',
			p.PropertyID AS 'PropId',
			per.PreferredName AS 'FirstName',
			per.LastName AS 'LastName',
			per.Email AS 'Email',
			per.Phone1 AS 'Phone',
			CASE WHEN (per.Phone2Type = 'Mobile') THEN per.Phone2
			     WHEN (per.Phone3Type = 'Mobile') THEN per.Phone3
			     ELSE null END AS 'Cell',
			pl.MoveInDate AS 'MoveInDate',
			CASE WHEN (pl.PersonLeaseID IS NOT NULL) THEN 'A'
				 ELSE 'P' END AS 'Status'
		FROM Person per
			INNER JOIN PersonType pt ON per.PersonID = pt.PersonID AND pt.[Type] = 'Prospect'
			INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID
			INNER JOIN Property p ON ptp.PropertyID = p.PropertyID
			LEFT JOIN PersonLease pl ON per.PersonID = pl.PersonID
							AND pl.ResidencyStatus IN ('Pending', 'Denied')
							AND ((pl.ApprovalStatus IS NULL) OR (pl.ApprovalStatus NOT IN ('Approved')))
			LEFT JOIN PersonNote pn ON per.PersonID = pn.PersonID 
							AND pn.PersonNoteID = (SELECT Top 1 PersonNoteID
													FROM PersonNote
													WHERE PersonID = per.PersonID
													  AND [Date] > DATEADD(day, -30, getdate())
													  AND pl.PersonLeaseID IS NULL
													ORDER BY DateCreated DESC)
		WHERE per.PersonID NOT IN (SELECT pt1.PersonID 
									  FROM PersonType pt1
										INNER JOIN PersonTypeProperty ptp1 ON pt1.PersonTypeID = ptp1.PersonTypeID
										INNER JOIN PersonLease pl1 ON pt1.PersonID = pl1.PersonID AND pl1.ResidencyStatus NOT IN ('Pending', 'Denied') AND ((pl1.ApprovalStatus IS NULL) OR (pl1.ApprovalStatus = 'Denied'))
									  WHERE [Type] = 'Resident'
									    AND ptp1.PropertyID = p.PropertyID)
		  AND ((pl.PersonLeaseID IS NOT NULL) OR  (pn.PersonNoteID IS NOT NULL))


END
GO
