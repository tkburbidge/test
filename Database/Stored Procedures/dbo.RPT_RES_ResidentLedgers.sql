SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Jordan Betteridge
-- Create date: August 11, 2014
-- Description:	Gets info for generating bulk resident ledgers
-- =============================================
create PROCEDURE [dbo].[RPT_RES_ResidentLedgers] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@statuses StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	
			
	SELECT
		u.number AS 'UnitNumber',
		per.FirstName + ' '+ per.LastName AS 'Resident',
		ulg.UnitLeaseGroupID,
		pl.PersonID,
		l.LeaseID
	FROM UnitLeaseGroup ulg
		INNER JOIN Unit u on u.UnitID = ulg.UnitID
		INNER JOIN Building b on b.BuildingID = u.BuildingID
		INNER JOIN Property p on p.PropertyID = b.PropertyID
		INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						  AND l.leaseid = (SELECT TOP 1 LeaseID
											FROM Lease 
												INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = LeaseStatus
											WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
											ORDER BY o.OrderBy)
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
								 AND pl.personLeaseID = (SELECT TOP 1 PersonLeaseID
															FROM PersonLease 
															WHERE LeaseID = l.LeaseID													
															ORDER BY pl.orderby) 
		INNER JOIN Person per on per.PersonID = pl.PersonID
	WHERE l.LeaseStatus IN (SELECT Value FROM @statuses)
	  AND p.PropertyID = @propertyID
	  AND ulg.AccountID = @accountID
	ORDER BY u.PaddedNumber
																																									
END



GO
