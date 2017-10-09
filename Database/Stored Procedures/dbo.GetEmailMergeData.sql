SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 26, 2013
-- Description:	Gets the email merge data for the given email recipients
-- =============================================
CREATE PROCEDURE [dbo].[GetEmailMergeData]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@fieldNames StringCollection readonly,
	@emailRecipientIDs GuidCollection readonly	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #FormLetterData
	(
		EmailRecipientID uniqueidentifier,
		FieldName nvarchar(500),
		Value nvarchar(max)
	)						   
    
    -- **** Lease Data **** --
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LeaseEndDate'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT er.EmailRecipientID, 'LeaseEndDate', CONVERT(nvarchar(50), l.LeaseEndDate, 101)
			FROM Lease l	
				INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)		
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LeaseStartDate'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'LeaseStartDate', CONVERT(nvarchar(50), l.LeaseStartDate, 101)
			FROM Lease l	
				INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)	
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RenewalLeaseStartDate'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'RenewalLeaseStartDate', CONVERT(nvarchar(50), DATEADD(DAY, 1, l.LeaseEndDate), 101)
			FROM Lease l	
				INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)	
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MoveInDate'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT er.EmailRecipientID, 'MoveInDate', CONVERT(nvarchar(50), MIN(pl.MoveInDate), 101)
			FROM Lease l	
				INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)			
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID			
			WHERE (l.LeaseStatus = 'Cancelled' OR pl.ResidencyStatus <> 'Cancelled')
			GROUP BY l.LeaseID, er.EmailRecipientID				
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MainContactNames'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT lids.Value, 'MainContactNames', 
				(STUFF((SELECT ', ' + (FirstName + ' ' + LastName)
						FROM Person p
						INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID AND pl.MainContact = 1
						INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
						WHERE l.LeaseID = (SELECT ObjectID FROM EmailRecipient WHERE EmailRecipientID = lids.Value)
							AND (l.LeaseStatus = 'Cancelled' OR pl.ResidencyStatus <> 'Cancelled')
						ORDER BY pl.OrderBy, p.FirstName
						FOR XML PATH ('')), 1, 2, ''))
			FROM @emailRecipientIDs lids				
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MarketRent') OR EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MarketRentAndMonthToMonthFee'))
    BEGIN
		CREATE TABLE #UnitAmenities (
			Number nvarchar(20) not null,
			UnitID uniqueidentifier not null,
			UnitTypeID uniqueidentifier not null,
			UnitStatus nvarchar(200) not null,
			UnitStatusLedgerItemTypeID uniqueidentifier not null,
			RentLedgerItemTypeID uniqueidentifier not null,
			MarketRent decimal null,
			Amenities nvarchar(MAX) null)
			
		CREATE TABLE #Properties (
			Sequence int identity not null,
			PropertyID uniqueidentifier not null)
			
		INSERT #Properties SELECT DISTINCT ut.PropertyID FROM UnitType ut
															INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
															INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
															INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
															INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID
														  WHERE er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
														  
		DECLARE @date date, @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection
		SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
		SET @date = GETDATE()
		WHILE (@ctr <= @maxCtr)
		BEGIN
			SELECT @propertyID = PropertyID FROM #Properties WHERE Sequence = @ctr
			INSERT @unitIDs 
				SELECT u.UnitID 
					FROM Unit u
						INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
						INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
						INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
						INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID
					WHERE er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
			INSERT #UnitAmenities 
				EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date
												
			SET @ctr = @ctr + 1
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MarketRent'))
		BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'MarketRent', CONVERT(nvarchar(20), CAST(#ua.MarketRent AS MONEY), 1)
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID	
				INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID	
			WHERE er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)				
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MarketRentAndMonthToMonthFee'))
		BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'MarketRentAndMonthToMonthFee', CONVERT(varchar(20), CAST((#ua.MarketRent + p.MonthToMonthFee) AS MONEY), 1)
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID		
				INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID
			WHERE er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)				
		END
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'NonMainContactNames'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT lids.Value, 'NonMainContactNames', 
				(STUFF((SELECT ', ' + (FirstName + ' ' + LastName)
						FROM Person p
						INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID AND pl.MainContact = 0
						INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
						WHERE l.LeaseID = (SELECT ObjectID FROM EmailRecipient WHERE EmailRecipientID = lids.Value)
							AND (l.LeaseStatus = 'Cancelled' OR pl.ResidencyStatus <> 'Cancelled')
						ORDER BY pl.OrderBy, p.FirstName
						FOR XML PATH ('')), 1, 2, ''))
			FROM @emailRecipientIDs lids				
    END
    
    -- **** Unit Information ****
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Unit'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'Unit', u.Number
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitStreetAddress'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'UnitStreetAddress', ISNULL(a.StreetAddress, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			LEFT JOIN [Address] a ON a.AddressID = u.AddressID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitState'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'UnitState', ISNULL(a.[State], '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			LEFT JOIN [Address] a ON a.AddressID = u.AddressID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitCity'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'UnitCity', ISNULL(a.City, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			LEFT JOIN [Address] a ON a.AddressID = u.AddressID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitZipCode'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'UnitZipCode', ISNULL(a.Zip, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			LEFT JOIN [Address] a ON a.AddressID = u.AddressID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitTypeDescription'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'UnitTypeDescription', ut.[Description]
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END

	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitTypeName'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'UnitTypeName', ut.Name
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    -- **** Property Infomration ****
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyName'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyName', p.Name
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyStreetAddress'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyStreetAddress', ISNULL(a.StreetAddress, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID
			LEFT JOIN [Address] a ON a.AddressID = p.AddressID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyCity'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyCity', ISNULL(a.City, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID
			LEFT JOIN [Address] a ON a.AddressID = p.AddressID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyState'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyState', ISNULL(a.[State], '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID
			LEFT JOIN [Address] a ON a.AddressID = p.AddressID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyZipCode'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyZipCode', ISNULL(a.Zip, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID
			LEFT JOIN [Address] a ON a.AddressID = p.AddressID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPhoneNumber'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyPhoneNumber', ISNULL(p.PhoneNumber, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID			
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyEmail'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyEmail', ISNULL(p.Email, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID			
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyWebsite'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyWebsite', ISNULL(p.Website, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID			
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropetyPortalWebsite'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'PropertyPortalWebsite', ('https://' + s.Subdomain + '.myresman.com/Portal/Access/SignIn/' + p.Abbreviation)
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID	
			INNER JOIN Settings s ON s.AccountID = @accountID		
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ManagementCompanyName'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'ManagementCompanyName', ISNULL(v.CompanyName, '')
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID
			LEFT JOIN Vendor v on v.VendorID = p.ManagementCompanyVendorID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MonthToMonthFee'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'MonthToMonthFee', CONVERT(nvarchar(20), CAST(p.MonthToMonthFee AS MONEY), 1)
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID			
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END

	-- **** Transaction Information ***  
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Balance'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'Balance', CONVERT(nvarchar(20), balance.Balance, 1)
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID			
			CROSS APPLY GetObjectBalance2(null, GETDATE(), l.UnitLeaseGroupID, 0, b.PropertyID) balance
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
    END
    
    IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LateFeesCharged'))
    BEGIN
		INSERT INTO #FormLetterData
			SELECT l.LeaseID, 'LateFeesCharged', CONVERT(nvarchar(20), CAST(ISNULL(SUM(ISNULL(t.Amount, 0)), 0) AS MONEY), 1)
			FROM Lease l
			LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID			
			INNER JOIN Settings s ON s.AccountID = @accountID
			INNER JOIN AccountingPeriod ap ON ap.AccountID = @accountID AND ap.StartDate <= GETDATE() AND ap.EndDate >= GETDATE()
			LEFT JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID 
									      AND t.TransactionDate >= ap.StartDate 
									      AND t.TransactionDate <= ap.EndDate
									      AND t.LedgerItemTypeID = s.LateFeeLedgerItemTypeID
			LEFT JOIN [Transaction]	tr ON tr.ReversesTransactionID = t.TransactionID
			INNER JOIN EmailRecipient er ON l.LeaseID = er.ObjectID AND er.EmailRecipientID IN (SELECT Value FROM @emailRecipientIDs)
			WHERE tr.TransactionID IS NULL
			  AND t.ReversesTransactionID IS NULL
			GROUP BY ulg.UnitLeaseGroupID, l.LeaseID									
    END
    
    SELECT * FROM #FormLetterData WHERE Value IS NOT NULL
	
END
GO
