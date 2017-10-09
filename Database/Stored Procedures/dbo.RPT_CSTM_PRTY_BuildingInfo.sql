SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 8, 2016
-- Description:	Custom Something for Joshie
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_PRTY_BuildingInfo] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

	SELECT	bldg.BuildingID,
			bldg.PropertyID,
			bldg.Floors,
			bldg.Name,
			bldg.[Description],
			ISNULL(adds.StreetAddress, '') AS 'StreetAddress',
			ISNULL(adds.City, '') AS 'City',
			ISNULL(adds.[State], '') AS [State],
			ISNULL(adds.Zip, '') AS Zip
		FROM Building bldg
			INNER JOIN @propertyIDs pIDs ON bldg.PropertyID = pIDs.Value
			LEFT JOIN [Address] adds ON bldg.AddressID = adds.AddressID

END

GO
