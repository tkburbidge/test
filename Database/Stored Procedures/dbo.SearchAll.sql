SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 18, 2011
-- Description:	Searches tables for Names
-- =============================================
CREATE PROCEDURE [dbo].[SearchAll] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection readonly,
	@partialName nvarchar(50) = null,
	@type nvarchar(1) = null
AS

DECLARE @count bit
DECLARE @rowCount tinyint
DECLARE @startTime datetime2
DECLARE @queryStartTime datetime2
DECLARE @endsWithPartialName nvarchar(25) = null
DECLARE @matchSSN bit = 0

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET @startTime = GETDATE()
	
	CREATE TABLE #SearchResults (
		OrderByID int IDENTITY,
		ObjectID uniqueidentifier not null,
		Type char(1) not null,
		AltType char(500) null,
		AltObjectID uniqueidentifier null,
		AltObjectID2 uniqueidentifier null,
		Name nvarchar(500) not null,
		Property nvarchar(500) null,
		Details nvarchar(500) null,
		ImageUri nvarchar(500) null,
		OrderBy int not null,
		OrderBy2 int null
		)
	
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs
	
	SET @count = (SELECT COUNT(*) FROM @propertyIDs)
	
	IF (ISNUMERIC(REPLACE(@partialName, '%', '')) = 1)
	BEGIN
		SET @endsWithPartialName = '%' + REPLACE(@partialName, '%', '')
		SET @matchSSN = CASE WHEN LEN(@endsWithPartialName) >= 5 THEN 1 ELSE 0 END
	END
	
	IF @type IS NULL
	BEGIN
		SELECT @rowCount = Settings.RowsReturnedFromSearch
			FROM Settings
			WHERE Settings.AccountID = @accountID
	END

	IF (LEN(@partialName) = 2)
	BEGIN
		SET @type = 'L'
	END
	
	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'R'
	BEGIN		
		INSERT #SearchResults
		SELECT
			UnitLeaseGroupPerson.PersonID,
			'R',		-- Residents
			(CASE WHEN UnitLeaseGroupPerson.IsMale = 0 THEN 'female' ELSE 'male' END),
			(CASE WHEN PersonLease.LeaseStatus = 'Pending Renewal' THEN COALESCE(CurrentLease.LeaseID, PersonLease.LeaseID)					  
				      ELSE PersonLease.LeaseID END),
			NULL,
			UnitLeaseGroupPerson.Name,
			UnitLeaseGroupPerson.Property,
			PersonLease.ResidencyStatus,	
			d.ThumbnailUri,	 
			1 AS 'OrderBy',
			null
		FROM 
		   (SELECT DISTINCT
				Person.PersonID,
				Person.PreferredName + ' ' + Person.LastName AS Name,
				UnitLeaseGroup.UnitLeaseGroupID,		
				Person.IsMale,
				Property.Abbreviation + '-' + Unit.Number AS Property
			FROM PersonLease
				INNER JOIN Lease on Lease.LeaseID = PersonLease.LeaseID
				INNER JOIN UnitLeaseGroup on UnitLeaseGroup.UnitLeaseGroupID = Lease.UnitLeaseGroupID
				INNER JOIN Unit on Unit.UnitID = UnitLeaseGroup.UnitID	
				INNER JOIN Building ON Building.BuildingID = Unit.BuildingID
				INNER JOIN Person on Person.PersonID = PersonLease.PersonID
				INNER JOIN PersonType on Person.PersonID = PersonType.PersonID AND PersonType.[Type] = 'Resident'
				INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID AND PersonTypeProperty.PropertyID = Building.PropertyID
				INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = Property.PropertyID			
			WHERE 
					--AND PersonType.Type = 'Resident'  
					PersonLease.AccountID = @accountID
					AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
						OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
						OR Person.LastName LIKE @partialName
						OR Person.Email LIKE @partialName
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone1) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone1) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone2) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone2) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone3) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone3) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (@matchSSN = 1 AND Person.SSNDisplay LIKE @partialName)
						OR (@matchSSN = 1 AND @endsWithPartialName IS NOT NULL AND Person.SSNDisplay LIKE @endsWithPartialName))) AS UnitLeaseGroupPerson
			CROSS APPLY (SELECT TOP 1 Lease.LeaseID, PersonLease.ResidencyStatus, Lease.LeaseStatus, Lease.UnitLeaseGroupID
						 FROM Lease
							  INNER JOIN PersonLease ON PersonLease.LeaseID = Lease.LeaseID
							  INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
						 WHERE Lease.UnitLeaseGroupID = UnitLeaseGroupPerson.UnitLeaseGroupID
							   AND PersonLease.PersonID = UnitLeaseGroupPerson.PersonID
						 ORDER BY Ordering.OrderBy) AS PersonLease
			-- If the resident is pending renewal, we want to show they are pending renewal
			-- but direct them to the current lease
			OUTER APPLY (SELECT TOP 1 Lease.LeaseID
						 FROM Lease
						 WHERE PersonLease.UnitLeaseGroupID = Lease.UnitLeaseGroupID
							AND Lease.LeaseStatus IN ('Current', 'Under Eviction')) AS CurrentLease					
			LEFT JOIN Document d ON d.ObjectID = UnitLeaseGroupPerson.PersonID AND d.[Type] = 'Person'	
			INNER JOIN Ordering ON PersonLease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
		ORDER BY Ordering.OrderBy
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'R', @queryStartTime, GETDATE())
	END
	
	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'P'
	BEGIN
		INSERT #SearchResults
		SELECT 
				Person.PersonID,
				'P',		-- Prospects
				(CASE WHEN Person.IsMale = 0 THEN 'female' ELSE 'male' END),
				Property.PropertyID,
				NULL,
				Person.PreferredName + ' ' + Person.LastName,
				Property.Abbreviation,
				Prospect.MovingFrom, 
				d.ThumbnailUri,
				4 AS 'OrderBy',
				null			
			FROM PersonTypeProperty 
				INNER JOIN PersonType ON PersonTypeProperty.PersonTypeID = PersonType.PersonTypeID
				INNER JOIN Person ON PersonType.PersonID = Person.PersonID 
											  AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
													OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
													OR Person.LastName LIKE @partialName
													OR Person.Email LIKE @partialName
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone1) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone1) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone2) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone2) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone3) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone3) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
													OR (@matchSSN = 1 AND Person.SSNDisplay LIKE @partialName)
													OR (@matchSSN = 1 AND @endsWithPartialName IS NOT NULL AND Person.SSNDisplay LIKE @endsWithPartialName))	
											  AND (NOT EXISTS(SELECT PersonType.PersonTypeID 
																FROM PersonType pt2
																	INNER JOIN PersonTypeProperty ptp2 ON pt2.PersonTypeID = ptp2.PersonTypeID
																WHERE pt2.Type = 'Resident'
																  AND pt2.PersonID = Person.PersonID
																  AND ptp2.PropertyID = PersonTypeProperty.PropertyID))	
				INNER JOIN Prospect ON Person.PersonID = Prospect.PersonID
				INNER JOIN Property ON PersonTypeProperty.PropertyID = Property.PropertyID
				LEFT JOIN Document d ON Person.PersonID = d.ObjectID AND d.[Type] = 'Person'
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = Property.PropertyID			
			WHERE PersonTypeProperty.AccountID = @accountID
				AND Prospect.LostDate IS NULL
			
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'P', @queryStartTime, GETDATE())
	END
	
	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'P'
	BEGIN							  
		INSERT #SearchResults
		SELECT 
				Prospect.PersonID,
				'P',		-- Prospects Roommates
				(CASE WHEN Person.IsMale = 0 THEN 'female' ELSE 'male' END),
				Property.PropertyID,
				Person.PersonID,
				Person.PreferredName + ' ' + Person.LastName,
				Property.Abbreviation,
				Prospect.MovingFrom,  
				d.ThumbnailUri,
				4 AS 'OrderBy',
				null	
	
			  FROM PersonTypeProperty
				INNER JOIN PersonType on PersonTypeProperty.PersonTypeID = PersonType.PersonTypeID AND PersonType.[Type] = 'Prospect'
				INNER JOIN Person ON PersonType.PersonID = Person.PersonID 
										AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
													OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
													OR Person.LastName LIKE @partialName
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone1) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone1) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone2) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone2) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone3) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone3) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
													OR (@matchSSN = 1 AND Person.SSNDisplay LIKE @partialName)
													OR (@matchSSN = 1 AND @endsWithPartialName IS NOT NULL AND Person.SSNDisplay LIKE @endsWithPartialName))
											  AND (NOT EXISTS(SELECT PersonType.PersonTypeID 
																FROM PersonType pt2
																	INNER JOIN PersonTypeProperty ptp2 ON pt2.PersonTypeID = ptp2.PersonTypeID
																WHERE pt2.Type = 'Resident'
																  AND pt2.PersonID = Person.PersonID
																  AND ptp2.PropertyID = PersonTypeProperty.PropertyID))	
				INNER JOIN Property ON PersonTypeProperty.PropertyID = Property.PropertyID
				INNER JOIN ProspectRoommate ON Person.PersonID = ProspectRoommate.PersonID
				INNER JOIN Prospect ON ProspectRoommate.ProspectID = Prospect.ProspectID
				LEFT JOIN Document d ON Person.PersonID = d.ObjectID AND d.[Type] = 'Person'
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = Property.PropertyID			
			WHERE PersonTypeProperty.AccountID = @accountID
				AND Prospect.LostDate IS NULL
			 
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'Q', @queryStartTime, GETDATE())
	END								  					  

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'N'
	BEGIN
		INSERT #SearchResults
		SELECT 
				per.PersonID,
				'N',		-- Non-Resident Accounts
				(CASE WHEN per.IsMale = 0 THEN 'female' ELSE 'male' END),
				ptp.PropertyID,
				null,
				per.PreferredName + ' ' + per.LastName,
				null,
				null,  
				null,
				5 AS 'OrderBy',
				null	
			  FROM PersonTypeProperty ptp
			    INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = ptp.PropertyID			
				INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID AND pt.[Type] = 'Non-Resident Account'
				INNER JOIN Person per ON pt.PersonID = per.PersonID AND ((per.FirstName + ' ' + per.LastName LIKE @partialName)
																			OR (per.PreferredName + ' ' + per.LastName LIKE @partialName)
																			OR (per.LastName LIKE @partialName)
																			OR (per.PreferredName LIKE @partialName)
																			OR (@matchSSN = 1 AND per.SSNDisplay LIKE @partialName)
																			OR (@matchSSN = 1 AND @endsWithPartialName IS NOT NULL AND per.SSNDisplay LIKE @endsWithPartialName))
			WHERE ptp.AccountID = @accountID
			
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'N', @queryStartTime, GETDATE())
	END
	
	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'E'
	BEGIN									
		INSERT #SearchResults
		SELECT DISTINCT
				Person.PersonID,
				'E',			-- Employees
				(CASE WHEN Person.IsMale = 0 THEN 'female' ELSE 'male' END),
				[User].UserID,
				null,
				Person.PreferredName + ' ' + Person.LastName,
				null,
				Employee.Title,  
				d.ThumbnailUri,
				6 AS 'OrderBy',
				null	
			FROM PersonTypeProperty 
				INNER JOIN PersonType ON PersonTypeProperty.PersonTypeID = PersonType.PersonTypeID AND PersonType.[Type] = 'Employee'
				INNER JOIN Person ON PersonType.PersonID = Person.PersonID
										AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
											OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
											OR Person.LastName LIKE @partialName
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone1) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone1) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone2) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone2) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone3) LIKE '%'+dbo.fnRemoveNonNumericCharacters(@partialName) AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
						OR (dbo.fnRemoveNonNumericCharacters(Person.Phone3) LIKE dbo.fnRemoveNonNumericCharacters(@partialName)+'%' AND dbo.fnRemoveNonNumericCharacters(@partialName) != '')
											OR (@matchSSN = 1 AND Person.SSNDisplay LIKE @partialName)
											OR (@matchSSN = 1 AND @endsWithPartialName IS NOT NULL AND Person.SSNDisplay LIKE @endsWithPartialName))
				LEFT JOIN [User] ON Person.PersonID = [User].PersonID
				INNER JOIN Employee ON Person.PersonID = Employee.PersonID
				INNER JOIN Property ON PersonTypeProperty.PropertyID = Property.PropertyID
				LEFT JOIN Document d ON Person.PersonID = d.ObjectID AND d.[Type] = 'Person'
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = PersonTypeProperty.PropertyID			
			WHERE PersonTypeProperty.AccountID = @accountID
			
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'E', @queryStartTime, GETDATE())
	END					

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'T'
	BEGIN	
		INSERT #SearchResults
		SELECT 
				Person.PersonID,
				'T',			-- Pets
				Pet.[Type],
				PersonLease.LeaseID,
				null,
				Pet.Name,
				Property.Abbreviation + '-' + Unit.Number,
				Person.PreferredName + ' ' + Person.LastName,  
				d.ThumbnailUri,
				9 AS 'OrderBy',
				null				
			FROM Person
				INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
				INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID			
				CROSS APPLY (SELECT TOP 1 Lease.LeaseID, PersonLease.ResidencyStatus, Lease.UnitLeaseGroupID FROM PersonLease 
							 INNER JOIN Lease on Lease.LeaseID = PersonLease.LeaseID
							 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
							 WHERE PersonLease.PersonID = Person.PersonID
							 ORDER BY Ordering.OrderBy) AS PersonLease
				INNER JOIN UnitLeaseGroup on UnitLeaseGroup.UnitLeaseGroupID = PersonLease.UnitLeaseGroupID
				INNER JOIN Unit on UnitLeaseGroup.UnitID = Unit.UnitID
				INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID
				INNER JOIN Pet on Pet.PersonID = Person.PersonID
				LEFT JOIN Document d ON d.ObjectID = Pet.PetID AND d.[Type] = 'Pet'
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = Property.PropertyID			
			WHERE PersonType.Type = 'Resident'
			  AND Pet.Name LIKE @partialName
			  AND Pet.AccountID = @accountID
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'T', @queryStartTime, GETDATE())
	END			  

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'A'
	BEGIN	
		INSERT #SearchResults
		SELECT 
				Person.PersonID,
				'A',			-- Automobiles
				null,
				PersonLease.LeaseID,
				null,
				ISNULL(Automobile.LicensePlateNumber + ' - ', '') + ISNULL(Automobile.Make, '') + ' ' + ISNULL(Automobile.Model, '') + ' ' + ISNULL('(' + Automobile.PermitNumber + ')', ''),
				Property.Abbreviation + '-' + Unit.Number,
				Person.PreferredName + ' ' + Person.LastName,  
				null,
				9 AS 'OrderBy',
				null				
			FROM Person
				INNER JOIN PersonType on Person.PersonID = PersonType.PersonID AND PersonType.[Type] = 'Resident'
				INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID			
				CROSS APPLY (SELECT TOP 1 Lease.LeaseID, PersonLease.ResidencyStatus, Lease.UnitLeaseGroupID FROM PersonLease 
							 INNER JOIN Lease on Lease.LeaseID = PersonLease.LeaseID
							 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
							 WHERE PersonLease.PersonID = Person.PersonID
							 ORDER BY Ordering.OrderBy) AS PersonLease
				INNER JOIN UnitLeaseGroup on UnitLeaseGroup.UnitLeaseGroupID = PersonLease.UnitLeaseGroupID
				INNER JOIN Unit on UnitLeaseGroup.UnitID = Unit.UnitID
				INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID
				INNER JOIN Automobile on Automobile.PersonID = Person.PersonID
					AND (Automobile.LicensePlateNumber LIKE @partialName OR Automobile.PermitNumber LIKE @partialName)
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = Property.PropertyID			
			WHERE  Automobile.AccountID = @accountID
			
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'A', @queryStartTime, GETDATE())
	END			  

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'L'
	BEGIN
		INSERT #SearchResults
			SELECT DISTINCT cl.LeaseID,
					'L',					-- Leases
					CASE WHEN per.IsMale = 0 THEN 'female' ELSE 'male' END,
					null, null,
					per.PreferredName + ' ' + per.LastName AS 'Name',
					p.Abbreviation + '-' + u.Number,
					COALESCE(pl.LeaseStatus, cl.LeaseStatus),
					d.ThumbnailUri, 
					LEN(u.Number) AS 'OrderBy',
					CASE WHEN (pl.LeaseID IS NOT NULL) THEN 2 ELSE o.OrderBy END AS 'OrderBy2'
				FROM UnitLeaseGroup ulg
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID AND u.Number LIKE @partialName
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
					INNER JOIN Property p ON ut.PropertyID = p.PropertyID
					INNER JOIN Lease cl ON ulg.UnitLeaseGroupID = cl.UnitLeaseGroupID AND cl.LeaseID = (SELECT TOP 1 LeaseID FROM Ordering o
																												INNER JOIN Lease l1 ON l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																																		AND l1.LeaseStatus IN ('Current', 'Under Eviction', 'Evicted', 'Pending', 'Former', 'Cancelled', 'Denied', 'Pending Transfer')
																												WHERE o.Value = l1.LeaseStatus 
																													AND o.[Type] = 'Lease'																																	
																												ORDER BY o.OrderBy)
					LEFT JOIN Lease pl ON ulg.UnitLeaseGroupID = pl.UnitLeaseGroupID AND pl.LeaseID = (SELECT TOP 1 LeaseID 
																									   FROM Lease l2 
																									   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																											AND l2.LeaseStatus IN ('Pending Renewal'))
					INNER JOIN PersonLease perl ON ((perl.LeaseID = cl.LeaseID)
														AND perl.MainContact = 1)									
					INNER JOIN Person per ON perl.PersonID = per.PersonID
					LEFT JOIN Document d ON per.PersonID = d.ObjectID AND d.[Type] = 'Person'
					INNER JOIN Ordering o ON o.Value = cl.LeaseStatus AND o.[Type] = 'Lease'
					INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID			
				WHERE ulg.AccountID = @accountID
				ORDER BY LEN(u.Number), 'OrderBy2'		
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'L', @queryStartTime, GETDATE())
	END

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'U'
	BEGIN				
		INSERT #SearchResults
		SELECT 
				Unit.UnitID,
				'U',			-- Units
				null,
				null,
				null,
				Unit.Number,
				Property.Abbreviation,
				UnitType.Name,  
				null,
				3 AS 'OrderBy',
				null	
			FROM Unit 
				INNER JOIN Building on Building.BuildingID = Unit.BuildingID
				INNER JOIN Property on Property.PropertyID = Building.PropertyID
				INNER JOIN UnitType on UnitType.UnitTypeID = Unit.UnitTypeID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = Property.PropertyID			
			WHERE Unit.Number LIKE @partialName
			ORDER BY Unit.PaddedNumber	
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'U', @queryStartTime, GETDATE())
	END						
	
	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'I'
	BEGIN
		INSERT #SearchResults
		SELECT DISTINCT Invoice.InvoiceID,
				'I',			-- Invoices
				null,
				null,
				null,
				Invoice.Number + ' - ' + Vendor.CompanyName,
				CASE WHEN (1 < (SELECT COUNT(DISTINCT ili1.PropertyID)
									FROM InvoiceLineItem ili1
										--INNER JOIN [Transaction] t1 ON ili1.TransactionID = t1.TransactionID
										--INNER JOIN Property p1 ON t1.TransactionID = p1.PropertyID
									WHERE ili1.InvoiceID = Invoice.InvoiceID))
					THEN CONVERT(nvarchar(10),Invoice.AccountingDate, 110)
					ELSE Property.Abbreviation + ' - ' + CONVERT(nvarchar(10),Invoice.AccountingDate, 110) END,
			   (CASE WHEN Invoice.Credit = 1 THEN -Invoice.Total ELSE Invoice.Total END),  
				null,
				7 AS 'OrderBy',
				null	
			FROM Invoice
				INNER JOIN InvoiceLineItem on Invoice.InvoiceID = InvoiceLineItem.InvoiceID
				--INNER JOIN [Transaction] on InvoiceLineItem.TransactionID = [Transaction].TransactionID
				INNER JOIN Vendor on Vendor.VendorID = Invoice.VendorID
				INNER JOIN Property on Property.PropertyID = InvoiceLineItem.PropertyID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = Property.PropertyID			
			WHERE Invoice.Number LIKE @partialName
			  AND Invoice.AccountID = @accountID
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'I', @queryStartTime, GETDATE())
	END			  

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'V'
	BEGIN
		INSERT #SearchResults
		SELECT DISTINCT
				Vendor.VendorID,
				'V',			-- Vendors
				null,
				null,
				null,
				Vendor.CompanyName,
				null,
				null,  
				null,
				8 AS 'OrderBy',
				null	
			FROM Vendor			
				LEFT JOIN VendorProperty on VendorProperty.VendorID = Vendor.VendorID			
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = VendorProperty.PropertyID			
			WHERE (Vendor.CompanyName LIKE '%' + @partialName
					OR Vendor.Abbreviation LIKE '%' + @partialName)
			  AND Vendor.AccountID = @accountID
			  AND Vendor.IsActive = 1
			  AND Vendor.IsOwner = 0
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'V', @queryStartTime, GETDATE())
	END			  

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'B'
	BEGIN
		INSERT #SearchResults
		SELECT DISTINCT
				BankAccount.BankAccountID,
				'B',			-- BankAccounts
				null,
				null,
				null,
				BankAccount.AccountName,
				BankAccount.BankName,
				BankAccount.AccountNumberDisplay,  
				null,
				10 AS 'OrderBy',
				null	
			FROM BankAccount			
				INNER JOIN BankAccountProperty on BankAccountProperty.BankAccountID = BankAccount.BankAccountID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = BankAccountProperty.PropertyID			
			WHERE (BankAccount.AccountName LIKE @partialName 
				   OR BankAccount.BankName LIKE @partialName 
				   OR BankAccount.AccountNumberDisplay LIKE @partialName)
			  AND BankAccount.AccountID = @accountID
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'B', @queryStartTime, GETDATE())
	END				   

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'W'
	BEGIN
		INSERT #SearchResults 
		SELECT DISTINCT
			wo.WorkOrderID,
			'W',				-- Work Orders
			null,
			null,
			null,
			CAST(wo.Number AS nvarchar(50)) + ' - ' + pli.Name,
			p.Abbreviation,
			wo.Status, 
			null,
			11 AS 'OrderBy',
			null	
			FROM WorkOrder wo
				INNER JOIN PickListItem pli ON wo.WorkOrderCategoryID = pli.PickListItemID
				INNER JOIN Property p ON wo.PropertyID = p.PropertyID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID			
			WHERE (wo.Number LIKE @partialName
				   OR pli.Name LIKE @partialName)	
			  AND wo.AccountID = @accountID
			  AND wo.[Status] NOT IN ('Cancelled')
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'W', @queryStartTime, GETDATE())	
	END				   
	
	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'G'
	BEGIN	
		INSERT #SearchResults 
		SELECT 
			gl.GLAccountID,
			'G',				-- GL Accounts
			null,
			null,
			null,
			gl.Number + ' - ' + gl.Name,
			NULL,
			NULL,  
			null,
			12 AS 'OrderBy',
			null	
			FROM GLAccount gl					
			WHERE gl.AccountID = @accountID 
			  AND (gl.Number LIKE @partialName
				   OR gl.Name LIKE ('%' + @partialName))
			  AND gl.AccountID = @accountID
			ORDER BY gl.Number
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'G', @queryStartTime, GETDATE())
	END			

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'Y'
	BEGIN	
		INSERT #SearchResults 
		SELECT ObjectID,
			   [Type],
			   null,
			   AltObjectID, 
			   AltObjectID2,
			   Name,
			   Property,
			   Details,
			   ImageUri,
			   OrderBy,
				null
		FROM (SELECT DISTINCT TOP 2147483647
					p.PaymentID AS 'ObjectID',
					'Y' AS 'Type',				-- Payments
					null AS 'AltType',
					null AS 'AltObjectID',
					null AS 'AltObjectID2',
					p.ReferenceNumber + ' - ' + p.[Description] + ' (' + CONVERT(nvarchar(10), p.[Date]) + ')' AS 'Name',
					prop.Abbreviation AS 'Property',
					p.ReceivedFromPaidTo AS 'Details',  
					null AS 'ImageUri',
					13 AS 'OrderBy',
					p.[Date]	
					FROM PaymentTransaction pt
						INNER JOIN Payment p ON pt.PaymentID = p.PaymentID AND p.ReferenceNumber like @partialName AND p.AccountID = @accountID AND p.PaidOut = 0
						INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Payment'
						INNER JOIN Property prop ON t.PropertyID = prop.PropertyID
						INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = prop.PropertyID			
					WHERE  pt.AccountID = @accountID
					ORDER BY p.[Date] DESC) Payments 
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'Y', @queryStartTime, GETDATE())
	END											   	

	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'O' OR @type = 'Z'
	BEGIN
		INSERT #SearchResults 
		SELECT ObjectID,
			   [Type],
			   null,
			   AltObjectID, 
			   AltObjectID2,
			   Name,
			   Property,
			   Details,
			   ImageUri,
			   OrderBy,
				null		 
		FROM (SELECT DISTINCT TOP 2147483647
					bt.ObjectID AS 'ObjectID',
					CASE 
						WHEN (tt.[Group] = 'Invoice') THEN 'O'
						ELSE 'Z' END AS 'Type',				-- Invoice Payments
					null AS 'AltObjectID',
					null AS 'AltObjectID2',
					bt.ReferenceNumber + ' - ' + p.ReceivedFromPaidTo AS 'Name',
					prop.Abbreviation AS 'Property',
					ba.AccountNumberDisplay + ' - ' + ba.AccountName AS 'Details',		
					null AS 'ImageUri',
					14 AS 'OrderBy',
					p.[Date] AS 'Date'	
					FROM BankTransaction bt
					INNER JOIN Payment p ON bt.ObjectID = p.PaymentID
					INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
					INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
					INNER JOIN TransactionType tt on tt.TransactionTypeID = t.TransactionTypeID
					INNER JOIN Property prop ON prop.PropertyID = t.PropertyID
					INNER JOIN BankAccount ba ON ba.BankAccountID = t.ObjectID				
					INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID			
					WHERE bt.AccountID = @accountID 	
					  AND ((tt.Name = 'Payment' AND tt.[Group] = 'Invoice') OR
						   (tt.Name IN ('Check', 'Vendor Credit') AND tt.[Group] = 'Bank'))				 					  
					  AND bt.ReferenceNumber like @partialName
					  AND bt.AccountID = @accountID
					ORDER BY p.[Date] DESC) InvoicePayments
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'O', @queryStartTime, GETDATE())
	END		
	
	--SET @queryStartTime = GETDATE()
	IF @type IS NULL OR @type = 'M'
	BEGIN				
		INSERT #SearchResults
		SELECT 
				li.LedgerItemID,
				'M',			-- Rentable Items
				null,
				null,
				null,
				li.[Description],
				p.Abbreviation,
				lip.Name,  
				null,
				15 AS 'OrderBy',
				null	
			FROM LedgerItem li
				INNER JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
				INNER JOIN Property p on p.PropertyID = lip.PropertyID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID
			WHERE  li.[Description] LIKE @partialName
			  AND li.AccountID = @accountID
			ORDER BY LEN(li.[Description]), li.[Description]
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'M', @queryStartTime, GETDATE())
	END	
	
	
	IF (@type IS NULL OR @type = 'H')
	BEGIN
		INSERT #SearchResults
		SELECT	DISTINCT 
				po.PurchaseOrderID AS 'ObjectID',
				'H' AS 'Type',			-- Purchase Orders
				null AS 'AltType',
				null AS 'AltObjectID',
				null AS 'AltObjectID2',
				po.Number + ' - ' + v.CompanyName AS 'Name',
				CASE WHEN (1 < (SELECT COUNT(DISTINCT PropertyID)
									FROM PurchaseOrderLineItem 
									WHERE PurchaseOrderID = po.PurchaseOrderID))
					THEN p.Name
					ELSE p.Abbreviation + ' - ' + CONVERT(nvarchar(10),po.[Date], 110) END AS 'Property',
				po.Total AS 'Details',
				null AS 'ImageUri',
				15 AS 'OrderBy',
				null AS 'OrderBy2'	
			FROM PurchaseOrder po
				INNER JOIN PurchaseOrderLineItem poli ON po.PurchaseOrderID = poli.PurchaseOrderID 
												AND poli.PropertyID IN (SELECT PropertyID FROM #PropertyIDs)
				INNER JOIN Property p ON poli.PropertyID = p.PropertyID
				INNER JOIN Vendor v ON po.VendorID = v.VendorID
			WHERE po.Number LIKE @partialName
			  AND po.AccountID = @accountID				
	END

	IF (@type IS NULL OR @type = '3')
	BEGIN
		INSERT #SearchResults
		SELECT	DISTINCT 
				et.EmailTemplateID AS 'ObjectID',
				'3' AS 'Type',			-- Email Templates
				null AS 'AltType',
				null AS 'AltObjectID',
				null AS 'AltObjectID2',
				et.Name AS 'Name',
				null,
				et.[Subject] AS 'Details',
				null AS 'ImageUri',
				16 AS 'OrderBy',
				null AS 'OrderBy2'	
			FROM EmailTemplate et
			WHERE et.AccountID = @accountID
				AND (et.Name LIKE @partialName OR et.Subject LIKE @partialName)
	END

	IF @type IS NULL OR @type = '0'
	BEGIN
		INSERT #SearchResults
		SELECT DISTINCT
				Vendor.VendorID,
				'0',			-- Owners
				null,
				null,
				null,
				Vendor.CompanyName,
				null,
				null,  
				null,
				17 AS 'OrderBy',
				null	
			FROM Vendor			
				LEFT JOIN VendorProperty on VendorProperty.VendorID = Vendor.VendorID			
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = VendorProperty.PropertyID			
			WHERE  Vendor.CompanyName LIKE '%' + @partialName
			  AND Vendor.AccountID = @accountID
			  AND Vendor.IsActive = 1
			  AND Vendor.IsOwner = 1
		--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'V', @queryStartTime, GETDATE())
	END	

	IF (@rowCount IS NULL)
	BEGIN
		SELECT * FROM #SearchResults
	END
	ELSE
	BEGIN
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'R' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'N' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'P' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'E' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'T' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'A' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'L' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'U' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'V' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'I' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'B' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'W' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'G' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'Y' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'O' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'Z' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'M' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'H' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = '3' ORDER BY OrderByID) t
		UNION ALL
		SELECT * FROM (SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = '0' ORDER BY OrderByID) t
    
END
	--INSERT SearchAllTiming VALUES (NEWID(), @accountID, 'Z', @startTime, GETDATE())
END
GO
