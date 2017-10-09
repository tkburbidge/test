SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 27, 2016
-- Description:	Rentlytics Integration Delinquency Query
-- =============================================
CREATE PROCEDURE [dbo].[TSK_RENTLYTICS_GetDelinquencies]
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS

DECLARE @accountID bigint
DECLARE @i int = 1
DECLARE @startDate date
DECLARE @endDate date
DECLARE @objectTypes StringCollection
DECLARE @leaseStatuses StringCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Delinquencies (
		property_code nvarchar(250) null,
		unit_code nvarchar(250) null,
		resident_code uniqueidentifier null,
		resident_name nvarchar(100) null,
		resident_status nvarchar(100) null,
		thirty_day_delinquency money null,
		sixty_day_delinquency money null,
		ninety_day_delinquency money null,
		ninety_plus_day_delinquency money null,
		total_delinquent money null,
		prepays money null,
		UnitLeaseGroupID uniqueidentifier null)

	CREATE TABLE #AllObjectIDs4Property (
		PropertyID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		UnitID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		Balance money null)

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier null)

	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,		
		OccupiedUnitLeaseGroupID uniqueidentifier, 
		OccupiedLastLeaseID uniqueidentifier,
		OccupiedMoveInDate date,
		OccupiedNTVDate date,
		OccupiedMoveOutDate date,
		OccupiedIsMovedOut bit,
		PendingUnitLeaseGroupID uniqueidentifier,
		PendingLeaseID uniqueidentifier,
		PendingApplicationDate date,
		PendingMoveInDate date)

	CREATE TABLE #MyAgedReceivables (	
		ReportDate date NOT NULL,
		Name nvarchar(50) NULL,	
		PropertyID uniqueidentifier NOT NULL,
		Number nvarchar(50) NULL,
		PaddedNumber nvarchar(50) NULL,
		ObjectID uniqueidentifier NOT NULL,
		ObjectType nvarchar(25) NOT NULL,		
		LeaseID uniqueidentifier NULL,
		Names nvarchar(100) NULL,
		TransactionID uniqueidentifier NULL,
		PaymentID uniqueidentifier NULL,
		TransactionType nvarchar(50) NOT NULL,
		TransactionDate datetime NOT NULL,
		LedgerItemType nvarchar(50) NULL,
		Total money NULL,		
		PrepaymentsCredits money NULL,
		Reason nvarchar(500) NULL)
		
	INSERT #PropertyIDs
		SELECT Value FROM @propertyIDs

	SET @accountID = (SELECT TOP 1 AccountID 
						  FROM Property
						  WHERE PropertyID IN (SELECT PropertyID FROM #PropertyIDs))

	-- Get Consolodated Numbers here for ObjectIDs, but maybe do that in a loop.

	WHILE (@i <= 4)
	BEGIN
		TRUNCATE TABLE #LeasesAndUnits

		IF (@i = 1)
		BEGIN
			SET @endDate = @date
			SET @startDate = DATEADD(DAY, -30, @date)
		END
		ELSE IF (@i = 2)
		BEGIN
			SET @endDate = DATEADD(DAY, -60, @date)
			SET @startDate = DATEADD(DAY, -31, @date)
		END
		ELSE IF (@i = 3)
		BEGIN
			SET @endDate = DATEADD(DAY, -90, @date)
			SET @startDate = DATEADD(DAY, -61, @date)
		END
		ELSE IF (@i = 4)
		BEGIN
			SET @endDate = DATEADD(DAY, -91, @date)
			SET @startDate = null
		END

		INSERT #LeasesAndUnits
			EXEC [GetConsolodatedOccupancyNumbers] @accountID, @endDate, null, @propertyIDs

		INSERT #AllObjectIDs4Property
			SELECT PropertyID, OccupiedUnitLeaseGroupID, UnitID, OccupiedLastLeaseID, null
				FROM #LeasesAndUnits
				WHERE OccupiedUnitLeaseGroupID NOT IN (SELECT UnitLeaseGroupID FROM #AllObjectIDs4Property)

		UPDATE #allObs4Prop SET Balance = [ObjectBalance].[Balance]
			FROM #AllObjectIDs4Property #allObs4Prop
				CROSS APPLY GetObjectBalance(@startDate, @endDate, #allObs4Prop.UnitLeaseGroupID, 0, @propertyIDs) [ObjectBalance]

		INSERT #Delinquencies
			SELECT	p.Abbreviation,
					u.Number,
					null,
					null,
					null,
					null,
					null,
					null,
					null,
					null,
					null,
					#allObs4Prop.UnitLeaseGroupID
				FROM #AllObjectIDs4Property #allObs4Prop
					INNER JOIN Property p ON #allObs4Prop.PropertyID = p.PropertyID
					INNER JOIN Unit u ON #allObs4Prop.UnitID = u.UnitID
				WHERE #allObs4Prop.UnitLeaseGroupID NOT IN (SELECT DISTINCT UnitLeaseGroupID FROM #Delinquencies)
				  AND #allObs4Prop.Balance > 0.00

		IF (@i = 1)
		BEGIN
			UPDATE #Delinquencies SET thirty_day_delinquency = (SELECT Balance 
																	FROM #AllObjectIDs4Property
																	WHERE UnitLeaseGroupID = #Delinquencies.UnitLeaseGroupID)
		END
		ELSE IF (@i = 2)
		BEGIN
			UPDATE #Delinquencies SET sixty_day_delinquency = (SELECT Balance 
																	FROM #AllObjectIDs4Property
																	WHERE UnitLeaseGroupID = #Delinquencies.UnitLeaseGroupID)		
		END 
		ELSE IF (@i = 3)
		BEGIN
			UPDATE #Delinquencies SET ninety_day_delinquency = (SELECT Balance 
																	FROM #AllObjectIDs4Property
																	WHERE UnitLeaseGroupID = #Delinquencies.UnitLeaseGroupID)		
		END 
		ELSE IF (@i = 4)
		BEGIN
			UPDATE #Delinquencies SET ninety_plus_day_delinquency = (SELECT Balance 
																		 FROM #AllObjectIDs4Property
																		 WHERE UnitLeaseGroupID = #Delinquencies.UnitLeaseGroupID)		
		END 

		UPDATE #AllObjectIDs4Property SET Balance = 0.00
		
		SET @i = @i + 1
	END
	
	UPDATE #Delinquencies SET total_delinquent = ISNULL(thirty_day_delinquency, 0.00) + ISNULL(sixty_day_delinquency, 0.00)
												+ ISNULL(ninety_day_delinquency, 0.00) + ISNULL(ninety_plus_day_delinquency, 0.00)

	UPDATE #del	SET resident_status = l.LeaseStatus
		FROM #Delinquencies #del
			INNER JOIN #AllObjectIDs4Property #allObs4Prop ON #del.UnitLeaseGroupID = #allObs4Prop.UnitLeaseGroupID
			INNER JOIN Lease l ON #allObs4Prop.LeaseID = l.LeaseID

	INSERT #MyAgedReceivables
		EXEC RPT_TNS_AgedReceivables @date,	@propertyIDs, @objectTypes,	@leaseStatuses

	INSERT #Delinquencies
		SELECT	p.Abbreviation,
				u.Number,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				#myAged.ObjectID
			FROM #MyAgedReceivables #myAged
				INNER JOIN #AllObjectIDs4Property #allObs4Prop ON #myAged.ObjectID = #allObs4Prop.UnitLeaseGroupID
				INNER JOIN Property p ON #allObs4Prop.PropertyID = p.PropertyID
				INNER JOIN Unit u ON #allObs4Prop.UnitID = u.UnitID
			WHERE ObjectID NOT IN (SELECT DISTINCT UnitLeaseGroupID FROM #Delinquencies)
			  AND ISNULL(#myAged.PrepaymentsCredits, 0.00) > 0.00

	UPDATE #del	SET prepays = ISNULL(#myAged.PrepaymentsCredits, 0.00)
		FROM #Delinquencies #del
			INNER JOIN #MyAgedReceivables #myAged ON #del.UnitLeaseGroupID = #myAged.ObjectID

	UPDATE #del SET resident_code = pl.PersonID, resident_status = pl.ResidencyStatus
		FROM #Delinquencies #del
			INNER JOIN #LeasesAndUnits #lau ON #del.UnitLeaseGroupID = #lau.OccupiedUnitLeaseGroupID
			INNER JOIN PersonLease pl ON #lau.OccupiedLastLeaseID = pl.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																										   FROM PersonLease 
																										   WHERE LeaseID = #lau.OccupiedLastLeaseID
																										   ORDER BY OrderBy)

	UPDATE #del SET resident_code = pl.PersonID, resident_status = pl.ResidencyStatus
		FROM #Delinquencies #del
			INNER JOIN Lease l On #del.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseID = (SELECT TOP 1 LeaseID
																								  FROM Lease
																								  WHERE UnitLeaseGroupID = #del.UnitLeaseGroupID
																								  ORDER BY LeaseStartDate DESC)
			INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																							FROM PersonLease 
																							WHERE LeaseID = l.LeaseID
																							ORDER BY OrderBy)
		WHERE resident_code IS NULL

	UPDATE #Delinquencies SET resident_name = (SELECT PreferredName + ' ' + LastName
												   FROM Person 
												   WHERE PersonID = #Delinquencies.resident_code)

	SELECT	DISTINCT
			#del.property_code,
			#del.unit_code,
			#del.resident_code,
			per.PreferredName + ' ' + per.LastName AS 'resident_name',
			pl.ResidencyStatus AS 'resident_status',
			ISNULL(#del.thirty_day_delinquency, 0.00) AS 'thirty_day_delinquency',
			ISNULL(#del.sixty_day_delinquency, 0.00) AS 'sixty_day_delinquency',
			ISNULL(#del.ninety_day_delinquency, 0.00) AS 'ninety_day_deliquency',
			ISNULL(#del.ninety_plus_day_delinquency, 0.00) AS 'ninety_day_plus_delinquency',
			ISNULL(#del.total_delinquent, 0.00) AS 'total_delinquent',
			ISNULL(#del.prepays, 0.00) AS 'prepays'
		FROM #Delinquencies #del
			INNER JOIN #MyAgedReceivables #myAgedRec ON #del.UnitLeaseGroupID = #myAgedRec.ObjectID
			INNER JOIN #AllObjectIDs4Property #allObs4Prop ON #del.UnitLeaseGroupID = #allObs4Prop.UnitLeaseGroupID
			INNER JOIN PersonLease pl ON #allObs4Prop.LeaseID = pl.LeaseID
			INNER JOIN Person per ON pl.PersonID = per.PersonID
		WHERE #del.total_delinquent > 0.0 
		   OR #del.prepays > 0.0
		ORDER BY #del.property_code, #del.unit_code, 'resident_name'

END
GO
