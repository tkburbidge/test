SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 18, 2011
-- Description:	Searches tables for Names
-- =============================================
CREATE PROCEDURE [dbo].[SearchAllMin] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection readonly,
	@partialName nvarchar(25) = null,
	@type nvarchar(1) = null
AS

DECLARE @count bit
DECLARE @rowCount tinyint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
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
	
	SET @count = (SELECT COUNT(*) FROM @propertyIDs)
	
	IF @type IS NULL
	BEGIN
		SELECT @rowCount = Settings.RowsReturnedFromSearch
			FROM Settings
			WHERE Settings.AccountID = @accountID
	END


	--IF @type IS NULL OR @type = 'R'
	--BEGIN		
	--	INSERT #SearchResults
	--	SELECT
	--		UnitLeaseGroupPerson.PersonID,
	--		'R',
	--		(CASE WHEN UnitLeaseGroupPerson.IsMale = 0 THEN 'female' ELSE 'male' END),	
	--		PersonLease.LeaseID,
	--		--(CASE WHEN PersonLease.LeaseStatus = 'Pending Renewal' THEN COALESCE(CurrentLease.LeaseID, PersonLease.LeaseID)					  
	--		--	      ELSE PersonLease.LeaseID END),
	--		NULL,
	--		UnitLeaseGroupPerson.Name,
	--		UnitLeaseGroupPerson.Property,
	--		PersonLease.ResidencyStatus,	
	--		d.ThumbnailUri,	 
	--		1 AS 'OrderBy',
	--		null
	--	FROM 
	--	   (SELECT DISTINCT
	--			Person.PersonID,
	--			Person.PreferredName + ' ' + Person.LastName AS Name,
	--			UnitLeaseGroup.UnitLeaseGroupID,		
	--			Person.IsMale,
	--			Property.Abbreviation + '-' + Unit.Number AS Property
	--		FROM PersonLease
	--			INNER JOIN Lease on Lease.LeaseID = PersonLease.LeaseID
	--			INNER JOIN UnitLeaseGroup on UnitLeaseGroup.UnitLeaseGroupID = Lease.UnitLeaseGroupID
	--			INNER JOIN Unit on Unit.UnitID = UnitLeaseGroup.UnitID	
	--			INNER JOIN Person on Person.PersonID = PersonLease.PersonID
	--			INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
	--			INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID	
	--			INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID				
	--		WHERE ((@count = 0) OR (PersonTypeProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--				AND PersonType.Type = 'Resident'  
	--				AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
	--					OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
	--					OR Person.LastName LIKE @partialName)) AS UnitLeaseGroupPerson
	--		CROSS APPLY (SELECT TOP 1 Lease.LeaseID, PersonLease.ResidencyStatus, Lease.LeaseStatus, Lease.UnitLeaseGroupID
	--					 FROM Lease
	--						  INNER JOIN PersonLease ON PersonLease.LeaseID = Lease.LeaseID
	--						  INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
	--					 WHERE Lease.UnitLeaseGroupID = UnitLeaseGroupPerson.UnitLeaseGroupID
	--						   AND PersonLease.PersonID = UnitLeaseGroupPerson.PersonID
	--					 ORDER BY Ordering.OrderBy) AS PersonLease
	--		-- If the resident is pending renewal, we want to show they are pending renewal
	--		-- but direct them to the current lease
	--		--OUTER APPLY (SELECT TOP 1 Lease.LeaseID
	--		--			 FROM Lease
	--		--			 WHERE PersonLease.UnitLeaseGroupID = Lease.UnitLeaseGroupID
	--		--				AND Lease.LeaseStatus = 'Current') AS CurrentLease					
	--		LEFT JOIN Document d ON d.ObjectID = UnitLeaseGroupPerson.PersonID AND d.[Type] = 'Person'	
	--		INNER JOIN Ordering ON PersonLease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
	--	ORDER BY Ordering.OrderBy
		
	--END

	--IF @type IS NULL OR @type = 'P'
	--BEGIN
	--	INSERT #SearchResults
	--	SELECT 
	--			Person.PersonID,
	--			'P',		-- Prospects
	--			(CASE WHEN Person.IsMale = 0 THEN 'female' ELSE 'male' END),
	--			Property.PropertyID,
	--			NULL,
	--			Person.PreferredName + ' ' + Person.LastName,
	--			Property.Abbreviation,
	--			Prospect.MovingFrom, 
	--			d.ThumbnailUri,
	--			4 AS 'OrderBy',
	--			null	
	--		FROM Person
	--			INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
	--			INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
	--			INNER JOIN Prospect on Prospect.PersonID = Person.PersonID
	--			INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID
	--			LEFT JOIN Document d ON d.ObjectID = Person.PersonID AND d.[Type] = 'Person'
	--		WHERE ((@count = 0) OR (PersonTypeProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND PersonType.Type = 'Prospect'
	--		  AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
	--				OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
	--				OR Person.LastName LIKE @partialName)
	--		  AND (NOT EXISTS(SELECT PersonType.PersonTypeID 
	--							FROM PersonType pt2
	--								INNER JOIN PersonTypeProperty ptp2 ON pt2.PersonTypeID = ptp2.PersonTypeID
	--							WHERE pt2.Type = 'Resident'
	--							  AND pt2.PersonID = Person.PersonID
	--							  AND ptp2.PropertyID = PersonTypeProperty.PropertyID))
	--END
	
	--IF @type IS NULL OR @type = 'P'
	--BEGIN							  
	--	INSERT #SearchResults
	--	SELECT 
	--			Prospect.PersonID,
	--			'P',		-- Prospects Roommates
	--			(CASE WHEN Person.IsMale = 0 THEN 'female' ELSE 'male' END),
	--			Property.PropertyID,
	--			Person.PersonID,
	--			Person.PreferredName + ' ' + Person.LastName,
	--			Property.Abbreviation,
	--			Prospect.MovingFrom,  
	--			d.ThumbnailUri,
	--			4 AS 'OrderBy',
	--			null	
	--		FROM Person
	--			INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
	--			INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID			
	--			INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID
	--			INNER JOIN ProspectRoommate on Person.PersonID = ProspectRoommate.PersonID
	--			INNER JOIN Prospect on Prospect.ProspectID = ProspectRoommate.ProspectID			
	--			LEFT JOIN Document d ON d.ObjectID = Person.PersonID AND d.[Type] = 'Person'
	--		WHERE ((@count = 0) OR (PersonTypeProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND PersonType.Type = 'Prospect'
	--		  AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
	--				OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
	--				OR Person.LastName LIKE @partialName)
	--		  AND (NOT EXISTS(SELECT PersonType.PersonTypeID 
	--							FROM PersonType pt2
	--								INNER JOIN PersonTypeProperty ptp2 ON pt2.PersonTypeID = ptp2.PersonTypeID
	--							WHERE pt2.Type = 'Resident'
	--							  AND pt2.PersonID = Person.PersonID
	--							  AND ptp2.PropertyID = PersonTypeProperty.PropertyID))		
	--END								  					  


	--IF @type IS NULL OR @type = 'N'
	--BEGIN
	--	INSERT #SearchResults
	--	SELECT 
	--			Person.PersonID,
	--			'N',		-- Non-Resident Accounts
	--			(CASE WHEN Person.IsMale = 0 THEN 'female' ELSE 'male' END),
	--			null,
	--			null,
	--			Person.PreferredName + ' ' + Person.LastName,
	--			null,
	--			null,  
	--			null,
	--			5 AS 'OrderBy',
	--			null	
	--		FROM Person
	--			INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
	--			INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
	--		WHERE ((@count = 0) OR (PersonTypeProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND PersonType.Type = 'Non-Resident Account'
	--		  AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
	--				OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
	--				OR Person.LastName LIKE @partialName)
	--END
	
	--IF @type IS NULL OR @type = 'E'
	--BEGIN									
	--	INSERT #SearchResults
	--	SELECT DISTINCT
	--			Person.PersonID,
	--			'E',			-- Employees
	--			(CASE WHEN Person.IsMale = 0 THEN 'female' ELSE 'male' END),
	--			[User].UserID,
	--			null,
	--			Person.PreferredName + ' ' + Person.LastName,
	--			null,
	--			Employee.Title,  
	--			d.ThumbnailUri,
	--			6 AS 'OrderBy',
	--			null	
	--		FROM Person
	--			INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
	--			INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
	--			INNER JOIN [User] on [User].PersonID = Person.PersonID
	--			INNER JOIN Employee on Employee.PersonID = Person.PersonID
	--			INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID
	--			LEFT JOIN Document d ON d.ObjectID = Person.PersonID AND d.[Type] = 'Person'
	--		WHERE ((@count = 0) OR (PersonTypeProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND PersonType.Type = 'Employee'
	--		  AND (Person.FirstName + ' ' + Person.LastName LIKE @partialName 
	--				OR Person.PreferredName + ' ' + Person.LastName LIKE @partialName
	--				OR Person.LastName LIKE @partialName)
	--END					

	--IF @type IS NULL OR @type = 'T'
	--BEGIN	
	--	INSERT #SearchResults
	--	SELECT 
	--			Person.PersonID,
	--			'T',			-- Pets
	--			Pet.[Type],
	--			PersonLease.LeaseID,
	--			null,
	--			Pet.Name,
	--			Property.Abbreviation + '-' + Unit.Number,
	--			Person.PreferredName + ' ' + Person.LastName,  
	--			d.ThumbnailUri,
	--			9 AS 'OrderBy',
	--			null				
	--		FROM Person
	--			INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
	--			INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID			
	--			CROSS APPLY (SELECT TOP 1 Lease.LeaseID, PersonLease.ResidencyStatus, Lease.UnitLeaseGroupID FROM PersonLease 
	--						 INNER JOIN Lease on Lease.LeaseID = PersonLease.LeaseID
	--						 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
	--						 WHERE PersonLease.PersonID = Person.PersonID
	--						 ORDER BY Ordering.OrderBy) AS PersonLease
	--			INNER JOIN UnitLeaseGroup on UnitLeaseGroup.UnitLeaseGroupID = PersonLease.UnitLeaseGroupID
	--			INNER JOIN Unit on UnitLeaseGroup.UnitID = Unit.UnitID
	--			INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID
	--			INNER JOIN Pet on Pet.PersonID = Person.PersonID
	--			LEFT JOIN Document d ON d.ObjectID = Pet.PetID AND d.[Type] = 'Pet'
	--		WHERE ((@count = 0) OR (PersonTypeProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND PersonType.Type = 'Resident'
	--		  AND Pet.Name LIKE @partialName
	--END			  

	--IF @type IS NULL OR @type = 'A'
	--BEGIN	
	--	INSERT #SearchResults
	--	SELECT 
	--			Person.PersonID,
	--			'A',			-- Automobiles
	--			null,
	--			PersonLease.LeaseID,
	--			null,
	--			Automobile.LicensePlateNumber + ' - ' + ISNULL(Automobile.Make, '') + ' ' + ISNULL(Automobile.Model, ''),
	--			Property.Abbreviation + '-' + Unit.Number,
	--			Person.PreferredName + ' ' + Person.LastName,  
	--			null,
	--			9 AS 'OrderBy',
	--			null				
	--		FROM Person
	--			INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
	--			INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID			
	--			CROSS APPLY (SELECT TOP 1 Lease.LeaseID, PersonLease.ResidencyStatus, Lease.UnitLeaseGroupID FROM PersonLease 
	--						 INNER JOIN Lease on Lease.LeaseID = PersonLease.LeaseID
	--						 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
	--						 WHERE PersonLease.PersonID = Person.PersonID
	--						 ORDER BY Ordering.OrderBy) AS PersonLease
	--			INNER JOIN UnitLeaseGroup on UnitLeaseGroup.UnitLeaseGroupID = PersonLease.UnitLeaseGroupID
	--			INNER JOIN Unit on UnitLeaseGroup.UnitID = Unit.UnitID
	--			INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID
	--			INNER JOIN Automobile on Automobile.PersonID = Person.PersonID
	--			--LEFT JOIN Document d ON d.ObjectID = Pet.PetID AND d.[Type] = 'Pet'
	--		WHERE ((@count = 0) OR (PersonTypeProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND PersonType.Type = 'Resident'
	--		  AND Automobile.LicensePlateNumber LIKE @partialName
	--END			  

	--IF @type IS NULL OR @type = 'L'
	--BEGIN
	--	INSERT #SearchResults
	--	SELECT DISTINCT
	--			(CASE WHEN PersonLease.LeaseStatus = 'Pending Renewal' THEN COALESCE(CurrentLease.LeaseID, PersonLease.LeaseID)					  
	--			      ELSE PersonLease.LeaseID END),
	--			'L',			-- Leases
	--			(CASE WHEN Person.IsMale = 0 THEN 'female' ELSE 'male' END),
	--			null,
	--			null,
	--			Person.PreferredName + ' ' + Person.LastName AS 'Name',
	--			Property.Abbreviation + '-' + PersonLease.Number,
	--			PersonLease.LeaseStatus,  
	--			d.ThumbnailUri,
	--			LEN(PersonLease.Number) AS 'OrderBy',
	--			Ordering.OrderBy				
	--		FROM Person
	--			INNER JOIN PersonType on Person.PersonID = PersonType.PersonID
	--			INNER JOIN PersonTypeProperty on PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID			
	--			CROSS APPLY (SELECT TOP 1 Lease.LeaseID, Lease.LeaseStatus, Lease.UnitLeaseGroupID, Unit.Number, Unit.PaddedNumber FROM PersonLease 
	--						 INNER JOIN Lease on Lease.LeaseID = PersonLease.LeaseID						 
	--						 INNER JOIN UnitLeaseGroup on UnitLeaseGroup.UnitLeaseGroupID = Lease.UnitLeaseGroupID
	--						 INNER JOIN Unit on UnitLeaseGroup.UnitID = Unit.UnitID	
	--						 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
	--						 WHERE PersonLease.PersonID = Person.PersonID AND Unit.Number LIKE @partialName AND PersonLease.MainContact = 1
	--						 ORDER BY Ordering.OrderBy) AS PersonLease
	--			-- If the resident is pending renewal, we want to show they are pending renewal
	--			-- but direct them to the current lease
	--			OUTER APPLY (SELECT TOP 1 Lease.LeaseID
	--						 FROM Lease
	--						 WHERE PersonLease.UnitLeaseGroupID = Lease.UnitLeaseGroupID
	--							AND Lease.LeaseStatus = 'Current') AS CurrentLease						 
	--			INNER JOIN Property on Property.PropertyID = PersonTypeProperty.PropertyID						 			
	--			LEFT JOIN Document d ON d.ObjectID = Person.PersonID AND d.[Type] = 'Person'
	--			INNER JOIN Ordering ON PersonLease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
	--		WHERE ((@count = 0) OR (PersonTypeProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--			AND PersonLease.LeaseStatus <> 'Renewed'	
	--		ORDER BY LEN(PersonLease.Number), Ordering.OrderBy
	--END

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
			WHERE ((@count = 0) OR (Building.PropertyID IN (SELECT Value FROM @propertyIDs)))
			  AND Unit.Number LIKE @partialName
			ORDER BY LEN(Unit.Number), Unit.PaddedNumber	
	END						
	
	--IF @type IS NULL OR @type = 'I'
	--BEGIN
	--	INSERT #SearchResults
	--	SELECT Invoice.InvoiceID,
	--			'I',			-- Invoices
	--			null,
	--			null,
	--			null,
	--			Invoice.Number + ' - ' + Vendor.CompanyName,
	--			Property.Abbreviation + ' - ' + CONVERT(nvarchar(10),Invoice.AccountingDate, 110),
	--		   (CASE WHEN Invoice.Credit = 1 THEN -Invoice.Total ELSE Invoice.Total END),  
	--			null,
	--			7 AS 'OrderBy',
	--			null	
	--		FROM Invoice
	--			INNER JOIN Vendor on Vendor.VendorID = Invoice.VendorID
	--			INNER JOIN Property on Property.PropertyID = Invoice.PropertyID
	--		WHERE ((@count = 0) OR (Property.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND Invoice.Number LIKE @partialName
	--END			  

	--IF @type IS NULL OR @type = 'V'
	--BEGIN
	--	INSERT #SearchResults
	--	SELECT DISTINCT
	--			Vendor.VendorID,
	--			'V',			-- Vendors
	--			null,
	--			null,
	--			null,
	--			Vendor.CompanyName,
	--			null,
	--			null,  
	--			null,
	--			8 AS 'OrderBy',
	--			null	
	--		FROM Vendor			
	--			LEFT JOIN VendorProperty on VendorProperty.VendorID = Vendor.VendorID			
	--		WHERE ((@count = 0) OR VendorProperty.VendorID IS NULL OR (VendorProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND Vendor.CompanyName LIKE '%' + @partialName
	--END			  

	--IF @type IS NULL OR @type = 'B'
	--BEGIN
	--	INSERT #SearchResults
	--	SELECT DISTINCT
	--			BankAccount.BankAccountID,
	--			'B',			-- BankAccounts
	--			null,
	--			null,
	--			null,
	--			BankAccount.AccountName,
	--			BankAccount.BankName,
	--			BankAccount.AccountNumber,  
	--			null,
	--			10 AS 'OrderBy',
	--			null	
	--		FROM BankAccount			
	--			INNER JOIN BankAccountProperty on BankAccountProperty.BankAccountID = BankAccount.BankAccountID
	--		WHERE ((@count = 0) OR (BankAccountProperty.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND (BankAccount.AccountName LIKE @partialName 
	--			   OR BankAccount.BankName LIKE @partialName 
	--			   OR BankAccount.AccountNumber LIKE @partialName)
	--END				   

	--IF @type IS NULL OR @type = 'W'
	--BEGIN
	--	INSERT #SearchResults 
	--	SELECT DISTINCT
	--		wo.WorkOrderID,
	--		'W',				-- Work Orders
	--		null,
	--		null,
	--		null,
	--		CAST(wo.Number AS nvarchar(50)) + ' - ' + pli.Name,
	--		p.Abbreviation,
	--		wo.Status, 
	--		null,
	--		11 AS 'OrderBy',
	--		null	
	--		FROM WorkOrder wo
	--			INNER JOIN PickListItem pli ON wo.WorkOrderCategoryID = pli.PickListItemID
	--			INNER JOIN Property p ON wo.PropertyID = p.PropertyID
	--		WHERE ((@count = 0) OR (wo.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND (wo.Number LIKE @partialName
	--			   OR pli.Name LIKE @partialName)		
	--END				   
	
	--IF @type IS NULL OR @type = 'G'
	--BEGIN	
	--	INSERT #SearchResults 
	--	SELECT 
	--		gl.GLAccountID,
	--		'G',				-- GL Accounts
	--		null,
	--		null,
	--		null,
	--		gl.Number + ' - ' + gl.Name,
	--		NULL,
	--		NULL,  
	--		null,
	--		12 AS 'OrderBy',
	--		null	
	--		FROM GLAccount gl					
	--		WHERE gl.AccountID = @accountID 
	--		  AND (gl.Number LIKE @partialName
	--			   OR gl.Name LIKE ('%' + @partialName))
	--		ORDER BY gl.Number
	--END			

	--IF @type IS NULL OR @type = 'Y'
	--BEGIN	
	--	INSERT #SearchResults 
	--	SELECT ObjectID,
	--		   [Type],
	--		   null,
	--		   AltObjectID, 
	--		   AltObjectID2,
	--		   Name,
	--		   Property,
	--		   Details,
	--		   ImageUri,
	--		   OrderBy,
	--			null
	--	FROM (SELECT DISTINCT TOP 2147483647
	--				p.PaymentID AS 'ObjectID',
	--				'Y' AS 'Type',				-- Payments
	--				null AS 'AltObjectID',
	--				null AS 'AltObjectID2',
	--				p.ReferenceNumber + ' - ' + p.[Description] + ' (' + CONVERT(nvarchar(10), p.[Date]) + ')' AS 'Name',
	--				prop.Abbreviation AS 'Property',
	--				p.ReceivedFromPaidTo AS 'Details',  
	--				null AS 'ImageUri',
	--				13 AS 'OrderBy',
	--				p.[Date]	
	--				FROM Payment p
	--				INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
	--				INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
	--				INNER JOIN TransactionType tt on tt.TransactionTypeID = t.TransactionTypeID
	--				INNER JOIN Property prop ON prop.PropertyID = t.PropertyID
	--				WHERE p.AccountID = @accountID 
	--				  AND ((@count = 0) OR (t.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--				  AND p.ReferenceNumber like @partialName
	--				  AND p.PaidOut = 0
	--				  AND tt.Name = 'Payment'		
	--				ORDER BY p.[Date] DESC) Payments
	--END											   	

	--IF @type IS NULL OR @type = 'O'
	--BEGIN
	--	INSERT #SearchResults 
	--	SELECT ObjectID,
	--		   [Type],
	--		   null,
	--		   AltObjectID, 
	--		   AltObjectID2,
	--		   Name,
	--		   Property,
	--		   Details,
	--		   ImageUri,
	--		   OrderBy,
	--			null		 
	--	FROM (SELECT DISTINCT TOP 2147483647
	--				bt.ObjectID AS 'ObjectID',
	--				'O' AS 'Type',				-- Invoice Payments
	--				null AS 'AltObjectID',
	--				null AS 'AltObjectID2',
	--				bt.ReferenceNumber + ' - ' + p.ReceivedFromPaidTo AS 'Name',
	--				prop.Abbreviation AS 'Property',
	--				ba.AccountNumber + ' - ' + ba.AccountName AS 'Details',		
	--				null AS 'ImageUri',
	--				14 AS 'OrderBy',
	--				p.[Date] AS 'Date'	
	--				FROM BankTransaction bt
	--				INNER JOIN Payment p ON bt.ObjectID = p.PaymentID
	--				INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
	--				INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
	--				INNER JOIN TransactionType tt on tt.TransactionTypeID = t.TransactionTypeID
	--				INNER JOIN Property prop ON prop.PropertyID = t.PropertyID
	--				INNER JOIN BankAccount ba ON ba.BankAccountID = t.ObjectID				
	--				WHERE bt.AccountID = @accountID 
	--				  AND ((@count = 0) OR (t.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--				  AND tt.Name = 'Payment'
	--				  AND tt.[Group] = 'Invoice'
	--				  AND bt.ReferenceNumber like @partialName
	--				ORDER BY p.[Date] DESC) InvoicePayments
	--END		
	
	
	--IF @type IS NULL OR @type = 'M'
	--BEGIN				
	--	INSERT #SearchResults
	--	SELECT 
	--			li.LedgerItemID,
	--			'M',			-- Rentable Items
	--			null,
	--			null,
	--			null,
	--			li.[Description],
	--			p.Abbreviation,
	--			lip.Name,  
	--			null,
	--			15 AS 'OrderBy',
	--			null	
	--		FROM LedgerItem li
	--			INNER JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
	--			INNER JOIN Property p on p.PropertyID = lip.PropertyID				
	--		WHERE ((@count = 0) OR (p.PropertyID IN (SELECT Value FROM @propertyIDs)))
	--		  AND li.[Description] LIKE @partialName
	--		ORDER BY LEN(li.[Description]), li.[Description]
	--END				

	IF (@rowCount IS NULL)
	BEGIN
		SELECT * FROM #SearchResults		
	END
	ELSE
	BEGIN		
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'R'
		UNION		
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'N'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'P'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'E'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'T'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'A'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'L'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'U'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'V'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'I'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'B'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'W'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'G'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'Y'
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'O'		
		UNION
		SELECT TOP (@rowCount) * FROM #SearchResults WHERE Type = 'M'		
	END

END
GO
