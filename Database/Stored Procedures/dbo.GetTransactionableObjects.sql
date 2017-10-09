SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetTransactionableObjects]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier,
	@term varchar(100)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    DECLARE @nsfCashOnlyLimit int
    DECLARE @nsfCashOnlyMonths int
    DECLARE @startDate date
    
    SELECT @nsfCashOnlyLimit = NSFCashOnlyLimit, @nsfCashOnlyMonths = NSFCashOnlyMonths FROM Property WHERE PropertyID = @propertyID AND AccountID = @accountID    
    SET @startDate = DATEADD(month, -@nsfCashOnlyMonths, GETDATE())   
    
	SELECT ObjectID, UnitID, PersonID, ObjectName, TransactionTypeGroup, UnitNumber, LeaseStatus, CashOnly, OrderBy, AllowPayments, HAPWOITAccountID
	FROM
		(SELECT * FROM 
			(SELECT UnitLeaseGroups.UnitLeaseGroupID AS ObjectID,
				   UnitLeaseGroups.PaddedNumber,		   		     
				  -- Get a contatonated list of the transactionable
				  -- residents on the lease
				  UnitLeaseGroups.PersonID,
				  UnitLeaseGroups.Number + ' - ' + UnitLeaseGroups.PersonName + (CASE WHEN UnitLeaseGroups.LeaseStatus IN ('Current') THEN '' ELSE ' - (' + UnitLeaseGroups.LeaseStatus + ')' END) AS ObjectName,
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
					UnitLeaseGroups.UnitID,
					UnitLeaseGroups.Number AS 'UnitNumber',
					UnitLeaseGroups.LeaseStatus,
					'Lease' AS TransactionTypeGroup,
					UnitLeaseGroups.OrderBy AS 'OrderBy',					
					(CASE WHEN (((SELECT COUNT(DISTINCT p.PaymentID) 
								FROM Payment p
								--INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
								--INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
								LEFT JOIN PersonNote pn ON p.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
								WHERE p.[Date] >= @startDate
									AND p.[Type] = 'NSF'
									AND pn.PersonNoteID IS NULL
									AND p.ObjectID = UnitLeaseGroups.UnitLeaseGroupID) +
								(ISNULL((SELECT ulg1.ImportNSFCount FROM UnitLeaseGroup ulg1 WHERE ulg1.UnitLeaseGroupID = UnitLeaseGroups.UnitLeaseGroupID
											AND ulg1.NSFImportDate >= @startDate), 0))  >= @nsfCashOnlyLimit)) OR UnitLeaseGroups.CashOnlyOverride = 1 THEN CAST(1 AS BIT)
						  ELSE CAST(0 AS BIT)
					END) AS 'CashOnly',
					(CASE WHEN UnitLeaseGroups.DoNotAllowUnderEvictionPayments = 1 AND UnitLeaseGroups.LeaseStatus = 'Under Eviction' THEN CAST(0 AS BIT)
					      ELSE CAST(1 AS BIT)
					 END) AS 'AllowPayments',
					UnitLeaseGroups.HAPWOITAccountID
			FROM   (SELECT UnitLeaseGroup.UnitLeaseGroupID, Person.PersonID, Lease.LeaseID, Lease.LeaseStatus, Unit.UnitID, Unit.Number, Unit.PaddedNumber, Lease.OrderBy, UnitLeaseGroup.CashOnlyOverride,
						   CASE WHEN (Person.LastName IS NULL OR Person.LastName = '') THEN Person.PreferredName ELSE Person.PreferredName + ' ' + Person.LastName END AS 'PersonName', Property.DoNotAllowUnderEvictionPayments, WOITAccount.WOITAccountID as 'HAPWOITAccountID'
					FROM UnitLeaseGroup	
					CROSS APPLY (SELECT TOP 1 * FROM Lease  
								 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
								 WHERE Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID			     		 
								 ORDER BY Ordering.OrderBy) AS Lease
					INNER JOIN Unit ON UnitLeaseGroup.UnitID = Unit.UnitID 	
					INNER JOIN Building ON Unit.BuildingID = Building.BuildingID
					INNER JOIN Property ON Building.PropertyID = Property.PropertyID
					INNER JOIN PersonLease ON Lease.LeaseID = PersonLease.LeaseID AND PersonLease.MainContact = 1
					INNER JOIN Person ON PersonLease.PersonID = Person.PersonID
					LEFT JOIN WOITAccount ON Lease.UnitLeaseGroupID = WOITAccount.BillingAccountID
					WHERE UnitLeaseGroup.AccountID = @accountID
						  AND Property.PropertyID = @propertyID) AS UnitLeaseGroups) as Residents		
		WHERE Residents.ObjectName LIKE '%' + @term + '%'				
		
		UNION
		
		SELECT Person.PersonID AS ObjectID, 
			   -- Needed for UNION operator
			   '' AS PaddedNumber,
			   Person.PersonID AS PersonID,
			  (Person.PreferredName + ' ' + Person.LastName) AS ObjectName, 
			   NULL AS UnitID,
			   NULL AS 'UnitNumber',
			   NULL AS 'LeaseStatus',
			   PersonType.[Type] AS TransactionTypeGroup,
			   0 AS 'OrderBy',
		   		(CASE WHEN ((SELECT COUNT(DISTINCT p.PaymentID) 
								FROM Payment p
								--INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
								--INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID								
								WHERE p.[Date] >= @startDate
									AND p.[Type] = 'NSF'
									AND p.ObjectID = Person.PersonID) >= @nsfCashOnlyLimit) THEN CAST(1 AS BIT)
						  ELSE CAST(0 AS BIT)
					END) AS 'CashOnly',
				CAST(1 AS BIT) AS 'AllowPayments',
				NULL as 'HAPWOITAccountID'
		FROM Person
		INNER JOIN PersonType  ON PersonType.PersonID = Person.PersonID
		INNER JOIN PersonTypeProperty  ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID	
		WHERE Person.AccountID = @accountID
			  -- Limit the accounts retrieved only to the indicated property
			  AND PersonTypeProperty.PropertyID = @propertyID
			  AND Person.IsTransactionable = 1
			  -- Only select people of either Non-Resident Account or Prospect types
			  AND (PersonType.[Type] = 'Non-Resident Account' OR PersonType.[Type] = 'Prospect') 
			  -- Don't include people that are associated with a lease as those were
			  -- included above
			  AND NOT EXISTS (SELECT PersonID 
			  				  FROM PersonLease 
							  WHERE PersonLease.PersonID = Person.PersonID)
			  -- Where their name contains the search term
			  AND (((Person.PreferredName + ' ' + Person.LastName) LIKE '%' + @term + '%') OR ((Person.LastName IS NULL OR Person.LastName = '') AND Person.PreferredName LIKE '%' + @term + '%'))
			  
		UNION
		
		SELECT WOITAccount.WOITAccountID AS ObjectID,
			   -- Neded for UNION operator
			   '' AS PaddedNumber,
			   NULL AS PersonID,
			   WOITAccount.Name AS ObjectName,
			   NULL AS UnitID,
			   NULL AS 'UnitNumber',
			   NULL AS 'LeaseStatus',
			   'WOIT Account' AS TransactionTypeGroup,
			   0 AS 'OrderBy',
			 (CASE WHEN ((SELECT COUNT(DISTINCT p.PaymentID) 
								FROM Payment p
								--INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
								--INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
								WHERE p.[Date] >= @startDate
									AND p.[Type] = 'NSF'
									AND p.ObjectID = WOITAccount.WOITAccountID) >= @nsfCashOnlyLimit) THEN CAST(1 AS BIT)
						  ELSE CAST(0 AS BIT)
					END) AS 'CashOnly'	,
				CAST(1 AS BIT) AS 'AllowPayments'	,
				NULL as 'HAPWOITAccountID'			
		FROM WOITAccount
		WHERE WOITAccount.AccountID = @accountID 
			  AND WOITAccount.IsTransactionable = 1 
			  AND WOITAccount.PropertyID = @propertyID
			  AND WOITAccount.BillingAccountID IS NULL
			  AND WOITAccount.Name LIKE '%' + @term + '%') Accounts2
	ORDER BY TransactionTypeGroup, OrderBy, PaddedNumber, ObjectName
END
GO
