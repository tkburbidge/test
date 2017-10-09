SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:	Sam Bryan	
-- Create date: Dec 17 2015
-- Description:	Generates the data for the Building Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_BLDG_BuildingSummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #AllBuildings (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		BuildingID uniqueidentifier not null,
		BuildingName nvarchar(15) not null,
		StreetAddress nvarchar(500) null,
		City nvarchar(50) null,
		[State] nvarchar(50) null,
		Zip nvarchar(20) null,
		NumberOfUnits int null,
		TotalSquareFootage int null,
		[Description] nvarchar(500) null
	)

	INSERT INTO #AllBuildings
	SELECT	p.PropertyID,
			p.Name,
			b.BuildingID,
			b.Name,
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			COUNT(*) as 'NumberOfUnits',
			SUM(u.SquareFootage) as 'TotalSquareFootage',
			b.[Description]
	FROM Building b
		INNER JOIN Property p on b.PropertyID = p.PropertyID
		INNER JOIN Unit u ON u.BuildingID = b.BuildingID
		LEFT JOIN [Address] a ON b.AddressID = a.AddressID
	WHERE b.AccountID = @accountID
	  AND b.PropertyID IN (SELECT Value FROM @propertyIDs)
	  AND u.ExcludedFromOccupancy = 0
	  AND u.DateRemoved IS NULL
	GROUP BY p.Name, p.PropertyID, b.Name, b.BuildingID, a.StreetAddress, a.City, a.[State], a.Zip, b.[Description]


	SELECT * FROM #AllBuildings #ab ORDER BY PropertyName, BuildingName
END
GO
