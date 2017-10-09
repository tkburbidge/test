SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[API_GetImplementationTemplates]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier,
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;    

	SELECT
		ISNULL(p.Salutation, '') AS 'Salutation',
		ISNULL(p.FirstName, '') AS 'FirstName', 
		ISNULL(p.MiddleName, '') AS 'MiddleName', 
		ISNULL(p.LastName, '') AS 'LastName', 
		ISNULL(p.PreferredName, '') AS 'PreferredName', 		
		p.Email,
		(CASE WHEN p.IsMale = 1 THEN 'Male' ELSE 'Female' END) AS 'Gender',
		(CASE WHEN p.Phone1Type = 'Mobile' THEN p.Phone1
			  WHEN p.Phone2Type = 'Mobile' THEN p.Phone2
	 		  WHEN p.Phone3Type = 'Mobile' THEN p.Phone3
		 END) AS 'MobilePhone',
		 (CASE WHEN p.Phone1Type = 'Home' THEN p.Phone1
			  WHEN p.Phone2Type = 'Home' THEN p.Phone2
	 		  WHEN p.Phone3Type = 'Home' THEN p.Phone3
		 END) AS 'HomePhone',
		 (CASE WHEN p.Phone1Type = 'Work' THEN p.Phone1
			  WHEN p.Phone2Type = 'Work' THEN p.Phone2
	 		  WHEN p.Phone3Type = 'Work' THEN p.Phone3
		 END) AS 'WorkPhone',
		 p.DriversLicenseNumber AS 'DriversLicense',
		 p.DriversLicenseState AS 'DriversLicenseState',
		 p.Birthdate,
		 p.SSN AS 'SSN',
		 p.PrimaryLanguage,	 
		 --REPLACE(REPLACE(a.StreetAddress, CHAR(13), ''), CHAR(10), '') AS 'StreetAddress',
		 a.StreetAddress,
		 a.City AS 'City',
		 a.State AS 'State',
		 a.Zip AS 'Zip',
		 a.Country AS 'Country',
		 ps.Name AS 'ProspectSource',
		 pros.MovingFrom,
		 pros.DateNeeded,
		 '' AS 'UnitTypes',
		 pros.Building,
		 pros.Floor,
		 pros.MaxRent AS 'DesiredRent',
		 pros.OtherPreferences,
		 pn.Date AS 'ContactDate',
		 pn.ContactType,
		 (CASE WHEN pn.InteractionType = 'Unit Shown' THEN CAST(1 AS BIT)
			   ELSE CAST(0 AS BIT)
		  END) AS 'UnitShown',
		 (CASE WHEN lap.PersonID IS NULL THEN pnp.FirstName + ' ' + pnp.LastName
				ELSE lap.FirstName + ' ' + lap.LastName
				END) AS 'LeasingAgent',
		 pn.Note AS 'Notes'
	FROM Prospect pros
	INNER JOIN Person p ON p.PersonID = pros.PersonID
	LEFT JOIN PersonLease pl ON pl.PersonID = p.PersonID
	LEFT JOIN [Address] a ON a.ObjectID = p.PersonID AND a.AddressType = 'Prospect'
	INNER JOIN PersonNote pn ON pn.PersonNoteID = pros.FirstPersonNoteID
	LEFT JOIN PersonTypeProperty laptp ON laptp.PersonTypePropertyID = pros.ResponsiblePersonTypePropertyID
	LEFT JOIN PersonType lapt ON lapt.PersonTypeID = laptp.PersonTypeID
	LEFT JOIN Person lap ON lap.PersonID = lapt.PersonID
	INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pros.PropertyProspectSourceID
	INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
	INNER JOIN Person pnp ON pnp.PersonID = pn.CreatedByPersonID
	WHERE pl.PersonLeaseID IS NULL
		AND pps.PropertyID = @propertyID
		AND pros.LostDate IS NULL


	SELECT ut.Name,
		   ut.Description,
		   ut.Bedrooms,
		   ut.Bathrooms,
		   ut.SquareFootage,
		   ut.MaximumOccupancy AS 'MaxOccupancy',
		   rlit.Abbreviation 'RentTransactionCategory',
		   ut.MarketRent,
		   dlit.Abbreviation 'DepositTransactionCategory',
		   ut.RequiredDeposit
	FROM UnitType ut
	INNER JOIN LedgerItemType rlit ON rlit.LedgerItemTypeID = ut.RentLedgerItemTypeID
	INNER JOIN LedgerItemType dlit ON dlit.LedgerItemTypeID = ut.DepositLedgerItemTypeID
	WHERE ut.PropertyID = @propertyID
	ORDER BY ut.Name



	SELECT 
		u.Number,
		ut.Name AS 'UnitType',
		b.Name AS 'Building',
		u.Floor,
		us.Status AS 'Status',
		a.StreetAddress,
		a.City,
		a.State,
		a.Zip,
		a.Country,
		u.AddressIncludesUnitNumber,
		u.LastVacatedDate,
		u.TotalVacantDays,
		u.PetsPermitted,
		u.AvailableForOnlineMarketing,
		u.IsHoldingUnit AS 'HoldingUnit',
		u.ExcludedFromOccupancy,
		u.SquareFootage
	FROM Unit u
	INNER JOIN Building b ON b.BuildingID =u.BuildingID
	INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
	CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) us
	INNER JOIN [Address] a ON a.AddressID = u.AddressID
	WHERE b.PropertyID = @propertyID
	ORDER BY u.PaddedNumber

	CREATE TABLE #TransactionLeaseIDs ( UnitLeaseGroupID uniqueidentifier, LeaseID uniqueidentifier )

	 CREATE TABLE #OutstandingCharges (
			ObjectID			uniqueidentifier		NOT NULL,
			TransactionID		uniqueidentifier		NOT NULL,
			Amount				money					NOT NULL,
			TaxAmount			money					NULL,
			UnPaidAmount		money					NULL,
			TaxesUnPaidAmount		money					NULL,
			[Description]		nvarchar(500)			NULL,
			TranDate			datetime2				NULL,
			GLAccountID			uniqueidentifier		NULL, 
			OrderBy				smallint				NULL,
			TaxRateGroupID		uniqueidentifier		NULL,
			LedgerItemTypeID	uniqueidentifier		NULL,
			LedgerItemTypeAbbr	nvarchar(50)			NULL,
			GLNumber			nvarchar(50)			NULL,		
			IsWriteOffable		bit						NULL,
			Notes				nvarchar(MAX)			NULL,
			TaxRateID			uniqueidentifier		NULL
			)

	CREATE TABLE #UnappliedPayments (
			CurrentPayment		int identity,
			ObjectID			uniqueidentifier		NOT NULL,
			TransactionID		uniqueidentifier		NOT NULL,
			PaymentID			uniqueidentifier		NOT NULL,
			TTName				nvarchar(25)			NOT NULL,
			TransactionTypeID	uniqueidentifier		NOT NULL,
			Amount				money					NOT NULL,
			Reference			nvarchar(50)			NULL,
			LedgerItemTypeID	uniqueidentifier		NULL,
			[Description]		nvarchar(1000)			NULL,
			Origin				nvarchar(50)			NULL,
			PaymentDate			date					NULL,
			PostingBatchID		uniqueidentifier		NULL,
			Allocated			bit						NOT NULL,
			AppliesToLedgerItemTypeID uniqueidentifier	NULL,
			LedgerItemTypeAbbreviation	nvarchar(50)	NULL,
			GLNumber			nvarchar(50)			NULL,
			GLAccountID			uniqueidentifier		NULL,
			TaxRateID			uniqueidentifier	    NULL)
		
	INSERT INTO #OutstandingCharges
		EXEC GetOutstandingCharges @accountID, @propertyID, null, 'Lease', 0, @date, 1, 1
		
	INSERT INTO #UnappliedPayments
		EXEC GetUnappliedPayments @accountID, @propertyID, null, 'Lease', null

	INSERT INTO #TransactionLeaseIDs
		SELECT ObjectID, null FROM #OutstandingCharges
		UNION
		SELECT ObjectID, null FROM #UnappliedPayments

	UPDATE #TransactionLeaseIDs
		SET LeaseID = (SELECT TOP 1 l.LeaseID
						FROM Lease l
						INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l.LeaseStatus
						WHERE l.UnitLeaseGroupID = #TransactionLeaseIDs.UnitLeaseGroupID
							AND o.Value <> 'Pending Renewal'
						ORDER BY o.OrderBy)


	SELECT 
		u.Number AS 'Unit',
		l.LeaseStatus,
		pl.ResidencyStatus,
		ISNULL(p.Salutation, '') AS 'Salutation',
		ISNULL(p.FirstName, '') AS 'FirstName', 
		ISNULL(p.MiddleName, '') AS 'MiddleName', 
		ISNULL(p.LastName, '') AS 'LastName', 
		ISNULL(p.PreferredName, '') AS 'PreferredName', 
		pl.HouseholdStatus,
		pl.MainContact,
		pl.ApplicationDate,
		pl.MoveInDate,
		pl.LeaseSignedDate,
		l.LeaseStartDate,
		l.LeaseEndDate,
		la.FirstName + ' ' + la.LastName AS 'LeasingAgent',
		p.Email,
		(CASE WHEN p.IsMale = 1 THEN 'Male' ELSE 'Female' END) AS 'Gender',
		(CASE WHEN p.Phone1Type = 'Mobile' THEN p.Phone1
			  WHEN p.Phone2Type = 'Mobile' THEN p.Phone2
	 		  WHEN p.Phone3Type = 'Mobile' THEN p.Phone3
		 END) AS 'MobilePhone',
		 (CASE WHEN p.Phone1Type = 'Home' THEN p.Phone1
			  WHEN p.Phone2Type = 'Home' THEN p.Phone2
	 		  WHEN p.Phone3Type = 'Home' THEN p.Phone3
		 END) AS 'HomePhone',
		 (CASE WHEN p.Phone1Type = 'Work' THEN p.Phone1
			  WHEN p.Phone2Type = 'Work' THEN p.Phone2
	 		  WHEN p.Phone3Type = 'Work' THEN p.Phone3
		 END) AS 'WorkPhone',
		 p.DriversLicenseNumber AS 'DriversLicense',
		 p.DriversLicenseState AS 'DriversLicenseState',
		 p.Birthdate,
		 p.SSN AS 'SSN',
		 p.PrimaryLanguage,
		 pl.NoticeGivenDate,
		 pl.MoveOutDate,
		 pl.ReasonForLeaving,
		 --REPLACE(REPLACE(fa.StreetAddress, CHAR(13), ''), CHAR(10), '') AS 'ForwardingStreetAddress',
		 fa.StreetAddress AS 'ForwardingStreetAddress',
		 fa.City AS 'ForwardingCity',
		 fa.State AS 'ForwardingState',
		 fa.Zip AS 'ForwardingZip',
		 fa.Country AS 'ForwardingCountry',
		 '' AS 'Notes',
		 e.Employer,
		 e.Industry,
		 e.Title,
		 s.Amount AS 'Salary',
		 s.SalaryPeriod,
		 e.ContactName AS 'EmployerContact',
		 e.CompanyPhone AS 'EmployerPhone',  
		 --REPLACE(REPLACE(ea.StreetAddress, CHAR(13), ''), CHAR(10), ''),
		 ea.StreetAddress AS 'EmployerAddress',
		 ea.City AS 'EmployerCity',
		 ea.State AS 'EmployerState',
		 ea.Zip AS 'EmployerZip',  
		 ea.Country AS 'EmployerCountry',
		 '' AS 'AltContactName',
		 '' AS 'AltContactRelation',
		 '' AS 'AltContactPhone',
		 '' AS 'AltContactWorkPhone',
		 '' AS 'AltContactEmail',
		 '' AS 'AltContactAddress',
		 '' AS 'AltContactCity', 
		 '' AS 'AltContactState', 
		 '' AS 'AltContactZip',
		 am.LicensePlateNumber AS 'AutoLicensePlate',
		 am.LicensePlateState AS 'AutoLicenseState',
		 am.Make AS 'AutoMake',
		 am.Model AS 'AutoModel',
		 am.Color AS 'AutoColor',
		 am.PermitNumber AS 'AutoPermit',
		 '' AS 'GateCardNumber',
		 pet.Name AS 'PetName',
		 pet.Type AS 'PetType',
		 pet.Breed AS 'PetBreed',
		 pet.Color AS 'PetColor',
		 pet.Age AS 'PetAge',
		 pet.Weight AS 'PetWeight',
		 pet.Notes AS 'PetNotes',
		 pet.RegistrationType AS 'PetRegistrationType',
		 pet.RegistrationIssuedBy AS 'PetRegistrationIssuer',
		 pet.RegistrationNumber AS 'PetRegistrationNumber',
		 pet.ProofOfVaccinations AS 'PetProofOfVaccinations',
		 pet.ValidationOfDogBreed AS 'PetProofOfBreed'
	FROM Lease l
	INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
	INNER JOIN Person p ON p.PersonID = pl.PersonID
	INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
	INNER JOIN Unit u ON u.UnitID = ulg.UnitID
	INNER JOIN Building b ON b.BuildingID = u.BuildingID
	LEFT JOIN Person la ON la.PersonID = l.LeasingAgentPersonID
	LEFT JOIN [Address] fa ON fa.ObjectID = p.PersonID AND fa.AddressType = 'Forwarding'
	LEFT JOIN Employment e ON e.PersonID = p.PersonID AND e.EmploymentID = (SELECT TOP 1 e2.EmploymentID FROM Employment e2 WHERE e2.PersonID = p.PersonID ORDER BY e2.StartDate DESC)
	LEFT JOIN Salary s ON e.EmploymentID = s.EmploymentID AND s.SalaryID = (SELECT TOP 1 s2.SalaryID FROM Salary s2 WHERE s2.EmploymentID = e.EmploymentID ORDER BY s2.EffectiveDate DESC)
	LEFT JOIN [Address] ea ON ea.AddressID = e.AddressID
	LEFT JOIN [Automobile] am ON am.PersonID = p.PersonID AND am.AutomobileID = (SELECT TOP 1 am2.AutomobileID FROM Automobile am2 WHERE am2.PersonID = p.PersonID)
	LEFT JOIN Pet pet ON pet.PersonID = p.PersonID AND pet.PetID = (SELECT TOP 1 pet2.PetID FROM Pet pet2 WHERE pet2.PersonID = p.PersonID)
	WHERE b.PropertyID = @propertyID
	AND (l.LeaseStatus IN ('Pending', 'Pending Transfer', 'Current', 'Under Eviction') OR
		 l.LeaseID IN (SELECT LeaseID FROM #TransactionLeaseIDs))
	AND (pl.ResidencyStatus IN ('Pending', 'Approved', 'Pending Transfer', 'Current', 'Under Eviction')
		 OR pl.LeaseID IN (SELECT LeaseID FROM #TransactionLeaseIDs))
	ORDER BY u.PaddedNumber, l.LeaseID, p.FirstName, p.LastName


	SELECT 
		u.Number AS 'Unit',
		p.FirstName + ' ' + p.LastName AS 'ResidentName',
		lit.Abbreviation AS 'TransactionCategory',
		(CASE WHEN li.LedgerItemPoolID IS NOT NULL THEN li.Description 
		ELSE null
		END) AS 'RentableItemName',
		lli.Description,
		lli.Amount,
		lli.StartDate,
		lli.EndDate,
		lli.RentalAssistanceSource,
		lli.IsNonOptionalCharge AS 'NonOptionalCharge',
		lli.PostToHapLedger AS 'PostToHapLedger'
	FROM Lease l
	INNER JOIN LeaseLedgerItem lli ON lli.LeaseID = l.LeaseID
	INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
	INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
	INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
	INNER JOIN Person p ON p.PersonID = pl.PersonID
	INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
	INNER JOIN Unit u ON u.UnitID = ulg.UnitID
	INNER JOIN Building b ON b.BuildingID = u.BuildingID
	LEFT JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
	WHERE b.PropertyID = @propertyID
	AND (l.LeaseStatus IN ('Pending', 'Pending Transfer', 'Current', 'Under Eviction') OR
		 l.LeaseID IN (SELECT LeaseID FROM #TransactionLeaseIDs))
	AND pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID FROM PersonLease pl2 WHERE pl2.LeaseID = l.LeaseID and pl2.MainContact = 1 ORDER BY pl2.OrderBy)					    
	AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
	ORDER BY u.PaddedNumber, l.LeaseID


	SELECT
		u.Number AS 'Unit', 
		p.FirstName + ' ' + p.LastName AS 'ResidentName',
		@date AS 'Date',
		lit.Abbreviation AS 'TransactionCategory',
		'' AS 'PaymentType',
		'' AS 'Reference',
		#oc.Description,
		#oc.UnPaidAmount AS 'Amount', 
		CONVERT(varchar(10), #oc.TranDate, 20) AS 'Notes'
	FROM #OutstandingCharges #oc
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = #oc.ObjectID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Lease l ON l.UnitLeaseGroupID = #oc.ObjectID
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
		INNER JOIN Person p ON p.PersonID = pl.PersonID
		INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = #oc.LedgerItemTypeID
	WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID FROM PersonLease pl2 WHERE pl2.LeaseID = l.LeaseID and pl2.MainContact = 1 ORDER BY pl2.OrderBy)					    
	AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
					 FROM Lease l2
					 INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l2.LeaseStatus
					 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					 ORDER BY o.OrderBy)

	UNION ALL


	SELECT
		u.Number AS 'Unit',
		p.FirstName + ' ' + p.LastName AS 'ResidentName',
		@date AS 'Date',
		lit.Abbreviation AS 'TransactionCategory',
		(CASE WHEN lit.IsPayment = 1 THEN 'Check'
			  ELSE '' 
		 END) AS 'PaymentType',
		#up.Reference AS 'Refernce',
		#up.Description,
		#up.Amount AS 'Amount', 
		CONVERT(varchar(10), #up.PaymentDate, 20) AS 'Notes'
	FROM #UnappliedPayments #up
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = #up.ObjectID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Lease l ON l.UnitLeaseGroupID = #up.ObjectID
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
		INNER JOIN Person p ON p.PersonID = pl.PersonID
		INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = #up.LedgerItemTypeID
	WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID FROM PersonLease pl2 WHERE pl2.LeaseID = l.LeaseID and pl2.MainContact = 1 ORDER BY pl2.OrderBy)					    
	AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
					 FROM Lease l2
					 INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l2.LeaseStatus
					 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					 ORDER BY o.OrderBy)

END
GO
