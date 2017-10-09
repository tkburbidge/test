SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 9, 2012
-- Description:	Get Units for an autobill
-- =============================================
CREATE PROCEDURE [dbo].[GetAutobillUnitInfo] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT DISTINCT u.UnitID, u.Number, u.UnitTypeID, us.[Name] AS 'UnitStatus', us.StatusLedgerItemTypeID, u.PaddedNumber
	FROM Unit u
		INNER JOIN Building b on u.BuildingID = b.BuildingID 
		INNER JOIN UnitNote un on un.UnitNoteID = (SELECT TOP 1 UnitNoteID FROM UnitNote WHERE UnitNote.UnitID = u.UnitID ORDER BY UnitNote.[Date] DESC, UnitNote.DateCreated DESC)
		INNER JOIN UnitStatus us on un.UnitStatusID = us.UnitStatusID
	WHERE b.PropertyID = @propertyID 
		AND b.AccountID = @accountID		
		AND u.IsHoldingUnit = 0
		AND (u.DateRemoved IS NULL)
	ORDER BY u.PaddedNumber
END

GO
