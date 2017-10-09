SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 15, 2012
-- Description:	Gets UnitNotes for selected properties, and selected types.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_UNT_UnitNotes] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@noteTypeIDs GuidCollection READONLY,
	@startDate datetime = null,
	@endDate datetime = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	p.Name AS 'PropertyName',
			u.UnitID AS 'UnitID',
			u.Number AS 'Unit',
			b.Name AS 'Building',
			u.[Floor] AS 'Floor',
			ut.Name AS 'UnitType',
			--ut.SquareFootage AS 'SquareFeet',
			u.SquareFootage AS 'SquareFeet',
			un.DateCreated AS 'Date',
			pli.Name AS 'NoteType',
			un.[Description] AS 'Description',
			un.Notes AS 'Notes',
			pr.PreferredName + ' ' + pr.LastName AS 'EmployeeName'
		FROM Unit u
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN UnitNote un ON u.UnitID = un.UnitID
			INNER JOIN PickListItem pli ON un.NoteTypeID = pli.PickListItemID
			INNER JOIN Person pr ON un.PersonID = pr.PersonID
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND un.NoteTypeID IN (SELECT Value FROM @noteTypeIDs)
		  AND (((@accountingPeriodID IS NULL) AND (un.[Date] >= @startDate) AND (un.[Date] <= @endDate))

		    OR ((@accountingPeriodID IS NOT NULL) AND (un.[Date] >= @startDate) AND (un.[Date] <= @endDate)))

		ORDER BY u.PaddedNumber, un.DateCreated		  
END
GO
