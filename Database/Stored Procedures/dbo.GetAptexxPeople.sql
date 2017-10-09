SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: August 26, 2013
-- Description:	Gets the data needed for Aptexx people sync
-- =============================================
CREATE PROCEDURE [dbo].[GetAptexxPeople] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier = null,
	@modifiedSince datetime,
	@includeBalances bit = 0,
	@objectID uniqueidentifier = null,
	@personID uniqueidentifier = null,
	@integrationPartnerID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @nsfCashOnlyLimit int
    DECLARE @nsfCashOnlyMonths int
    DECLARE @startDate date
	CREATE TABLE #PropertyIDs 
	(
		ID int IDENTITY, 
		PropertyID uniqueidentifier 
	)

	SELECT @nsfCashOnlyLimit = NSFCashOnlyLimit, @nsfCashOnlyMonths = NSFCashOnlyMonths FROM Property WHERE PropertyID = @propertyID AND AccountID = @accountID    
    SET @startDate = DATEADD(month, -@nsfCashOnlyMonths, GETDATE())   

	IF (@propertyID IS NOT NULL)
	BEGIN
		INSERT INTO #PropertyIDs VALUES (@propertyID)
	END

	IF ((SELECT COUNT(*) FROM Property WHERE ParentPropertyID = @propertyID) > 0)
	BEGIN
		INSERT INTO #PropertyIDs
			SELECT DISTINCT p.PropertyID
			FROM Property p
				-- Get the rent IntegrationPartnerItemProperty record for the parent account
				INNER JOIN IntegrationPartnerItemProperty parentipip ON parentipip.IntegrationPartnerItemID = 32 AND parentipip.PropertyID = @propertyID
				-- Make sure the rent IntegrationParnterItemProperty record for the child has the same
				-- Aptexx external_id as the parent
				INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.IntegrationPartnerItemID = 32 AND ipip.PropertyID = p.PropertyID AND ipip.Value1 = parentipip.Value1
			WHERE p.ParentPropertyID = @propertyID
				AND p.AccountID = @accountID

	END

	CREATE TABLE #BalanceChangeLeasePersonIDs ( ObjectID uniqueidentifier, PersonID uniqueidentifier )
	--CREATE TABLE #BalanceChangeProspectPersonIDs ( ObjectID uniqueidentifier, PersonID uniqueidentifier )
	
	-- If we passed in an @objectID we don't need to get a list of people who have had transactions posted to them
	IF (@includeBalances = 1 AND @objectID IS NULL)
	BEGIN
		-- Get the PersonIDs of UnitLeaseGroups that had a transaction
		-- posted since the last time the request was made
		INSERT INTO #BalanceChangeLeasePersonIDs
			SELECT DISTINCT ulg.UnitLeaseGroupID, pl.PersonID
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			WHERE t.AccountID = @accountID			
				AND (@propertyID IS NULL OR t.PropertyID IN (SELECT PropertyID FROM #PropertyIDs))
				AND tt.[Group] = 'Lease'
				AND t.[TimeStamp] >= @modifiedSince
				AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
									INNER JOIN Ordering o ON o.Value = l2.LeaseStatus
								 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 ORDER BY OrderBy)			
								 
		--INSERT INTO #BalanceChangeProspectPersonIDs
		--	SELECT DISTINCT p.PersonID, p.PersonID
		--	FROM [Transaction] t
		--		INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
		--		INNER JOIN Person p ON p.PersonID = t.ObjectID
		--	WHERE t.AccountID = @accountID			
		--		AND (@propertyID IS NULL OR t.PropertyID = @propertyID)
		--		AND tt.[Group] = 'Prospect'
		--		AND t.[TimeStamp] >= @modifiedSince											 					
	END

	-- 0 = Don't accept any payments
	-- 1 = Accept any payments
	-- 2 = Cash equivalent / Certified funds

	CREATE TABLE #People
	(
		LastModified DateTime,
		PropertyID uniqueidentifier,
		ExternalID nvarchar(100),
		ObjectID uniqueidentifier,
		ObjectType nvarchar(100),
		PersonID uniqueidentifier,
		FirstName nvarchar(100),
		LastName nvarchar(100),
		Unit nvarchar(100),
		StreetAddress nvarchar(500),
		City nvarchar(50),
		[State] nvarchar(50),
		Zip nvarchar(20),
		Email nvarchar(100),
		MobilePhone nvarchar(100),
		HomePhone nvarchar(100),
		Phone nvarchar(100),
		LeaseStartDate date,
		LeaseEndDate date,
		MoveInDate date,
		MoveOutDate date,		
		PaymentStatus int
	)

	INSERT INTO #People
		SELECT DISTINCT
			p.LastModified,
			b.PropertyID,
			ipip.Value1 AS 'ExternalID',
			ulg.UnitLeaseGroupID AS 'ObjectID',
			'Lease' AS 'ObjectType',
			p.PersonID,
			p.FirstName,
			p.LastName,
			u.Number AS 'Unit',
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			p.Email,	
			CASE WHEN (p.Phone1Type = 'Mobile') THEN p.Phone1
				 WHEN (p.Phone2Type = 'Mobile') THEN p.Phone2
				 WHEN (p.Phone3Type = 'Mobile') THEN p.Phone3
				 ELSE null END AS 'MobilePhone',
			CASE WHEN (p.Phone1Type = 'Home') THEN p.Phone1
				 WHEN (p.Phone2Type = 'Home') THEN p.Phone2
				 WHEN (p.Phone3Type = 'Home') THEN p.Phone3
				 ELSE null END AS 'HomePhone',
			p.Phone1 AS 'Phone',
			l.LeaseStartDate,
			l.LeaseEndDate,	
			(CASE WHEN pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed', 'Pending Renewal') THEN pl.MoveInDate
				 ELSE null
			END) AS 'MoveInDate',
			(CASE WHEN pl.ResidencyStatus IN ('Evicted', 'Former', 'Denied') THEN pl.MoveOutDate
				ELSE null
			END) AS 'MoveOutDate',		
			(CASE WHEN ulg.OnlinePaymentsDisabled = 1 THEN 0
				  WHEN ulg.CashOnlyOverride = 1 OR
					  (((SELECT COUNT(DISTINCT p.PaymentID) 
						FROM Payment p								
						LEFT JOIN PersonNote pn ON p.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
						WHERE p.[Date] >= @startDate
							AND p.[Type] = 'NSF'
							AND pn.PersonNoteID IS NULL
							AND p.ObjectID = ulg.UnitLeaseGroupID) +
						(CASE WHEN ulg.NSFImportDate IS NOT NULL AND ulg.NSFImportDate >= @startDate THEN ISNULL(ulg.ImportNSFCount, 0)
								ELSE 0
							END)) >= @nsfCashOnlyLimit) THEN 2
				  ELSE 1
			 END) AS 'PaymentStatus'
		FROM Person p
			INNER JOIN PersonLease pl ON pl.PersonID = p.PersonID
			INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			-- Make sure they are integrated with the integrationPartner passed in
			INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.PropertyID = b.PropertyID
			INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID 
			LEFT JOIN [Address] a ON u.AddressID = a.AddressID
		WHERE ((p.LastModified >= @modifiedSince) OR (p.PersonID IN (SELECT PersonID FROM #BalanceChangeLeasePersonIDs)) OR (l.UnitLeaseGroupID = @objectID))
			AND (pl.MainContact = 1 OR pl.PersonID = @personID)
			AND p.AccountID = @accountID
			AND (@propertyID IS NULL OR b.PropertyID IN (SELECT PropertyID FROM #PropertyIDs))
			AND ((@integrationPartnerID = 1013 AND ipi.IntegrationPartnerID = @integrationPartnerID AND ipip.IntegrationPartnerItemID = 35)					-- 1013 = Aptexx, 35 = AX_Portal
			  OR (@integrationPartnerID IN (1010, 1078) AND ipi.IntegrationPartnerID IN (1010, 1078) AND ipip.IntegrationPartnerItemID IN ( 29, 151)))		-- 1010 = PayLease, 29 = PL_Rent, 1078 = PayLease Utilities, 151 = Billing			
			AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
							 FROM Lease l2
								INNER JOIN Ordering o ON o.Value = l2.LeaseStatus
							 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							 ORDER BY OrderBy)				
			AND (pl.MoveOutDate IS NULL OR pl.MoveOutDate >= DATEADD(MONTH, -3, GETDATE()))
			AND (@objectID IS NULL OR (l.UnitLeaseGroupID = @objectID AND p.PersonID = @personID))
						
		UNION

		SELECT DISTINCT
			p.LastModified,
			pps.PropertyID,
			ipip.Value1 AS 'ExternalID',
			pr.PersonID AS 'ObjectID',
			'Prospect' AS 'ObjectType',
			p.PersonID,
			p.FirstName,
			p.LastName,
			'Prospect' AS 'Unit',
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			p.Email,	
			CASE WHEN (p.Phone1Type = 'Mobile') THEN p.Phone1
				 WHEN (p.Phone2Type = 'Mobile') THEN p.Phone2
				 WHEN (p.Phone3Type = 'Mobile') THEN p.Phone3
				 ELSE null END AS 'MobilePhone',
			CASE WHEN (p.Phone1Type = 'Home') THEN p.Phone1
				 WHEN (p.Phone2Type = 'Home') THEN p.Phone2
				 WHEN (p.Phone3Type = 'Home') THEN p.Phone3
				 ELSE null END AS 'HomePhone',
			p.Phone1 AS 'Phone',
			null,
			null,
			null,
			null,		
			1 AS 'PaymenStatus'
		FROM Person p
			INNER JOIN Prospect pr ON pr.PersonID = p.PersonID
			INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
			-- Make sure they are integrated with the integrationPartner passed in
			INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.PropertyID = pps.PropertyID
			INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID 
			LEFT JOIN [Address] a ON a.ObjectID = p.PersonID
			-- Make sure they haven't been converted to a Applicant/Resident
			LEFT JOIN PersonType pt ON pt.PersonID = p.PersonID AND pt.[Type] = 'Resident'
		WHERE ((p.LastModified >= @modifiedSince) OR (p.PersonID = @objectID))
			AND p.IsTransactionable = 1
			AND p.AccountID = @accountID

			AND (@propertyID IS NULL OR pps.PropertyID IN (SELECT PropertyID FROM #PropertyIDs))
			AND ((@integrationPartnerID = 1013 AND ipi.IntegrationPartnerID = @integrationPartnerID AND ipip.IntegrationPartnerItemID = 35)					-- 1013 = Aptexx, 35 = AX_Portal
			  OR (@integrationPartnerID IN (1010, 1078) AND ipi.IntegrationPartnerID IN (1010, 1078) AND ipip.IntegrationPartnerItemID IN ( 29, 151)))		-- 1010 = PayLease, 29 = PL_Rent, 1078 = PayLease Utilities, 151 = Billing			
			AND pt.PersonTypeID IS NULL
			AND p.LastModified > '2013-8-22'				
			AND (@objectID IS NULL OR p.PersonID = @objectID)			
		
		UNION

		SELECT DISTINCT
			p.LastModified,
			ptp.PropertyID,
			ipip.Value1 AS 'ExternalID',
			p.PersonID AS 'ObjectID',
			'Non-Resident Account' AS 'ObjectType',
			p.PersonID,
			p.FirstName,
			p.LastName,
			'Non-Resident' AS 'Unit',
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			null,
			null 'MobilePhone',
			null AS 'HomePhone',
			p.Phone1 AS 'Phone',
			null,
			null,
			null,
			null,		
			1 AS 'PaymentStatus'
		FROM Person p			
			INNER JOIN PersonType pt ON pt.PersonID = p.PersonID AND pt.[Type] = 'Non-Resident Account'		
			INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID
			-- Make sure they are integrated with the integrationPartner passed in
			INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.PropertyID = ptp.PropertyID
			INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID 
			LEFT JOIN [Address] a ON a.ObjectID = p.PersonID						
		WHERE (@objectID IS NULL OR @objectID = p.PersonID)
			AND p.IsTransactionable = 1
			AND p.AccountID = @accountID

			AND (@propertyID IS NULL OR ptp.PropertyID IN (SELECT PropertyID FROM #PropertyIDs))	
			AND ((@integrationPartnerID = 1013 AND ipi.IntegrationPartnerID = @integrationPartnerID AND ipip.IntegrationPartnerItemID = 35)					-- 1013 = Aptexx, 35 = AX_Portal
			  OR (@integrationPartnerID IN (1010, 1078) AND ipi.IntegrationPartnerID IN (1010, 1078) AND ipip.IntegrationPartnerItemID IN ( 29, 151)))		-- 1010 = PayLease, 29 = PL_Rent, 1078 = PayLease Utilities, 151 = Billing			
			--AND p.LastModified > '2013-8-22'			
			AND (@objectID IS NULL OR p.PersonID = @objectID)	

		UNION

		SELECT DISTINCT
			GETDATE(),
			woit.PropertyID,
			ipip.Value1 AS 'ExternalID',
			woit.WOITAccountID AS 'ObjectID',
			'WOIT Account' AS 'ObjectType',
			woit.WOITAccountID,
			woit.Name,
			'',
			'WOIT Account' AS 'Unit',
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			'',
			NULL 'MobilePhone',
			NULL 'HomePhone',
			prop.PhoneNumber AS 'Phone',
			null,
			null,
			null,
			null,			
			1 AS 'PaymentStatus'
		FROM WOITAccount woit
			INNER JOIN Property prop ON woit.PropertyID = prop.PropertyID
			-- Make sure they are integrated with the integrationPartner passed in
			INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.PropertyID = woit.PropertyID
			INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID 	
			LEFT JOIN [Address] a ON a.ObjectID = prop.PropertyID					
		WHERE 
			woit.IsTransactionable = 1 
			AND woit.AccountID = @accountID
			AND woit.BillingAccountID IS NULL
			AND (@propertyID IS NULL OR woit.PropertyID  IN (SELECT PropertyID FROM #PropertyIDs))		
			AND ((@integrationPartnerID = 1013 AND ipi.IntegrationPartnerID = @integrationPartnerID AND ipip.IntegrationPartnerItemID = 35)					-- 1013 = Aptexx, 35 = AX_Portal
			  OR (@integrationPartnerID IN (1010, 1078) AND ipi.IntegrationPartnerID IN (1010, 1078) AND ipip.IntegrationPartnerItemID IN ( 29, 151)))		-- 1010 = PayLease, 29 = PL_Rent, 1078 = PayLease Utilities, 151 = Billing			
			AND (@objectID IS NULL OR woit.WOITAccountID = @objectID)
			--AND p.LastModified > '2013-8-22'				
	
	IF (@includeBalances = 1)
	BEGIN
			

		-- CREATE TABLE #OutstandingCharges (
		--	ObjectID			uniqueidentifier		NOT NULL,
		--	TransactionID		uniqueidentifier		NOT NULL,
		--	Amount				money					NOT NULL,
		--	TaxAmount			money					NULL,
		--	UnPaidAmount		money					NULL,
		--	TaxUnpaidAmount		money					NULL,
		--	[Description]		nvarchar(500)			NULL,
		--	TranDate			datetime2				NULL,
		--	GLAccountID			uniqueidentifier		NULL, 
		--	OrderBy				smallint				NULL,
		--	TaxRateGroupID		uniqueidentifier		NULL,
		--	LedgerItemTypeID	uniqueidentifier		NULL,
		--	LedgerItemTypeAbbr	nvarchar(50)			NULL,
		--	GLNumber			nvarchar(50)			NULL,
		--	IsWriteOffable		bit						NULL,
		--	Notes				nvarchar(MAX)			NULL)		
		
		--CREATE TABLE #UnappliedPayments (			
		--	ObjectID			uniqueidentifier		NOT NULL,
		--	TransactionID		uniqueidentifier		NOT NULL,
		--	PaymentID			uniqueidentifier		NOT NULL,
		--	TTName				nvarchar(25)			NOT NULL,
		--	TransactionTypeID	uniqueidentifier		NOT NULL,
		--	Amount				money					NOT NULL,
		--	Reference			nvarchar(50)			NULL,
		--	LedgerItemTypeID	uniqueidentifier		NULL,
		--	[Description]		nvarchar(1000)			NULL,
		--	Origin				nvarchar(50)			NULL,
		--	PaymentDate			date					NULL,
		--	PostingBatchID		uniqueidentifier		NULL,
		--	Allocated			bit						NOT NULL,
		--	AppliesToLedgerItemTypeID uniqueidentifier	NULL,
		--	LedgerItemTypeAbbreviation	nvarchar(50)	NULL,
		--	GLNumber			nvarchar(50)			NULL)

		--DECLARE @maxCtr int = (SELECT MAX(ID) FROM #PropertyIDs)
		--DECLARE @ctr int = 1000

		--WHILE (@maxCtr >= @ctr)
		--BEGIN
			
		--	TRUNCATE TABLE #OutstandingCharges
		--	TRUNCATE TABLE #UnappliedPayments

		--	SELECT @propertyID = PropertyID FROM #PropertyIDs WHERE ID = @ctr
			
		--	INSERT INTO #OutstandingCharges EXEC GetOutstandingCharges @accountID, @propertyID, @objectID, 'Lease', 0	
						
		--	INSERT INTO #UnappliedPayments EXEC GetUnappliedPayments @accountID, @propertyID, @objectID, 'Lease', null
		
		--	UPDATE #People SET Balance = ISNULL((SELECT ISNULL(SUM(UnPaidAmount), 0)
		--										  FROM #OutstandingCharges #oc
		--											WHERE #oc.ObjectID = #People.ObjectID
		--												AND #People.PropertyID = @propertyID), 0)
		--	WHERE #People.Balance IS NULL
		--		AND #People.PropertyID = @propertyID
									  
		--	UPDATE #People SET Balance = Balance - ISNULL((SELECT ISNULL(SUM(Amount), 0)
		--												  FROM #UnappliedPayments #up
		--													WHERE #up.ObjectID = #People.ObjectID
		--														AND #People.PropertyID = @propertyID), 0)
		--	WHERE #People.Balance IS NULL
		--		AND #People.PropertyID = @propertyID
			
		--	SET @ctr = @ctr + 1
		--END
					
		--UPDATE #People SET Balance = 0 WHERE Balance IS NULL

		SELECT #People.*, 
			Balance.Balance		
		FROM #People 
		CROSS APPLY GetObjectBalance2('1900-1-1', '2099-12-31', #People.ObjectID, 0, #People.PropertyID) Balance
		ORDER BY LastModified, LeaseEndDate
	END
	ELSE
	BEGIN
		SELECT #People.*, 
			NULL AS 'Balance'
		FROM #People 	
		ORDER BY LastModified, LeaseEndDate
	END
END
GO
