SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 16, 2017
-- Description:	Gets the Rentlytics Unit List
-- =============================================
CREATE PROCEDURE [dbo].[TSK_RENTLYTICS_UnitList] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null)

	INSERT #Properties
		SELECT Value 
			FROM @propertyIDs

	SELECT	DISTINCT
			p.Abbreviation AS 'property_code',
			ut.Name AS 'unit_type_code',
			ut.Name AS 'unit_type_name',
			u.Number AS 'unit_code',
			u.Number AS 'unit_name',
			ut.Bedrooms AS 'bedrooms',
			ut.Bathrooms AS 'bathrooms',
			ut.SquareFootage AS 'square_feet'
		FROM Unit u
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN #Properties #prop ON ut.PropertyID = #prop.PropertyID
			INNER JOIN Property p ON #prop.PropertyID = p.PropertyID
		ORDER BY p.Abbreviation, ut.Name, u.Number



END
GO
