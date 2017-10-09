SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Joshua Grigg
-- Create date: July 1, 2015
-- Description:	Gets merge data (key and value) for portal merge fields
-- =============================================
CREATE PROCEDURE [dbo].[GetPortalMergeData]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@fieldNames StringCollection readonly,
	@propertyID uniqueIdentifier = null	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PortalMergeData
	(
		FieldName nvarchar(500),
		Value nvarchar(max)
	)

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyName'))
		BEGIN
			INSERT INTO #PortalMergeData
				SELECT 'PropertyName', p.Name
				FROM Property p 
				WHERE   p.PropertyID = @propertyID 
					AND p.AccountID = @accountID
	END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyStreetAddress'))
	BEGIN
		INSERT INTO #PortalMergeData
			SELECT 'PropertyStreetAddress', ISNULL(a.StreetAddress, '')
			FROM Property p
			LEFT JOIN [Address] a ON a.AddressID = p.AddressID
			WHERE   p.PropertyID = @propertyID 
				AND p.AccountID = @accountID
	END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyCity'))
	BEGIN
		INSERT INTO #PortalMergeData
			SELECT 'PropertyCity', ISNULL(a.City, '')
			FROM Property p
			LEFT JOIN [Address] a ON a.AddressID = p.AddressID
			WHERE   p.PropertyID = @propertyID 
				AND p.AccountID = @accountID
	END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyState'))
	BEGIN
		INSERT INTO #PortalMergeData
			SELECT 'PropertyState', ISNULL(a.[State], '')
			FROM Property p
			LEFT JOIN [Address] a ON a.AddressID = p.AddressID
			WHERE   p.PropertyID = @propertyID 
				AND p.AccountID = @accountID
	END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyZipCode'))
	BEGIN
		INSERT INTO #PortalMergeData
			SELECT 'PropertyZipCode', ISNULL(a.Zip, '')
			FROM Property p
			LEFT JOIN [Address] a ON a.AddressID = p.AddressID
			WHERE   p.PropertyID = @propertyID 
				AND p.AccountID = @accountID
	END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPhoneNumber'))
	BEGIN
		INSERT INTO #PortalMergeData
			SELECT 'PropertyPhoneNumber', ISNULL(p.PhoneNumber, '')
			FROM Property p 
			WHERE   p.PropertyID = @propertyID 
				AND p.AccountID = @accountID
	END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyEmail'))
	BEGIN
		INSERT INTO #PortalMergeData
			SELECT 'PropertyEmail', ISNULL(p.Email, '')
			FROM Property p 
			WHERE   p.PropertyID = @propertyID 
				AND p.AccountID = @accountID
	END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyWebsite'))
	BEGIN
		INSERT INTO #PortalMergeData
			SELECT 'PropertyWebsite', ISNULL(p.Website, '')
			FROM Property p
			WHERE   p.PropertyID = @propertyID 
				AND p.AccountID = @accountID
	END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPortalWebsite'))
	BEGIN
		INSERT INTO #PortalMergeData
			SELECT 'PropertyPortalWebsite', ('https://' + s.Subdomain + '.myresman.com/Portal/Access/SignIn/' + p.Abbreviation)
			FROM Property p
			INNER JOIN Settings s ON s.AccountID = p.AccountID		
			WHERE   p.AccountID = @accountID
				AND p.PropertyID = @propertyID
	END

    SELECT * FROM #PortalMergeData WHERE Value IS NOT NULL
	
END




GO
