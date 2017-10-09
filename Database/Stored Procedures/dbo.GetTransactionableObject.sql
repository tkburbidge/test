SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: October 7, 2011
-- Description:	Gets the Transactionable Account information
--				for a single account
-- =============================================
CREATE PROCEDURE [dbo].[GetTransactionableObject]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@objectID uniqueidentifier,
	@transactionTypeGroup varchar(100),
	@personID uniqueidentifier 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	
    
    DECLARE @object TABLE 
    (
		ObjectID uniqueidentifier,	
		PersonID uniqueidentifier,	
		ObjectName nvarchar(500),
		UnitID uniqueidentifier null,
		UnitNumber nvarchar(50) null, 
		LeaseStatus nvarchar(50) null,
		TransactionTypeGroup nvarchar(50),
		CashOnly bit,
		PropertyID uniqueidentifier	null,
		AllowPayments bit not null,
		HAPWOITAccountID uniqueidentifier null
    )
    
    IF (@transactionTypeGroup = 'Lease')
		BEGIN
			INSERT INTO @object
				SELECT UnitLeaseGroups.UnitLeaseGroupID AS ObjectID,		   	   		     
					  -- Get a contatonated list of the transactionable
					  -- residents on the lease
					  --(UnitLeaseGroups.Number + ' - ' + 
					  --STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							-- FROM Person
							-- INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							-- INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							-- INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							-- WHERE PersonLease.LeaseID = UnitLeaseGroups.LeaseID
							--	   AND PersonType.[Type] = 'Resident'				   
							--	   AND PersonLease.MainContact = 1	
							-- ORDER BY PersonLease.OrderBy, Person.PreferredName			   
							-- FOR XML PATH ('')), 1, 2, '')
							-- + (CASE WHEN UnitLeaseGroups.LeaseStatus IN ('Current') THEN '' ELSE ' - (' + UnitLeaseGroups.LeaseStatus + ')' END)) AS ObjectName,
						UnitLeaseGroups.PersonID AS 'PersonID',
						UnitLeaseGroups.Number + ' - ' + UnitLeaseGroups.PersonName + (CASE WHEN UnitLeaseGroups.LeaseStatus IN ('Current') THEN '' ELSE ' - (' + UnitLeaseGroups.LeaseStatus + ')' END) AS ObjectName,
						UnitLeaseGroups.UnitID,
						UnitLeaseGroups.Number AS 'UnitNumber', 
						UnitLeaseGroups.LeaseStatus AS 'LeaseStatus',
						'Lease' AS TransactionTypeGroup,
						UnitLeaseGroups.CashOnlyOverride AS 'CashOnly',
						UnitLeaseGroups.PropertyID,
						(CASE WHEN UnitLeaseGroups.DoNotAllowUnderEvictionPayments = 1 AND UnitLeaseGroups.LeaseStatus = 'Under Eviction' THEN CAST(0 AS BIT)
					      ELSE CAST(1 AS BIT)
					 END) AS 'AllowPayments',
					UnitLeaseGroups.HAPWOITAccountID
				FROM   (SELECT UnitLeaseGroup.UnitLeaseGroupID, Lease.LeaseID, Lease.LeaseStatus, Unit.UnitID, Unit.Number, Building.PropertyID, UnitLeaseGroup.CashOnlyOverride,
								Person.PreferredName + ' ' + Person.LastName AS 'PersonName', Person.PersonID AS 'PersonID', Property.DoNotAllowUnderEvictionPayments, WOITAccount.WOITAccountID as 'HAPWOITAccountID'
						FROM UnitLeaseGroup	
						CROSS APPLY (SELECT TOP 1 l.* FROM Lease l 
									 INNER JOIN Ordering o ON l.LeaseStatus = o.[Value] AND o.[Type] = 'Lease'
									 INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
									 WHERE l.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID		
									 AND (@personID IS NULL OR pl.PersonID = @personID)	     		 
									 ORDER BY o.OrderBy) AS Lease
						INNER JOIN Unit ON UnitLeaseGroup.UnitID = Unit.UnitID 
						INNER JOIN Building ON Building.BuildingID = Unit.BuildingID
						INNER JOIN Property ON Building.PropertyID = Property.PropertyID
						INNER JOIN PersonLease ON Lease.LeaseID = PersonLease.LeaseID
						INNER JOIN Person ON PersonLease.PersonID = Person.PersonID
					LEFT JOIN WOITAccount ON Lease.UnitLeaseGroupID = WOITAccount.BillingAccountID
						WHERE UnitLeaseGroup.AccountID = @accountID
							  AND UnitLeaseGroup.UnitLeaseGroupID = @objectID
							  AND ((@personID IS NULL AND PersonLease.MainContact = 1) OR (@personID = Person.PersonID))) AS UnitLeaseGroups
		END	
	ELSE IF (@transactionTypeGroup = 'WOIT Account')
		BEGIN
			INSERT INTO @object
				SELECT WOITAccount.WOITAccountID AS ObjectID,
						NULL AS PersonID,
					   WOITAccount.Name AS ObjectName,
					   NULL AS UnitID,
						NULL AS 'UnitNumber',
						NULL AS 'LeaseStatus',
					   'WOIT Account' AS TransactionTypeGroup,
					   CAST (0 AS BIT) AS 'CashOnly',
					   WOITAccount.PropertyID,
					   CAST(1 AS BIT) AS 'AllowPayments',
					   NULL as 'HAPWOITAccountID'
				FROM WOITAccount
				WHERE WOITAccount.AccountID = @accountID 
					  AND WOITAccount.IsTransactionable = 1 
					  AND WOITAccount.WOITAccountID = @objectID
		END
	ELSE 
	BEGIN
		INSERT INTO @object
			SELECT Person.PersonID AS ObjectID, 	
					Person.PersonID AS PersonID,  
				  (Person.PreferredName + ' ' + Person.LastName) AS ObjectName, 
				   NULL AS UnitID,
				   NULL AS 'UnitNumber',
				   NULL AS 'LeaseStatus',
				   @transactionTypeGroup AS TransactionTypeGroup,
				   CAST (0 AS BIT) AS 'CashOnly',
				   ptp.PropertyID,
				   CAST(1 AS BIT) AS 'AllowPayments',
				   NULL as 'HAPWOITAccountID'
			FROM Person 
			INNER JOIN PersonType pt ON pt.PersonID = Person.PersonID AND pt.[Type] = @transactionTypeGroup
			INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID
			WHERE Person.AccountID = @accountID	  
				  AND Person.IsTransactionable = 1
				  AND Person.PersonID = @objectID		
				  AND ptp.PersonTypePropertyID = (SELECT TOP 1 PersonTypePropertyID
												  FROM PersonTypeProperty 
												  WHERE PersonTypeID = pt.PersonTypeID)
	END
	
	DECLARE @nsfCashOnlyLimit int
    DECLARE @nsfCashOnlyMonths int
    DECLARE @startDate date
    DECLARE @propertyID uniqueidentifier     
    DECLARE @nsfCount int
    SELECT TOP 1 @propertyID = PropertyID FROM @object
    
    -- If we have a property specified and the object isn't already defined as cash only
    IF (@propertyID IS NOT NULL AND (SELECT TOP 1 CashOnly FROM @object) <> 1)
    BEGIN    
		SELECT @nsfCashOnlyLimit = NSFCashOnlyLimit, @nsfCashOnlyMonths = NSFCashOnlyMonths FROM Property WHERE PropertyID = @propertyID AND AccountID = @accountID    
		SET @startDate = DATEADD(month, -@nsfCashOnlyMonths, GETDATE())
		
		SET @nsfCount = ((SELECT COUNT(DISTINCT p.PaymentID)
						FROM Payment p
						--INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
						--INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
						LEFT JOIN PersonNote pn ON p.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
						WHERE p.[Date] >= @startDate
							AND p.[Type] = 'NSF'
							AND p.ObjectID = @objectID
							AND pn.PersonNoteID IS NULL))
									
		IF ((SELECT NSFImportDate FROM UnitLeaseGroup WHERE UnitLeaseGroupID = @objectID) >= @startDate)
		BEGIN
			SET @nsfCount = ISNULL(@nsfCount, 0) + ISNULL((SELECT ImportNSFCount FROM UnitLeaseGroup WHERE UnitLeaseGroupID = @objectID), 0)
		END
							
		IF @nsfCount >= @nsfCashOnlyLimit
		BEGIN
			UPDATE @object SET CashOnly = 1									
		END
    END
    
    SELECT TOP 1 * FROM @object    
    
END



GO
