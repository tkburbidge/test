SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: August 8, 2013
-- Description:	Gets the data needed when collectio information is
--				requested through the API
-- =============================================
CREATE PROCEDURE [dbo].[GetCollectionAccounts]
	
	@accountID bigint,
	@propertyID uniqueidentifier,
	@integrationPartnerID int,
	@utcNow datetime,
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
	CREATE TABLE #LeaseFiles (
		UnitNumber			nvarchar(50)		NOT NULL,
		UnitLeaseGroupID	uniqueidentifier	NOT NULL,
		CollectionAgreementID	uniqueidentifier	NOT NULL,
		LeaseID				uniqueidentifier	NOT NULL,
		UnitID				uniqueidentifier	NOT NULL,
		LastChangeDate		datetime			NOT NULL,
		MoveOutDate			datetime			NULL,
		NoticeGivenDate		datetime			NULL,
		MoveInDate			datetime			NOT NULL,
		LeaseStartDate		datetime			NOT NULL,
		LeaseEndDate		datetime			NOT NULL,
		MonthlyRent			money				NULL
	)

	CREATE TABLE #FileTransactions (	
		UnitLeaseGroupID	uniqueidentifier	NOT NULL,
		CollectionDetailID	uniqueidentifier	NOT NULL,
		[Date]				datetime			NOT NULL,
		[Description]		nvarchar(500)		NOT NULL,
		Amount				money				NOT NULL,	
		OpenAmount			money				NULL
	)

	CREATE TABLE #Tenants (
		UnitLeaseGroupID	uniqueidentifier	NOT NULL,
		PersonID			uniqueidentifier	NOT NULL,
		FirstName			nvarchar(50)		NULL,
		LastName			nvarchar(50)		NULL,
		Birthdate			datetime			NULL,
		SSN					nvarchar(25)		NULL,
		DriversLicense		nvarchar(50)		NULL,
		Phone1				nvarchar(50)		NULL,
		Phone1Type			nvarchar(50)		NULL,
		Phone2				nvarchar(50)		NULL,
		Phone2Type			nvarchar(50)		NULL,
		Phone3				nvarchar(50)		NULL,
		Phone3Type			nvarchar(50)		NULL,
		Email				nvarchar(150)		NULL
	)

	CREATE TABLE #Income (
		PersonID			uniqueidentifier	NOT NULL,
		[Type]				nvarchar(10)		NOT NULL, -- This will be one of Constants.EmploymentTypes

		Company				nvarchar(100)		NULL,
		StreetAddress		nvarchar(500)		NULL,
		City				nvarchar(500)		NULL,
		[State]				nvarchar(500)		NULL,
		Zip					nvarchar(500)		NULL,
		Country				nvarchar(500)		NULL,
		Phone				nvarchar(500)		NULL,	-- SupervisorPhone
		Email				nvarchar(500)		NULL,
		Title				nvarchar(500)		NULL,
		ContactName			nvarchar(500)		NULL,   -- SupervisorName
		Salary				money				NULL,
		SalaryPeriod		nvarchar(50)		NULL	-- Needs to be converted to PaymentPeriod values
	)

	CREATE TABLE #Address (
		PersonID			uniqueidentifier	NOT NULL,
		AddressType			nvarchar(50)		NOT NULL,
		StreetAddress		nvarchar(500)		NULL,
		City				nvarchar(500)		NULL,
		[State]				nvarchar(500)		NULL,
		Zip					nvarchar(500)		NULL,
		Country				nvarchar(500)		NULL,
	)

	CREATE TABLE #CADocuments (
		CollectionAgreementDocumentID	uniqueidentifier	NOT NULL,
		CollectionAgreementID			uniqueidentifier	NOT NULL,
		DocumentID						uniqueidentifier	NOT NULL,
		DocumentName					nvarchar(100)		NOT NULL,
	)

	CREATE TABLE #AlternateContacts (
		ResidentPersonID	uniqueidentifier	NOT NULL,
		PersonID			uniqueidentifier	NOT NULL,
		Email				nvarchar(150)		NULL,
		Name				nvarchar(150)		NOT NULL,
		PhoneNumber			nvarchar(35)		NULL,
		WorkPhone			nvarchar(35)		NULL,
		StreetAddress		nvarchar(500)		NULL,
		City				nvarchar(50)		NULL,
		[State]				nvarchar(50)		NULL,
		Zip					nvarchar(20)		NULL,
		Country				nvarchar(50)		NULL
	)

	INSERT INTO #LeaseFiles
		SELECT 
			 u.Number,
			 ulg.UnitLeaseGroupID,
			 ca.CollectionAgreementID,
			 l.LeaseID,
			ulg.UnitID,
			 ca.DateCreated AS 'LastChangeDate',
			 (SELECT Max(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID) AS 'MoveOutDate',
			 (SELECT Max(NoticeGivenDate) FROM PersonLease WHERE LeaseID = l.LeaseID) AS 'NoticeGivenDate',
			 (SELECT Min(MoveInDate) FROM PersonLease WHERE LeaseID = l.LeaseID) AS 'MoveInDate',
			 l.LeaseStartDate,
			 l.LeaseEndDate,
			 (SELECT SUM(lli.Amount) 
			  FROM LeaseLedgerItem lli
				INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
				INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
			  WHERE lli.LeaseID = l.LeaseID
				AND lit.IsRent = 1
				AND lli.StartDate <= l.LeaseEndDate
				AND lli.EndDate >= l.LeaseEndDate) AS 'MonthlyRent'
		FROM CollectionAgreement ca
			INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ca.IntegrationPartnerItemID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = ca.ObjectID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND LeaseStatus IN ('Former', 'Evicted')
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
		WHERE ca.AccountID = @accountID
			AND b.PropertyID = @propertyID
			AND ipi.IntegrationPartnerID = @integrationPartnerID
			AND ca.CollectionType = 'Third Party'
			AND ca.IsClosed = 0
			-- Get the latest agreement
			AND ca.CollectionAgreementID = (SELECT TOP 1 CollectionAgreementID
											FROM CollectionAgreement
											WHERE ObjectID = ca.ObjectID
											ORDER BY DateCreated DESC)
			AND ((@startDate IS NULL AND ca.LastSent IS NULL) OR (@startDate IS NOT NULL AND ca.DateCreated >= @startDate AND ca.DateCreated <= @endDate))
											
	INSERT INTO #FileTransactions
		SELECT #lf.UnitLeaseGroupID,
			   cd.CollectionDetailID,
			   --COALESCE(t.TransactionDate, cd.[Date]),
			   cd.[Date],
			   COALESCE(lit2.Name, lit.Name),
			   cd.Amount,
			   0
		FROM CollectionDetail cd
			INNER JOIN #LeaseFiles #lf ON #lf.UnitLeaseGroupID = cd.ObjectID
			INNER JOIN LedgerItemType lit ON cd.LedgerItemTypeID = lit.LedgerItemTypeID
			LEFT JOIN [Transaction] t ON t.TransactionID = cd.OriginalTransactionID
			LEFT JOIN LedgerItemType lit2 ON lit2.LedgerItemTypeID = t.LedgerItemTypeID
			
	UPDATE #ft SET OpenAmount = (Amount - ISNULL((SELECT SUM(ta.Amount) 
													FROM CollectionDetailTransaction cdt
														INNER JOIN #FileTransactions #ft2 ON #ft2.CollectionDetailID = cdt.CollectionDetailID 
														INNER JOIN [Transaction] t ON t.TransactionID = cdt.TransactionID
														LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
														LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
														LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
													WHERE t.ObjectID = #ft2.UnitLeaseGroupID
													  AND #ft.CollectionDetailID = #ft2.CollectionDetailID
													  AND tr.TransactionID IS NULL
													  AND tar.TransactionID IS NULL

													GROUP BY cdt.CollectionDetailID), 0))
			FROM #FileTransactions #ft		
												
	INSERT INTO #Tenants
		SELECT #lf.UnitLeaseGroupID,
				p.PersonID,
				p.FirstName,
				p.LastName,
				p.BirthDate,
				p.SSN,
				p.DriversLicenseNumber,
				p.Phone1,
				p.Phone1Type,
				p.Phone2,
				p.Phone2Type,
				p.Phone3,
				p.phone3Type,
				p.Email
		FROM PersonLease pl
			INNER JOIN Person p ON p.PersonID = pl.PersonID
			INNER JOIN #LeaseFiles #lf ON #lf.LeaseID = pl.LeaseID
		WHERE pl.MainContact = 1
		ORDER BY pl.OrderBy
		
	INSERT INTO #Income
		SELECT 
			e.PersonID,
			e.[Type],

			e.Employer,
			a.StreetAddress,
			a.City,
			a.[State],
			a.[Zip],
			a.Country,
			e.CompanyPhone,
			null,
			e.Title,
			e.ContactName,			
			ISNULL(sal.Amount, 0) AS 'Salary',			
			ISNULL(sal.SalaryPeriod, 'Annually') AS 'SalaryPeriod'




		FROM Employment e
			INNER JOIN #Tenants #t ON #t.PersonID = e.PersonID
			LEFT JOIN Salary sal ON e.EmploymentID = sal.EmploymentID
						AND sal.SalaryID = (SELECT TOP 1 SalaryID
												FROM Salary
												WHERE EmploymentID = e.EmploymentID
												  AND Amount IS NOT NULL
												ORDER BY EffectiveDate DESC, Amount DESC)
			LEFT JOIN [Address] a ON a.AddressID = e.AddressID
		
	INSERT INTO #Address
		SELECT 
			a.ObjectID,
			a.AddressType,
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			a.Country
		FROM [Address] a
			INNER JOIN #Tenants #t ON #t.PersonID = a.ObjectID
		
	INSERT INTO #Address
		SELECT 
			#t.PersonID,
			a.AddressType,
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			a.Country
		FROM Unit u 
			INNER JOIN #LeaseFiles #lf ON #lf.UnitID = u.UnitID
			INNER JOIN [Address] a ON a.AddressID = u.AddressID
			INNER JOIN #Tenants #t ON #t.UnitLeaseGroupID = #lf.UnitLeaseGroupID

	INSERT INTO #CADocuments
		SELECT
			cad.CollectionAgreementDocumentID,
			cad.CollectionAgreementID,
			cad.DocumentID,
			d.Name
		FROM CollectionAgreementDocument cad
			INNER JOIN Document d ON cad.DocumentID = d.DocumentID
			INNER JOIN #LeaseFiles lf ON cad.CollectionAgreementID = lf.CollectionAgreementID
		WHERE cad.AccountID = @accountID

	UPDATE ca
		SET ca.LastSent = @utcNow
		FROM CollectionAgreement ca
		INNER JOIN #LeaseFiles lf ON ca.CollectionAgreementID = lf.CollectionAgreementID
		WHERE ca.AccountID = @accountID
			AND ca.AccountID <> 800 -- Don't clear demo accounts

	INSERT INTO #AlternateContacts
		SELECT
			p.ParentPersonID AS 'ResidentPersonID',
			p.PersonID,
			p.Email,
			p.PreferredName AS 'Name',
			p.Phone1 AS 'PhoneNumber',
			p.Phone2 AS 'WorkPhone',
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			a.Country
		FROM Person p
			INNER JOIN #Tenants t ON p.ParentPersonID = t.PersonID
			LEFT JOIN [Address] a ON p.PersonID = a.ObjectID
		WHERE p.PreferredName IS NOT NULL
			
	SELECT * FROM #LeaseFiles
	SELECT * FROM #FileTransactions
	SELECT * FROM #Tenants	
	SELECT * FROM #Income
	SELECT * FROM #Address
	SELECT * FROM #CADocuments
	SELECT * FROM #AlternateContacts
END
GO
