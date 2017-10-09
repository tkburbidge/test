SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 16, 1017
-- Description:	Get the Rentlytics Property List.
-- =============================================
CREATE PROCEDURE [dbo].[TSK_RENTLYTICS_GetPropertyList] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

	CREATE TABLE #PropertyList (
		property_code nvarchar(50) not null,
		name nvarchar(200) null,
		street_address nvarchar(100) null,
		city nvarchar(100) null,
		[state] nvarchar(50) null,
		postal_code nvarchar(100) null,
		launch_date date null)

	INSERT #PropertyList
		SELECT	p.Abbreviation,
				p.Name,
				addr.StreetAddress,
				addr.City,
				addr.[State],
				addr.Zip,
				p.DateAcquired
			FROM @propertyIDs pIDs
				INNER JOIN Property p ON pIDs.Value = p.PropertyID
				INNER JOIN [Address] addr ON p.AddressID = addr.AddressID

	SELECT	DISTINCT
			property_code,
			name,
			street_address,
			city,
			[state],
			postal_code,
			CONVERT(varchar(10), launch_date, 120) AS 'launch_date'
		FROM #PropertyList
		ORDER BY name

END
GO
