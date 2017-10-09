SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AddPhoneNumbers] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@integrationPartnerID int = 0,
	@propertyID uniqueidentifier = null,
	@phoneNumbers StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #NewPhoneNumbers (
		PhoneNumber nvarchar(50) null)
		
	CREATE TABLE #AllPhoneNumbers (
		Sequence int identity,
		PhoneNumber nvarchar(50) null)
		
	CREATE TABLE #Persons (
		Sequence int identity,
		PersonID uniqueidentifier)
	
	INSERT #NewPhoneNumbers 
		SELECT Value FROM @phoneNumbers
		
	INSERT PropertyPhoneNumber
		SELECT PhoneNumber, @accountID, @propertyID, @integrationPartnerID, CAST(1 AS bit)
			FROM #NewPhoneNumbers
			
	INSERT #AllPhoneNumbers
		SELECT PhoneNumber
			FROM PropertyPhoneNumber
			WHERE PropertyID = @propertyID
			  AND IsActive = 1
			  
	INSERT #Persons
		SELECT DISTINCT per.PersonID
			FROM Person per
				INNER JOIN PersonType pt ON per.PersonID = pt.PersonID AND pt.[Type] IN ('Resident')
				INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID AND ptp.PropertyID = @propertyID
				INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID AND pl.ResidencyStatus IN ('Current', 'Under Eviction')

	INSERT #Persons
		SELECT DISTINCT per.PersonID
			FROM Person per
				INNER JOIN PersonType pt ON per.PersonID = pt.PersonID AND pt.[Type] IN ('Resident')
				INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID AND ptp.PropertyID = @propertyID
				INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID AND pl.ResidencyStatus NOT IN ('Current', 'Under Eviction')
				
	INSERT #Persons
		SELECT DISTINCT per.PersonID
			FROM Person per
				INNER JOIN PersonType pt ON per.PersonID = pt.PersonID AND pt.[Type] NOT IN ('Resident')
				INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID AND ptp.PropertyID = @propertyID
			WHERE per.PersonID NOT IN (SELECT PersonID FROM #Persons)

	-- This should delete the second and all subsequent occurrences of the PersonID in the #Persons table.  
	-- The first occurrence should be the Resident record, if one exists.
	DELETE #p2
		FROM #Persons #p1
			INNER JOIN #Persons #p2 ON #p1.PersonID = #p2.PersonID AND #p1.Sequence < #p2.Sequence
			
	-- Delete all PersonSMSTextPhoneProperty records associated with the Property.
	DELETE PersonSMSTextPhoneProperty
		WHERE PropertyID = @propertyID
		  AND AccountID = @accountID	
		  
	DECLARE @numberOfPhones int = (SELECT MAX(Sequence) FROM #AllPhoneNumbers)
		  
	IF (@numberOfPhones <> 0)
	BEGIN
	    SET NOCOUNT OFF; -- Used for AdminScripts
		INSERT PersonSMSTextPhoneProperty
			SELECT @accountID, #per.PersonID, @propertyID, #allNumbers.PhoneNumber
				FROM #Persons #per
					INNER JOIN #AllPhoneNumbers #allNumbers ON (#per.Sequence % @numberOfPhones) = (#allNumbers.Sequence - 1)
	END
			
END
GO
