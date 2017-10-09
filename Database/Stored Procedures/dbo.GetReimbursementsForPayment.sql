SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetReimbursementsForPayment] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @date DATE = GETDATE();

	CREATE TABLE #PropertyIDs (Value UNIQUEIDENTIFIER NOT NULL);
		
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	CREATE TABLE #TempUtilityReimbursement (
    [AccountID]               BIGINT           NOT NULL,
    [UtilityReimbursementID]  UNIQUEIDENTIFIER NOT NULL,
	[Date]					  DATETIME         NOT NULL,
	[UnitLeaseGroupID]		  UNIQUEIDENTIFIER NOT NULL,
	[Amount]				  MONEY			   NOT NULL,
	[ObjectID]				  UNIQUEIDENTIFIER NOT NULL,
	[ObjectType]			  VARCHAR(20)	   NOT NULL,
	[UnitNumber]			  VARCHAR(20)	   NOT NULL,
	[Residents]				  VARCHAR(MAX)	   NOT NULL,
	[PersonID]				  UNIQUEIDENTIFIER NOT NULL,
	[Address]				  VARCHAR(MAX)	   NULL,
	[AddressID]				  UNIQUEIDENTIFIER NULL,
	[PropertyID]			  UNIQUEIDENTIFIER NOT NULL,
	[PaymentID]				  UNIQUEIDENTIFIER NOT NULL);
	
	CREATE TABLE #PaidUtilityReimbursement (
    [AccountID]               BIGINT           NOT NULL,
    [UtilityReimbursementID]  UNIQUEIDENTIFIER NOT NULL,
	[Date]					  DATETIME         NOT NULL,
	[UnitLeaseGroupID]		  UNIQUEIDENTIFIER NOT NULL,
	[Amount]				  MONEY			   NOT NULL,
	[PaymentID]				  UNIQUEIDENTIFIER NOT NULL);

	INSERT INTO #PaidUtilityReimbursement 
	SELECT u.* FROM UtilityReimbursement u 
		JOIN Payment p on u.paymentID = p.paymentID 
		WHERE p.reversed = 0;

	CREATE TABLE #AllUnitLeaseGroups (unitLeaseGroupID UNIQUEIDENTIFIER)
	INSERT INTO #AllUnitLeaseGroups 
	SELECT DISTINCT c.UnitLeaseGroupID FROM Certification c
		JOIN CertificationAffordableProgramAllocation capa on c.CertificationID = capa.CertificationID
		JOIN AffordableProgramAllocation apa on capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
		JOIN AffordableProgram ap on apa.AffordableProgramID = ap.AffordableProgramID
	JOIN PersonLease ON c.LeaseID = PersonLease.LeaseID
        JOIN PersonType ON PersonLease.PersonID = PersonType.PersonID
    WHERE c.DateCompleted IS NOT NULL AND ap.IsHUD = 1 AND c.EffectiveDate < @date AND ap.PropertyID IN (SELECT Value FROM #PropertyIDs) 
    AND ap.AccountID = @accountID AND PersonType.[Type] = 'Resident' AND PersonLease.MainContact = 1;    												

    
	CREATE TABLE #UnitLeaseGroupIDChains (
	UnitLeaseGroupID UNIQUEIDENTIFIER NOT NULL,
	UnitLeaseGroupGroupCounter INT NOT NULL);
	
	DECLARE @remainingULGCount INT = (SELECT COUNT(*) FROM #AllUnitLeaseGroups);
	DECLARE @ULGGroup INT = 1;

	WHILE @remainingULGCount > 0
	BEGIN 
	
		DECLARE @unitLeaseGroupID UNIQUEIDENTIFIER = (SELECT TOP 1 * FROM #AllUnitLeaseGroups);
		
		INSERT INTO #UnitLeaseGroupIDChains VALUES(@unitLeaseGroupID, @ULGGroup);

		INSERT INTO #UnitLeaseGroupIDChains SELECT UnitLeaseGroupID, @ULGGroup FROM UnitLeaseGroup WHERE  UnitLeaseGroupID <> @unitLeaseGroupID AND TransferGroupID IS NOT NULL AND TransferGroupID = (SELECT TransferGroupID FROM UnitLeaseGroup WHERE UnitLeaseGroupID = @unitLeaseGroupID)

		DELETE FROM #AllUnitLeaseGroups WHERE unitLeaseGroupID IN (SELECT UnitLeaseGroupID FROM #UnitLeaseGroupIDChains);
		
		SET @remainingULGCount = (SELECT COUNT(*) FROM #AllUnitLeaseGroups);
		SET @ULGGroup = @ULGGroup + 1;
	END
    
	CREATE TABLE #Certifications (
	CertificationID UNIQUEIDENTIFIER NULL, 
	UnitLeaseGroupGroupCounter INT NOT NULL
	)
	
	CREATE TABLE #CertificationsInMonth (
	CertificationID UNIQUEIDENTIFIER NULL, 
	HUDUtilityReimbursement MONEY NULL, 
	EffectiveDate DATE NULL, 
	CreatedDate DATE NULL
	)

	DECLARE @currentULGGroup INT = 1
	DECLARE @certID UNIQUEIDENTIFIER
	DECLARE @certID2 UNIQUEIDENTIFIER
	DECLARE @curDate DATE = dbo.firstofmonth(@date)
	DECLARE @beginDate DATE

	WHILE @currentULGGroup < @ULGGroup
	BEGIN
		SET @curDate = dbo.firstofmonth(@date)
		SET @certID = (SELECT TOP 1 c.CertificationGroupID
						FROM Certification c
							JOIN #UnitLeaseGroupIDChains ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
							JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
							JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID AND ap.IsHUD = 1
						WHERE c.AccountID = @accountID
							AND ulg.UnitLeaseGroupGroupCounter = @currentULGGroup
							AND c.EffectiveDate <= @date
							AND c.DateCompleted IS NOT NULL
						ORDER BY c.EffectiveDate DESC)
		
		SET @beginDate = (SELECT InitialEffectiveDate FROM CertificationGroup WHERE CertificationGroupID = @certID)
        
		IF (@beginDate < '2017-8-1')
		BEGIN
			SET @beginDate = '2017-8-1'
		END

		WHILE @beginDate <= @curDate
		BEGIN
			IF (SELECT COUNT(*) FROM #PaidUtilityReimbursement WHERE [Date] = @curDate AND UnitLeaseGroupID in (SELECT UnitLeaseGroupID FROM #UnitLeaseGroupIDChains WHERE UnitLeaseGroupGroupCounter = @currentULGGroup)) = 0
			BEGIN
			
			SET @certID = (SELECT TOP 1 c.CertificationID
							FROM Certification c
								JOIN #UnitLeaseGroupIDChains ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
								JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
								JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID AND ap.IsHUD = 1
							WHERE c.AccountID = @accountID
								AND ulg.UnitLeaseGroupGroupCounter = @currentULGGroup
								AND c.EffectiveDate <= @curDate
								AND c.DateCompleted IS NOT NULL
							ORDER BY c.EffectiveDate DESC)
			
			TRUNCATE TABLE #CertificationsInMonth

			INSERT INTO #CertificationsInMonth 
				SELECT CertificationID, HUDUtilityReimbursement, EffectiveDate, CreatedDate 
				FROM Certification 
				WHERE UnitLeaseGroupID IN (SELECT UnitLeaseGroupID FROM #UnitLeaseGroupIDChains WHERE UnitLeaseGroupGroupCounter = @currentULGGroup) AND 
					DateCompleted IS NOT NULL AND 
					EffectiveDate > @curdate AND
					EffectiveDate <= EOMONTH(@curDate) 
				ORDER BY EffectiveDate, CreatedDate DESC;

				DECLARE @amount MONEY = 0;

			IF (SELECT COUNT(*) FROM #CertificationsInMonth) = 0
			BEGIN
				SET @amount = (SELECT HUDUtilityReimbursement FROM Certification WHERE @certID = CertificationID);
			END
			ELSE 
			BEGIN
				DECLARE @prevStart INT =  1 + DAY(EOMONTH(@curDate));
				DECLARE @daysInMonth INT = DAY(EOMONTH(@curDate))

				WHILE (SELECT COUNT(*) FROM #CertificationsInMonth) > 0
				BEGIN
					SET @certID2 = (SELECT TOP 1 CertificationID FROM #CertificationsInMonth ORDER BY EffectiveDate DESC, CreatedDate DESC)
					SET @amount = @amount + (SELECT HUDUtilityReimbursement FROM #CertificationsInMonth WHERE CertificationID = @certID2) * (@prevStart - (SELECT DAY(EffectiveDate) FROM #CertificationsInMonth WHERE CertificationID = @certID2)) / @daysInMonth
					SET @prevStart = (SELECT DAY(EffectiveDate) FROM #CertificationsInMonth WHERE CertificationID = @certID2)
					DELETE FROM #CertificationsInMonth WHERE CertificationID = @certID2
				END
					SET @amount = @amount + (SELECT HUDUtilityReimbursement FROM Certification WHERE @certID = CertificationID) * (@prevStart - 1) / @daysInMonth
			END

				INSERT INTO #TempUtilityReimbursement SELECT 
				c.AccountID,
				NEWID(), 
				@curDate,
				c.UnitLeaseGroupID,
				@amount,
				c.CertificationID,
				'Certification',
				u.Number,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = c.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1				   
						 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
				(SELECT TOP 1 Person.PersonID
					FROM Person
					INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					WHERE PersonLease.LeaseID = c.LeaseID
						AND PersonType.[Type] = 'Resident'				   
						AND PersonLease.MainContact = 1) AS 'PersonID',
				(SELECT TOP 1 adder.StreetAddress + char(13) + adder.City + ', ' + adder.[State] + ' ' + adder.Zip + char(13) + ISNULL(adder.Country, 'USA') + char(13)
					FROM [Address] adder
						INNER JOIN PersonLease plAdder ON adder.ObjectID = plAdder.PersonID AND adder.AddressType = 'MailingAddress'
											AND plAdder.MainContact = 1 AND plAdder.LeaseID = c.LeaseID) AS 'Address',
				(SELECT TOP 1 adder.AddressID
					FROM [Address] adder
						INNER JOIN PersonLease plAdder ON adder.ObjectID = plAdder.PersonID AND adder.AddressType = 'MailingAddress'
											AND plAdder.MainContact = 1 AND plAdder.LeaseID = c.LeaseID) AS 'AddressID',
				b.PropertyID,
				NEWID()
				FROM Certification c 
					INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					JOIN Unit u ON ulg.UnitID = u.UnitID
					JOIN CertificationPerson cp ON c.CertificationID = cp.CertificationID
					JOIN Building b ON u.BuildingID = b.BuildingID
				WHERE c.CertificationID = @certID AND @amount <> 0
			END
			SET @curDate = DATEADD(MONTH, -1, @curDate)
		END
		SET @currentULGGroup = @currentULGGroup + 1
	END

	SELECT * FROM #TempUtilityReimbursement

END
GO
