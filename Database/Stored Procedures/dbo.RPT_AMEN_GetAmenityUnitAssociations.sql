SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 18, 2014
-- Description:	Associates Amenities to Units
-- =============================================
CREATE PROCEDURE [dbo].[RPT_AMEN_GetAmenityUnitAssociations] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #AmenitiesAndUnits (
		PropertyID uniqueidentifier not null,
		AmenityID uniqueidentifier not null,
		AmenityName nvarchar(100) not null,
		UnitID uniqueidentifier null,
		UnitNumber nvarchar(50) null,
		PaddedNumber nvarchar(50) null,
		IsAssociated bit null)
		
	CREATE TABLE #MyProperties (
		PropertyID uniqueidentifier not null)
		
	INSERT #MyProperties
		SELECT Value FROM @propertyIDs
		
	INSERT #AmenitiesAndUnits
		SELECT #myProps.PropertyID, amen.AmenityID, amen.Name, u.UnitID, u.Number, u.PaddedNumber, CAST(0 AS bit)
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Amenity amen ON ut.PropertyID = amen.PropertyID AND amen.[Level] = 'Unit'
				INNER JOIN #MyProperties #myProps ON ut.PropertyID = #myProps.PropertyID AND amen.PropertyID = #myProps.PropertyID
			WHERE (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		
	UPDATE #AmenAndUs SET IsAssociated = CAST(1 AS Bit)
		FROM #AmenitiesAndUnits #AmenAndUs
			INNER JOIN UnitAmenity ua ON #AmenAndUs.AmenityID = ua.AmenityID AND #AmenAndUs.UnitID = ua.UnitID AND ua.DateEffective <= @date
				
	SELECT	prop.Name AS 'PropertyName',
			#AmenAndUs.UnitID,
			#AmenAndUs.UnitNumber,
			#AmenAndUs.PaddedNumber,
			#AmenAndUs.AmenityID,
			#AmenAndUs.AmenityName,
			#AmenAndUs.IsAssociated
		FROM #AmenitiesAndUnits #AmenAndUs
			INNER JOIN Property prop ON #AmenAndUs.PropertyID = prop.PropertyID
		ORDER BY prop.Name, #AmenAndUs.PaddedNumber
			
END
GO
