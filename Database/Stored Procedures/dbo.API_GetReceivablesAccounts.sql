SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: August 26, 2013
-- Description:	Gets the data needed for Aptexx people sync
-- =============================================
CREATE PROCEDURE [dbo].[API_GetReceivablesAccounts] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier,
	@modifiedSince datetime,	
	@objectID uniqueidentifier = null,	
	@personID uniqueidentifier = null,
	@includeBalances bit = 0	
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

	--IF (@propertyID IS NOT NULL)
	--BEGIN
		INSERT INTO #PropertyIDs VALUES (@propertyID)
	--END

	--IF ((SELECT COUNT(*) FROM Property WHERE ParentPropertyID = @propertyID) > 0)
	--BEGIN
	--	INSERT INTO #PropertyIDs
	--		SELECT DISTINCT p.PropertyID
	--		FROM Property p
	--			-- Get the rent IntegrationPartnerItemProperty record for the parent account
	--			INNER JOIN IntegrationPartnerItemProperty parentipip ON parentipip.IntegrationPartnerItemID = 32 AND parentipip.PropertyID = @propertyID
	--			-- Make sure the rent IntegrationParnterItemProperty record for the child has the same
	--			-- Aptexx external_id as the parent
	--			INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.IntegrationPartnerItemID = 32 AND ipip.PropertyID = p.PropertyID AND ipip.Value1 = parentipip.Value1
	--		WHERE p.ParentPropertyID = @propertyID
	--			AND p.AccountID = @accountID

	--END

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
	END	

	CREATE TABLE #People
	(
		LastModified DateTime,
		PropertyID uniqueidentifier,		
		BillingAccountID uniqueidentifier,
		AccountType nvarchar(100),
		PersonID uniqueidentifier,
		FirstName nvarchar(100),
		LastName nvarchar(100),
		Unit nvarchar(100),
		Building nvarchar(100),
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
		PaymentStatus nvarchar(100),
		Status nvarchar(100)
	)

	INSERT INTO #People
		SELECT DISTINCT
			p.LastModified,
			b.PropertyID,			
			ulg.UnitLeaseGroupID AS 'BillingAccountID',
			'Lease' AS 'AccountType',
			p.PersonID,
			p.FirstName,
			p.LastName,
			u.Number AS 'Unit',
			b.Name,
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
			pl.MoveInDate,
			pl.MoveOutDate,
			--(CASE WHEN pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed', 'Pending Renewal') THEN pl.MoveInDate
			--	 ELSE null
			--END) AS 'MoveInDate',
			--(CASE WHEN pl.ResidencyStatus IN ('Evicted', 'Former', 'Denied') THEN pl.MoveOutDate
			--	ELSE null
			--END) AS 'MoveOutDate',		
			(CASE WHEN ulg.OnlinePaymentsDisabled = 1 THEN 'Do Not Accept'
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
							END)) >= @nsfCashOnlyLimit) THEN 'Certified Funds Only'
				  ELSE 'Accept'
			 END) AS 'PaymentStatus',
			 pl.ResidencyStatus AS 'Status'
		FROM Person p
			INNER JOIN PersonLease pl ON pl.PersonID = p.PersonID
			INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID		
			LEFT JOIN [Address] a ON u.AddressID = a.AddressID
		WHERE ((p.LastModified >= @modifiedSince) OR (p.PersonID IN (SELECT PersonID FROM #BalanceChangeLeasePersonIDs)) OR (l.UnitLeaseGroupID = @objectID))
			-- 2016-11-30: CHange made to return all people since Aptexx is deactivating accounts
			--				if they don't show up in the feed
			--AND (pl.MainContact = 1 OR pl.PersonID = @personID)
			AND p.AccountID = @accountID
			AND (@propertyID IS NULL OR b.PropertyID IN (SELECT PropertyID FROM #PropertyIDs))
			AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
							 FROM Lease l2
								INNER JOIN PersonLease pl2 ON pl2.PersonID = p.PersonID AND pl2.LeaseID = l2.LeaseID
								INNER JOIN Ordering o ON o.Value = l2.LeaseStatus								
							 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID								
							 ORDER BY o.OrderBy)				
			AND (pl.MoveOutDate IS NULL OR pl.MoveOutDate >= DATEADD(MONTH, -6, GETDATE()))
			AND (@objectID IS NULL OR (l.UnitLeaseGroupID = @objectID AND p.PersonID = @personID))
						
		UNION

		SELECT DISTINCT
			p.LastModified,
			pps.PropertyID,			
			pr.PersonID AS 'BillingAccountID',
			'Prospect' AS 'AccountType',
			p.PersonID,
			p.FirstName,
			p.LastName,
			'' AS 'Unit',
			'' AS 'Building',
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
			'Accept' AS 'PaymenStatus',
			'Prospect' AS 'Status'
		FROM Person p
			INNER JOIN Prospect pr ON pr.PersonID = p.PersonID
			INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID			
			LEFT JOIN [Address] a ON a.ObjectID = p.PersonID
			-- Make sure they haven't been converted to a Applicant/Resident
			LEFT JOIN PersonType pt ON pt.PersonID = p.PersonID AND pt.[Type] = 'Resident'
		WHERE ((p.LastModified >= @modifiedSince) OR (p.PersonID = @objectID))
			AND p.IsTransactionable = 1
			AND p.AccountID = @accountID
			AND (@propertyID IS NULL OR pps.PropertyID IN (SELECT PropertyID FROM #PropertyIDs))			
			AND pt.PersonTypeID IS NULL
			AND p.LastModified > '2013-8-22'				
			AND (@objectID IS NULL OR p.PersonID = @objectID)			
		
		UNION

		SELECT DISTINCT
			p.LastModified,
			ptp.PropertyID,			
			p.PersonID AS 'ObjectID',
			'Non-Resident Account' AS 'ObjectType',
			p.PersonID,
			p.FirstName,
			p.LastName,
			'' AS 'Unit',
			'' AS 'Building',
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
			'Accept' AS 'PaymentStatus',
			'Non-Resident Account' AS 'Status'
		FROM Person p			
			INNER JOIN PersonType pt ON pt.PersonID = p.PersonID AND pt.[Type] = 'Non-Resident Account'		
			INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID			
			LEFT JOIN [Address] a ON a.ObjectID = p.PersonID						
		WHERE (@objectID IS NULL OR @objectID = p.PersonID)
			AND p.IsTransactionable = 1
			AND p.AccountID = @accountID
			AND (@propertyID IS NULL OR ptp.PropertyID IN (SELECT PropertyID FROM #PropertyIDs))	
			AND (@objectID IS NULL OR p.PersonID = @objectID)	

		UNION

		SELECT DISTINCT
			GETDATE(),
			woit.PropertyID,			
			woit.WOITAccountID AS 'ObjectID',
			'WOIT Account' AS 'AccountType',
			woit.WOITAccountID,
			woit.Name,
			'',
			'' AS 'Unit',
			'' AS 'Building',
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
			'Accept' AS 'PaymentStatus',
			'WOIT Account' AS 'Status'
		FROM WOITAccount woit
			INNER JOIN Property prop ON woit.PropertyID = prop.PropertyID			
			LEFT JOIN [Address] a ON a.ObjectID = prop.PropertyID					
		WHERE 
			woit.IsTransactionable = 1 
			AND woit.AccountID = @accountID
			AND (@propertyID IS NULL OR woit.PropertyID  IN (SELECT PropertyID FROM #PropertyIDs))					
			AND (@objectID IS NULL OR woit.WoitAccountID = @objectID)						
	
	
		SELECT #People.*
		FROM #People 	
		ORDER BY LastModified
	
END
GO
