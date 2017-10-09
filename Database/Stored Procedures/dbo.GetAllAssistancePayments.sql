SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetAllAssistancePayments]
-- Add the parameters for the stored procedure here
	@accountID bigint,
	@affordableSubmissionID uniqueidentifier,
	@complete bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @voucherStatus nvarchar(20),
			@voucherMonth datetime,
			@affordableProgramAllocationID uniqueidentifier

	-- Abbreviation Dictionary
	DECLARE @AR nvarchar(15) = 'Recertification',
			@IR nvarchar(7) = 'Interim',
			@IC nvarchar(7) = 'Initial',
			@MI nvarchar(7) = 'Move-in',
			@MO nvarchar(8) = 'Move-out',
			@TM nvarchar(11) = 'Termination',
			@GR nvarchar(25) = 'Gross Rent Change Interim',
			@UT nvarchar(16) = 'Transfer Interim'

	-- The table that we will be returning
	CREATE TABLE #CompleteAssistancePayments (CertificationID uniqueidentifier, UnitNumber nvarchar(50),
			HeadOfHouseholdFirstName nvarchar(50), HeadOfHouseholdMiddleName nvarchar(50), HeadOfHouseholdLastName nvarchar(50),
			Amount int, PaidAmount int, CertType nvarchar(30), IsCorrection bit, EffectiveDate datetime,
			-- Fields for HUD forms and MAT files
			NumBedrooms int, ContractRent int, UtilityAllowance int, GrossRent money,
			IncomeCode nvarchar(50), TurnoverCode nvarchar(50), TurnoverDate datetime, RecertDate datetime, 
			RecertReminderDate datetime, ChangeCode nvarchar(50), AffordableSubmissionID uniqueidentifier,
			AffordableSubmissionItemID uniqueidentifier)

	-- Before we go any further, can we just return the affordable submission items?  Has the voucher already been sent?
	SELECT @voucherStatus = [Status],
		   @voucherMonth = StartDate,
		   @affordableProgramAllocationID = AffordableProgramAllocationID
	FROM AffordableSubmission
	WHERE AccountID = @accountID
		  AND AffordableSubmissionID = @affordableSubmissionID

	IF @voucherStatus IN ('Sent', 'Corrections Needed', 'Success')
	BEGIN
		IF @complete = 0
		BEGIN
			INSERT INTO #CompleteAssistancePayments
				SELECT c.CertificationID AS 'CertificationID',
					   certAsi.UnitNumber AS 'UnitNumber',
					   certAsi.HeadOfHouseholdFirstName AS 'HeadOfHouseholdFirstName',
					   certAsi.HeadOfHouseholdMiddleName AS 'HeadOfHouseholdMiddleName',
					   certAsi.HeadOfHouseholdLastName AS 'HeadOfHouseholdLastName',
					   ISNULL(c.HUDAssistancePayment, 0) AS 'Amount',
					   asi.PaidAmount AS 'PaidAmount',
					   c.[Type] AS 'CertType',
					   c.IsCorrection AS 'IsCorrection',
					   c.EffectiveDate AS 'EffectiveDate',
					   -- All the rest of the fields are part of the complete set, we can just set them to NULL
					   -- no need to go the extra mile and get more data than we need
					   NULL AS 'NumBedrooms',
					   NULL AS 'ContractRent',
					   NULL AS 'UtilityAllowance',
					   NULL AS 'GrossRent',
					   NULL AS 'IncomeCode',
					   NULL AS 'TurnoverCode',
					   NULL AS 'TurnoverDate',
					   NULL AS 'RecertificationDate',
					   NULL AS 'RecertReminderDate',
					   NULL AS 'ChangeCode',
					   @affordableSubmissionID AS 'AffordableSubmissionID',
					   asi.AffordableSubmissionItemID AS 'AffordableSubmissionItemID'
				FROM AffordableSubmissionItem asi
				INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi.AffordableSubmissionID
				INNER JOIN Certification c ON c.CertificationID = asi.ObjectID
				-- Get the snapshot of the last full cert that was successful sent to HUD
				INNER JOIN AffordableSubmissionItem certAsi ON certAsi.AffordableSubmissionItemID = dbo.LastFullCertSubmissionItem(@accountID, c.CertificationID)
				WHERE asi.AccountID = @accountID
					  AND a.AffordableSubmissionID = @affordableSubmissionID
					  AND asi.ObjectType = 'AssistancePayment'
		END
		ELSE
		BEGIN
			INSERT INTO #CompleteAssistancePayments
				SELECT c.CertificationID AS 'CertificationID',
					   ISNULL(certAsi.UnitNumber, u.Number) AS 'UnitNumber',
					   ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName)  AS 'HeadOfHouseholdFirstName',
					   ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName) AS 'HeadOfHouseholdMiddleName',
					   ISNULL(certAsi.HeadOfHouseholdLastName, p.LastName) AS 'HeadOfHouseholdLastName',
					   ISNULL(c.HUDAssistancePayment, 0) AS 'Amount',
					   asi.PaidAmount AS 'PaidAmount',
					   c.[Type] AS 'CertType',
					   c.IsCorrection AS 'IsCorrection',
					   c.EffectiveDate AS 'EffectiveDate',
					   ut.Bedrooms AS 'NumBedrooms',
					   ISNULL(c.HUDGrossRent - c.UtilityAllowance, 0) AS 'ContractRent',
					   ISNULL(c.UtilityAllowance, 0) AS 'UtilityAllowance',
					   ISNULL(c.HUDGrossRent, 0) AS 'GrossRent',
					   -- Show the exception unless it's CV
					   CASE WHEN c.Section8LIException <> 'CV' THEN c.Section8LIException ELSE NULL END AS 'IncomeCode',
					   -- If there was an assistance payment for this unit lease group last month, make sure that it was for a cert
					   -- of a differen type with ulg3, ulg4 tests to see if it had no assistance payments whatsoever, if it had no assistance
					   -- payments whatsoever and it's a move-in or initial then we also want to do a turnover code
					   CASE WHEN ulg3.UnitLeaseGroupID IS NOT NULL OR ulg4.UnitLeaseGroupID IS NULL AND c.[Type] IN (@MI, @IC)
							THEN CASE c.[Type] WHEN @MI THEN 'I' WHEN @IC THEN 'C' WHEN @TM THEN 'T' WHEN @MO THEN 'O' ELSE NULL END
							ELSE NULL END AS 'TurnoverCode',
					   CASE WHEN ulg3.UnitLeaseGroupID IS NOT NULL OR ulg4.UnitLeaseGroupID IS NULL AND c.[Type] IN (@MI, @IC)
						    THEN CASE WHEN c.[Type] IN (@MI, @IC, @TM, @MO) THEN c.EffectiveDate ELSE NULL END
							ELSE NULL END AS 'TurnoverDate',
					   c.RecertificationDate,
					   (SELECT MIN(Date)
						FROM PersonNote
						WHERE AccountID = @accountID
							  AND ObjectID = c.CertificationID
							  AND [Description] IN ('120 Day Notice', '90 Day Notice', '60 Day Notice', '30 Day Notice')
						GROUP BY ObjectID) AS 'RecertReminderDate',
					   asi.ChangeCode AS 'ChangeCode',
					   @affordableSubmissionID AS 'AffordableSubmissionID',
					   asi.AffordableSubmissionItemID AS 'AffordableSubmissionItemID'
				FROM AffordableSubmissionItem asi
				INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi.AffordableSubmissionID
				INNER JOIN Certification c ON c.CertificationID = asi.ObjectID
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
				INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
				-- Get the snapshot of the last full cert that was successful sent to HUD
				LEFT OUTER JOIN AffordableSubmissionItem certAsi ON certAsi.AffordableSubmissionItemID = dbo.LastFullCertSubmissionItem(@accountID, c.CertificationID)
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID AND cp.HouseholdStatus = 'Head of Household'
				INNER JOIN Person p ON p.PersonID = cp.PersonID
				-- Check if there was a certification for this unit lease group chain from last month's voucher that was paid and was
				-- of a different type then the certification for this month
				LEFT OUTER JOIN UnitLeaseGroup ulg3 ON ulg3.UnitLeaseGroupID = (
					SELECT TOP 1 subUlg.UnitLeaseGroupID
					FROM UnitLeaseGroup subUlg
					INNER JOIN Certification subC ON subC.UnitLeaseGroupID = subUlg.UnitLeaseGroupID
					INNER JOIN AffordableSubmissionItem subAsi ON subAsi.ObjectID = subC.CertificationID
					INNER JOIN AffordableSubmission subA ON subA.AffordableSubmissionID = subAsi.AffordableSubmissionID
					WHERE ISNULL(subUlg.TransferGroupID, subUlg.UnitLeaseGroupID) = ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID)
						  AND subC.[Type] <> c.[Type]
						  AND subA.AffordableProgramAllocationID = @affordableProgramAllocationID
						  AND subA.StartDate = DATEADD(M, -1, @voucherMonth)
						  AND subA.PaidAmount IS NOT NULL)
				-- Were there no paid assistance payments for this unit lease group last month?
				LEFT OUTER JOIN UnitLeaseGroup ulg4 ON ulg4.UnitLeaseGroupID = (
					SELECT TOP 1 subUlg.UnitLeaseGroupID
					FROM UnitLeaseGroup subUlg
					INNER JOIN Certification subC ON subC.UnitLeaseGroupID = subUlg.UnitLeaseGroupID
					INNER JOIN AffordableSubmissionItem subAsi ON subAsi.ObjectID = subC.CertificationID
					INNER JOIN AffordableSubmission subA ON subA.AffordableSubmissionID = subAsi.AffordableSubmissionID
					WHERE ISNULL(subUlg.TransferGroupID, subUlg.UnitLeaseGroupID) = ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID)
						  AND subA.AffordableProgramAllocationID = @affordableProgramAllocationID
						  AND subA.StartDate = DATEADD(M, -1, @voucherMonth)
						  AND subA.PaidAmount IS NOT NULL)
				WHERE asi.AccountID = @accountID
					  AND a.AffordableSubmissionID = @affordableSubmissionID
					  AND asi.ObjectType = 'AssistancePayment'

		END
	END

	ELSE
	BEGIN
		CREATE TABLE #AllCertifications (CertificationID uniqueidentifier, UnitLeaseGroupID uniqueidentifier, TransferGroupID uniqueidentifier, EffectiveDate datetime)

		-- All certifications that could be assistance payments
		INSERT INTO #AllCertifications
			SELECT DISTINCT c.CertificationID,
				   -- One very important thing to consider here is that we're changing the effective date on our own
				   -- all certification table but the certification table now has the wrong effective date, so in the
				   -- rest of this stored procedure we can't just join in the certification table and use the effective
				   -- date because that could potentially be wrong since it hasn't had this rule applied to it yet
				   -- In the rest of this sproc you'll see that if we need more certification information we always join
				   -- to our own all certification table instead of the regular certification table, because we want
				   -- to make sure that we're always getting the updated effective date
				   c.UnitLeaseGroupID,
				   ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID),
				   CASE WHEN c.[Type] = @MO AND ah.DeathDate IS NOT NULL AND c.EffectiveDate > DATEADD(D, 14, ah.DeathDate)
					    THEN DATEADD(D, 14, ah.DeathDate)
						ELSE c.EffectiveDate END AS 'EffectiveDate'
			FROM AffordableSubmission a
			INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissionID = a.AffordableSubmissionID
			INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationAffordableProgramAllocationID = asi.ObjectID
			INNER JOIN AffordableProgramAllocation apa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
			INNER JOIN Certification c ON capa.CertificationID = c.CertificationID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
			INNER JOIN AffordableHousehold ah ON ah.ObjectID = c.UnitLeaseGroupID
			INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
			INNER JOIN PersonLease pl ON pl.PersonID = cp.PersonID AND pl.LeaseID = c.LeaseID
			INNER JOIN Person p ON p.PersonID = cp.PersonID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			WHERE (cp.PersonID = c.HeadOfHouseholdPersonID OR cp.HouseholdStatus = 'Head of Household')
					AND c.DateCompleted IS NOT NULL
					AND apa.AffordableProgramAllocationID = @affordableProgramAllocationID
					AND a.[Status] IN ('Sent', 'Success', 'Corrections Needed')
					AND a.HUDSubmissionType = 'Tenant'
					AND a.AccountID = @accountID
					AND asi.IsBaseline = 0

		/**** ------------------------------------------ Cut #1 - Corrections that Override ------------------------------------------ ****/
		-- Now we need to remove all original certifications that are either permanently ignored
		-- or are going to start being ignored from this voucher on
		DECLARE @CertificationsToPurge GuidCollection
		INSERT INTO @CertificationsToPurge
			SELECT CertificationID FROM #AllCertifications

		DELETE FROM #AllCertifications
		WHERE CertificationID NOT IN (
			SELECT * FROM dbo.RemoveIgnoredCertifications(@accountID, @CertificationsToPurge))

		/**** ------------------------------------------ Cut #2 - Same Day Certifications ------------------------------------------ ****/
		-- Now remove certifications that share effective dates with other certifications but were not sent as recently as other certifications
		-- If we have a GRC, an IR and an AR that all fall on 10/30/2016, then whichever one was sent to HUD most recently is the only certification
		-- that gets to stick around
		DELETE FROM #AllCertifications
		WHERE CertificationID IN (
			SELECT ubc.CertificationID
			FROM #AllCertifications ubc
			-- Get rid of this certification if it's not the certification that is the most recently sent to HUD
			-- Look at other certifications that are in the same unit lease group chain and are on the same effective date
			WHERE ubc.CertificationID <> (SELECT TOP 1 subUbc.CertificationID
										  FROM #AllCertifications subUbc
										  -- Now we have to do the next three joins to figure out when the certification was sent to HUD
										  INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = subUbc.CertificationID
										  INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = capa.CertificationAffordableProgramAllocationID
										  INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi.AffordableSubmissionID
										  -- Make sure the certifications we are comparing against our original are in the same chain and have the same effective date
										  WHERE subUbc.TransferGroupID = ubc.TransferGroupID
											    AND subUbc.EffectiveDate = ubc.EffectiveDate
												-- Because we're pulling from the Unbilled Certification table we don't need to include
												-- where statements for making sure that the submissions were successful or they weren't baseline
												-- submissions, etc... that's all been filtered out already
										  ORDER BY a.DateSubmitted DESC))

		/**** ------------------------------------------ Cut #3 - Anticipated Voucher Date ------------------------------------------ ****/
		-- Remove any certifications that don't belong in this voucher month
		DELETE FROM #AllCertifications
		WHERE CertificationID NOT IN (
			SELECT c.CertificationID
			FROM #AllCertifications c
			INNER JOIN Certification c2 ON c2.CertificationID = c.CertificationID
			INNER JOIN AffordableHousehold ah ON ah.ObjectID = c2.UnitLeaseGroupID
			WHERE dbo.FirstHUDMonthBillable(c.CertificationID, @accountID, 0) <= @voucherMonth)

		/**** ------------------------------------------ Split Certification Pool ------------------------------------------ ****/
		CREATE TABLE #UnitLeaseGroups (UnitLeaseGroupCounter int, CertificationID uniqueidentifier, [Primary] bit, ChangeCode nvarchar(2))
		CREATE TABLE #RemainingCerts (CertificationID uniqueidentifier, UnitLeaseGroupID uniqueidentifier)
		CREATE TABLE #UnitLeaseGroupIDs (UnitLeaseGroupID uniqueidentifier)
		CREATE TABLE #CertsForThisGroup (CertificationID uniqueidentifier)

		INSERT INTO #RemainingCerts SELECT CertificationID, UnitLeaseGroupID FROM #AllCertifications
		DECLARE @RemainingCertsCount int = 0,
				@UnitLeaseGroupCounter int = 1

		SELECT @RemainingCertsCount = COUNT(*) FROM #RemainingCerts

		WHILE @RemainingCertsCount > 0
		BEGIN
			DECLARE @currentTransferGroupID uniqueidentifier = NULL
			--Pick a cert that we haven't work with yet and get it's transfer group
			SELECT TOP 1 @currentTransferGroupID = ubc.TransferGroupID
			FROM #RemainingCerts rc
			INNER JOIN #AllCertifications ubc ON ubc.CertificationID = rc.CertificationID

			-- Out of our remaining certifications grab all of the certications that belong in the same unit lease group chain
			-- as the random certification that we selected at the start of this iteration
			INSERT INTO #UnitLeaseGroups
				SELECT @UnitLeaseGroupCounter, rc.CertificationID, NULL, NULL
				FROM #RemainingCerts rc
				INNER JOIN Certification c ON c.CertificationID = rc.CertificationID
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
				WHERE ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @currentTransferGroupID) OR ulg.UnitLeaseGroupID = @currentTransferGroupID)

			-- Now delete all of the certs from the remaining cert table that we just added to the unit lease group table
			--SELECT CertificationID FROM #UnitLeaseGroups WHERE UnitLeaseGroupCounter = @UnitLeaseGroupCounter
			DELETE FROM #RemainingCerts
			WHERE CertificationID IN (SELECT CertificationID FROM #UnitLeaseGroups WHERE UnitLeaseGroupCounter = @UnitLeaseGroupCounter)

			--Prepare for next iteration in loop
			SELECT @UnitLeaseGroupCounter = @UnitLeaseGroupCounter + 1
			SELECT @RemainingCertsCount = COUNT(*) FROM #RemainingCerts
		END
		TRUNCATE TABLE #RemainingCerts

		DECLARE @LastAdjustmentGroup int,
			    @AdjustmentGroupCounter int = 1,
				@FakeAdjustmentID int = 0
		SELECT @LastAdjustmentGroup = MAX(UnitLeaseGroupCounter) FROM #UnitLeaseGroups

		/**** ------------------------------------------ Cut #3 - Deadzones ------------------------------------------ ****/
		CREATE TABLE #Deadzones (Startdate datetime, EndDate datetime)
		CREATE TABLE #UntouchedDeadzoneCerts (CertificationID uniqueidentifier)

		WHILE @AdjustmentGroupCounter <= @LastAdjustmentGroup
		BEGIN

			DECLARE @RandomUnitLeaseGroupNumber uniqueidentifier = NULL,
				    @TransferGroupID uniqueidentifier = NULL
			SELECT @RandomUnitLeaseGroupNumber = c.UnitLeaseGroupID,
				   @TransferGroupID = ISNULL(ulg2.TransferGroupID, ulg2.UnitLeaseGroupID)
			FROM #UnitLeaseGroups ulg
			INNER JOIN Certification c ON c.CertificationID = ulg.CertificationID
			INNER JOIN UnitLeaseGroup ulg2 ON ulg2.UnitLeaseGroupID = c.UnitLeaseGroupID
			WHERE ulg.UnitLeaseGroupCounter = @AdjustmentGroupCounter

			INSERT INTO #UntouchedDeadzoneCerts
				SELECT c.CertificationID
				FROM Certification c
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
				INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
				INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = capa.CertificationAffordableProgramAllocationID
				INNER JOIN AffordableSubmission a ON asi.AffordableSubmissionID = a.AffordableSubmissionID
				WHERE ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @TransferGroupID) OR ulg.UnitLeaseGroupID = @TransferGroupID)
					  AND a.[Status] IN ('Sent', 'Corrections Needed', 'Success')

			WHILE (SELECT COUNT(*) FROM #UntouchedDeadzoneCerts) <> 0
			BEGIN
				DECLARE @ThisUntouchedCert uniqueidentifier = NULL,
						@ThisUntouchedCertType nvarchar(30) = NULL,
						@ThisUntouchedCertDate datetime = NULL
				SELECT TOP 1 @ThisUntouchedCert = udc.CertificationID,
							 @ThisUntouchedCertType = c.[Type],
							 @ThisUntouchedCertDate = c.EffectiveDate
				FROM #UntouchedDeadzoneCerts udc
				INNER JOIN Certification c ON c.CertificationID = udc.CertificationID
				ORDER BY c.EffectiveDate

				-- Move-out/terminations mark the start of our deadzone, if we find one then try to find the next move-in or initial
				-- so that we can mark the start and end of this deadzone
				IF @ThisUntouchedCertType IN (@MO, @TM)
				BEGIN
					-- We found an early move-out or termination, now we need to find the next chronologic move-in or initial
					DECLARE @NextMIIC uniqueidentifier = NULL
					SELECT TOP 1 @NextMIIC = udc.CertificationID
					FROM #UntouchedDeadzoneCerts udc
					INNER JOIN Certification c ON c.CertificationID = udc.CertificationID
					WHERE c.EffectiveDate > @ThisUntouchedCertDate
						  AND c.[Type] IN (@IC, @MI)
					ORDER BY c.EffectiveDate

					-- We couldn't find a move-in or initial after that move-out or termination,
					-- so this deadzone will continue until the year 3000 at which poverty will
					-- be completely eliminated so we won't need subsidized housing anymore
					IF @NextMIIC IS NULL
					BEGIN
						INSERT INTO #Deadzones
							SELECT @ThisUntouchedCertDate, '2999-12-31 00:00:00.000'
						-- We can go ahead and remove anything else from the queue to be looked at
						DELETE FROM #UntouchedDeadzoneCerts
					END
					-- There was a moove-in or initial after this move-out or termination, so the deadzone will be finite
					ELSE
					BEGIN
						INSERT INTO #Deadzones
							SELECT @ThisUntouchedCertDate, c.EffectiveDate
							FROM #UntouchedDeadzoneCerts udc
							INNER JOIN Certification c ON c.CertificationID = udc.CertificationID
							WHERE udc.CertificationID = @NextMIIC
						DELETE FROM #UntouchedDeadzoneCerts
						WHERE CertificationID = @NextMIIC
					END
				END
				DELETE FROM #UntouchedDeadzoneCerts
				WHERE CertificationID = @ThisUntouchedCert
			END

			-- Now we have the deadzones, so let's remove all the certifications that fall in deadzones
			DELETE FROM #UnitLeaseGroups
			WHERE CertificationID IN (
				SELECT ulg.CertificationID
				FROM #UnitLeaseGroups ulg
				INNER JOIN Certification c ON c.CertificationID = ulg.CertificationID
				INNER JOIN #Deadzones d ON c.EffectiveDate > d.Startdate AND c.EffectiveDate < d.EndDate
				WHERE ulg.UnitLeaseGroupCounter = @AdjustmentGroupCounter)

			-- This is the same thing as the lone termination stop on the adjustment sproc
			-- We're looking for any NS DS terminations where there is no billing history and there is no move-in or initial
			-- that starts on a different date in this new group, if either of those situations are not true then we can still
			-- keep the termination around, if both situations are true then there is no purpose in putting in a termination that reverses nothing
			-- there's going to be no adjustment for this termination, there should be no assistance payment, this termination will be completely
			-- absent in all billing
			DELETE FROM #UnitLeaseGroups
			WHERE CertificationID IN (
				SELECT c.CertificationID
			    FROM #UnitLeaseGroups ulgs
					-- Certifications from our list
					INNER JOIN Certification c ON c.CertificationID = ulgs.CertificationID
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
					-- All certifications in the unit lease group chain
					INNER JOIN UnitLeaseGroup ulg2 ON ISNULL(ulg2.TransferGroupID, ulg2.UnitLeaseGroupID) = ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID)
					INNER JOIN Certification c2 ON c2.UnitLeaseGroupID = ulg2.UnitLeaseGroupID
					LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationID = c2.CertificationID
					LEFT OUTER JOIN AffordableSubmissionItem asi ON asi.ObjectID IN (c2.CertificationID, ca.CertificationAdjustmentID)
					LEFT OUTER JOIN AffordableSubmission a ON asi.AffordableSubmissionID = a.AffordableSubmissionID AND a.PaidAmount IS NOT NULL
				WHERE ulgs.UnitLeaseGroupCounter = @AdjustmentGroupCounter
					  -- Make sure a single certification was never ever billed for this unit lease group chain
					  AND a.AffordableSubmissionID IS NULL
					  -- There should only be on certification in this group
					  AND (SELECT COUNT(*)
						   FROM #UnitLeaseGroups subUlgs
						   WHERE subUlgs.UnitLeaseGroupCounter = @AdjustmentGroupCounter) = 1
					  AND c.[Type] = @TM
					  AND c.TerminationReason IN ('Resident did not qualify', 'Double subsidy'))

			-- Now if the last cert is a move-out or termination and it's already had an assistance payment then we can remove it
			DECLARE @MoveOutToIgnore uniqueidentifier = NULL
			SELECT TOP 1 @MoveOutToIgnore = ulg.CertificationID
			FROM #UnitLeaseGroups ulg
			INNER JOIN Certification c ON c.CertificationID = ulg.CertificationID
			INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = c.CertificationID
			INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi.AffordableSubmissionID
			WHERE ulg.UnitLeaseGroupCounter = @AdjustmentGroupCounter
				  AND c.[Type] IN (@MO, @TM)
				  AND a.[Status] IN ('Corrections Needed', 'Success')
			ORDER BY c.EffectiveDate DESC, c.CreatedDate DESC, c.DateCompleted DESC

			IF @MoveOutToIgnore IS NOT NULL
			BEGIN
				DELETE FROM #UnitLeaseGroups
				WHERE UnitLeaseGroupCounter = @AdjustmentGroupCounter
			END

			-- Now find the most recent certification in each unit lease group chain and mark it as the primary
			-- We still need the secondary certifications to help us figure out the change code
			UPDATE #UnitLeaseGroups SET [Primary] = 1
			WHERE CertificationID IN (
				SELECT TOP 1 c.CertificationID
				FROM #UnitLeaseGroups ulgs
				INNER JOIN Certification c ON c.CertificationID = ulgs.CertificationID
				WHERE ulgs.UnitLeaseGroupCounter = @AdjustmentGroupCounter
				-- Should be the last effective date and if there are corrections then these other two orders should return the last correction in the chain
				ORDER BY c.EffectiveDate DESC, c.CreatedDate DESC, c.DateCompleted DESC)

			/**** ------------------------------------------ Figure out the Change Codes ------------------------------------------ ****/
			DECLARE @ChangeCode nvarchar(2) = NULL,
					@LastAPEffectiveDate datetime = NULL,
					@LastAPAmount int = NULL,
					@ThisVoucherAPAmount int = NULL

			-- First we need to know what was billed in last month's voucher for this unit lease group chain
			SELECT @LastAPAmount = c.HUDAssistancePayment,
				   @LastAPEffectiveDate = c.EffectiveDate
			FROM AffordableSubmission a
			INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissioniD = a.AffordableSubmissionID
			INNER JOIN Certification c ON c.CertificationID = asi.ObjectID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
			WHERE a.AffordableProgramAllocationID = @affordableProgramAllocationID
				  AND DATEADD(M, -1, @voucherMonth) = a.StartDate
				  AND ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID) = @TransferGroupID

			-- Now what is the amount of the assistance payment for this month going to be
			SELECT @ThisVoucherAPAmount = ISNULL(c.HUDAssistancePayment, 0)
			FROM #UnitLeaseGroups ulgs
			INNER JOIN Certification c ON c.CertificationID = ulgs.CertificationID
			WHERE ulgs.UnitLeaseGroupCounter = @AdjustmentGroupCounter
				  AND ulgs.[Primary] = 1

			-- If there isn't going to be a change in the assistance payment then we're not going to have a change code
			IF @ThisVoucherAPAmount <> @LastAPAmount
			BEGIN
				-- Now we're trying to get the first new certification
				SELECT TOP 1 @ChangeCode = CASE c.[Type] WHEN @IR THEN 'IR' WHEN @GR THEN 'GR' WHEN @AR THEN 'AR'
										   WHEN @UT THEN 'UT' WHEN @IC THEN 'IC' WHEN @MI THEN 'MI'
										   WHEN @TM THEN 'TM' END
				FROM #UnitLeaseGroups ulgs
				INNER JOIN Certification c ON c.CertificationID = ulgs.CertificationID
				WHERE ulgs.UnitLeaseGroupCounter = @AdjustmentGroupCounter
					  AND ISNULL(c.HUDAssistancePayment, 0) <> @LastAPAmount
					  AND c.[Type] IN (@MI, @IC, @AR, @IR, @UT, @GR, @TM)
					  AND c.EffectiveDate > @LastAPEffectiveDate
				-- Get the earliest cert
				ORDER BY c.EffectiveDate
			END

			UPDATE #UnitLeaseGroups SET ChangeCode = @ChangeCode
			WHERE UnitLeaseGroupCounter = @AdjustmentGroupCounter
				  AND [Primary] = 1

			SELECT @AdjustmentGroupCounter = @AdjustmentGroupCounter + 1
			TRUNCATE TABLE #UnitLeaseGroupIDs
			TRUNCATE TABLE #UntouchedDeadzoneCerts
			TRUNCATE TABLE #Deadzones

		END

		DELETE FROM #UnitLeaseGroups WHERE [Primary] IS NULL

		IF @complete = 0
		BEGIN
			INSERT #CompleteAssistancePayments
				SELECT c.CertificationID AS 'CertificationID',
					   ISNULL(certAsi.UnitNumber, u.Number) AS 'UnitNumber',
					   ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName)  AS 'HeadOfHouseholdFirstName',
					   ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName) AS 'HeadOfHouseholdMiddleName',
					   ISNULL(certAsi.HeadOfHouseholdLastName, p.LastName) AS 'HeadOfHouseholdLastName',
					   ISNULL(c2.HUDAssistancePayment, 0) AS 'Amount',
					   NULL AS 'PaidAmount',
					   c2.[Type] AS 'CertType',
					   c2.IsCorrection AS 'IsCorrection',
					   c.EffectiveDate AS 'EffectiveDate',
					   -- All the rest of the fields are part of the complete set, we can just set them to NULL
					   -- no need to go the extra mile and get more data than we need
					   NULL AS 'NumBedrooms',
					   NULL AS 'ContractRent',
					   NULL AS 'UtilityAllowance',
					   NULL AS 'GrossRent',
					   NULL AS 'IncomeCode',
					   NULL AS 'TurnoverCode',
					   NULL AS 'TurnoverDate',
					   NULL AS 'RecertificationDate',
					   NULL AS 'RecertReminderDate',
					   NULL AS 'ChangeCode',
					   @affordableSubmissionID AS 'AffordableSubmissionID',
					   NULL AS 'AffordableSubmissionItemID'
				FROM #AllCertifications c
				INNER JOIN Certification c2 ON c2.CertificationID = c.CertificationID
				-- Get the snapshot of the last full cert that was successful sent to HUD
				LEFT OUTER JOIN AffordableSubmissionItem certAsi ON certAsi.AffordableSubmissionItemID = dbo.LastFullCertSubmissionItem(@accountID, c.CertificationID)
				INNER JOIN UnitLeaseGroup ulg ON c2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID AND cp.HouseholdStatus = 'Head of Household'
				INNER JOIN Person p ON p.PersonID = cp.PersonID
				WHERE c.CertificationID IN (SELECT CertificationID FROM #UnitLeaseGroups WHERE [Primary] = 1)
		END
		ELSE
		BEGIN
			INSERT #CompleteAssistancePayments
				SELECT c.CertificationID AS 'CertificationID',
					   ISNULL(certAsi.UnitNumber, u.Number) AS 'UnitNumber',
					   ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName)  AS 'HeadOfHouseholdFirstName',
					   ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName) AS 'HeadOfHouseholdMiddleName',
					   ISNULL(certAsi.HeadOfHouseholdLastName, p.LastName) AS 'HeadOfHouseholdLastName',
					   ISNULL(c2.HUDAssistancePayment, 0) AS 'Amount',
					   NULL AS 'PaidAmount',
					   c2.[Type] AS 'CertType',
					   c2.IsCorrection AS 'IsCorrection',
					   c2.EffectiveDate AS 'EffectiveDate',
					   ut.Bedrooms AS 'NumBedrooms',
					   ISNULL(c2.HUDGrossRent - c2.UtilityAllowance, 0) AS 'ContractRent',
					   c2.UtilityAllowance AS 'UtilityAllowance',
					   ISNULL(c2.HUDGrossRent, 0) AS 'GrossRent',
					   -- Show the exception unless it's CV
					   CASE WHEN c2.Section8LIException <> 'CV' THEN c2.Section8LIException ELSE NULL END AS 'IncomeCode',
					   -- If there was an assistance payment for this unit lease group last month, make sure that it was for a cert
					   -- of a differen type with ulg3, ulg4 tests to see if it had no assistance payments whatsoever, if it had no assistance
					   -- payments whatsoever and it's a move-in or initial then we also want to do a turnover code
					   CASE WHEN ulg3.UnitLeaseGroupID IS NOT NULL OR ulg4.UnitLeaseGroupID IS NULL AND c2.[Type] IN (@MI, @IC)
							THEN CASE c2.[Type] WHEN @MI THEN 'I' WHEN @IC THEN 'C' WHEN @TM THEN 'T' WHEN @MO THEN 'O' ELSE NULL END
							ELSE NULL END AS 'TurnoverCode',
					   CASE WHEN ulg3.UnitLeaseGroupID IS NOT NULL OR ulg4.UnitLeaseGroupID IS NULL AND c2.[Type] IN (@MI, @IC)
						    THEN CASE WHEN c2.[Type] IN (@MI, @IC, @TM, @MO) THEN c.EffectiveDate ELSE NULL END
							ELSE NULL END AS 'TurnoverDate',
					   c2.RecertificationDate,
					   (SELECT MIN(Date)
						FROM PersonNote
						WHERE AccountID = @accountID
							  AND ObjectID = c.CertificationID
							  AND [Description] IN ('120 Day Notice', '90 Day Notice', '60 Day Notice', '30 Day Notice')
						GROUP BY ObjectID) AS 'RecertReminderDate',
					   ulgs.ChangeCode,
					   @affordableSubmissionID AS 'AffordableSubmissionID',
					   NULL AS 'AffordableSubmissionItemID'
				FROM #AllCertifications c
				INNER JOIN #UnitLeaseGroups ulgs ON ulgs.CertificationID = c.CertificationID
				INNER JOIN Certification c2 ON c2.CertificationID = c.CertificationID
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c2.UnitLeaseGroupID
				-- Get the snapshot of the last full cert that was successful sent to HUD
				LEFT OUTER JOIN AffordableSubmissionItem certAsi ON certAsi.AffordableSubmissionItemID = dbo.LastFullCertSubmissionItem(@accountID, c.CertificationID)
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID AND cp.HouseholdStatus = 'Head of Household'
				INNER JOIN Person p ON p.PersonID = cp.PersonID
				-- Check if there was a certification for this unit lease group chain from last month's voucher that was paid and was
				-- of a different type then the certification for this month
				LEFT OUTER JOIN UnitLeaseGroup ulg3 ON ulg3.UnitLeaseGroupID = (
					SELECT TOP 1 subUlg.UnitLeaseGroupID
					FROM UnitLeaseGroup subUlg
					INNER JOIN Certification subC ON subC.UnitLeaseGroupID = subUlg.UnitLeaseGroupID
					INNER JOIN AffordableSubmissionItem subAsi ON subAsi.ObjectID = subC.CertificationID
					INNER JOIN AffordableSubmission subA ON subA.AffordableSubmissionID = subAsi.AffordableSubmissionID
					WHERE ISNULL(subUlg.TransferGroupID, subUlg.UnitLeaseGroupID) = ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID)
						  AND subC.[Type] <> c2.[Type]
						  AND subA.AffordableProgramAllocationID = @affordableProgramAllocationID
						  AND subA.StartDate = DATEADD(M, -1, @voucherMonth)
						  AND subA.PaidAmount IS NOT NULL)
				-- Were there no paid assistance payments for this unit lease group last month?
				LEFT OUTER JOIN UnitLeaseGroup ulg4 ON ulg4.UnitLeaseGroupID = (
					SELECT TOP 1 subUlg.UnitLeaseGroupID
					FROM UnitLeaseGroup subUlg
					INNER JOIN Certification subC ON subC.UnitLeaseGroupID = subUlg.UnitLeaseGroupID
					INNER JOIN AffordableSubmissionItem subAsi ON subAsi.ObjectID = subC.CertificationID
					INNER JOIN AffordableSubmission subA ON subA.AffordableSubmissionID = subAsi.AffordableSubmissionID
					WHERE ISNULL(subUlg.TransferGroupID, subUlg.UnitLeaseGroupID) = ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID)
						  AND subA.AffordableProgramAllocationID = @affordableProgramAllocationID
						  AND subA.StartDate = DATEADD(M, -1, @voucherMonth)
						  AND subA.PaidAmount IS NOT NULL)


		END
	END

	-- Spit out the results
	SELECT * FROM #CompleteAssistancePayments
	ORDER BY UnitNumber

	/*
	DROP TABLE #AllCertifications
	DROP TABLE #CompleteAssistancePayments
	DROP TABLE #RemainingCerts
	DROP TABLE #UnitLeaseGroups
	DROP TABLE #Deadzones
	DROP TABLE #UntouchedDeadzoneCerts
	DROP TABLE #CertsForThisGroup
	DROP TABLE #UnitLeaseGroupIDs
	*/

END
GO
