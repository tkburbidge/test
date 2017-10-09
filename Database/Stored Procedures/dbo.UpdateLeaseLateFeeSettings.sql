SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Jordan Betteridge
-- Create date: 02/25/2013
-- Description:	Updates all current and pending leases
-- =============================================
CREATE PROCEDURE [dbo].[UpdateLeaseLateFeeSettings] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection readonly, 
	-- Other five properties that need to be updated
	@lateFeeScheduleID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	UPDATE l
	  SET 
		-- update Lease table fields to the parameters passed in
		LateFeeScheduleID = @lateFeeScheduleID
	  FROM Lease AS l
	  INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
	  INNER JOIN Unit u ON u.UnitID = ulg.UnitID
	  INNER JOIN Building b on b.BuildingID = u.BuildingID
	  WHERE l.AccountID = @accountID	
		AND b.PropertyID in (select value from @propertyIDs)
		AND l.LeaseStatus IN ('Current', 'Pending', 'Pending Renewal', 'Pending Transfer', 'Under Eviction')

END
GO
