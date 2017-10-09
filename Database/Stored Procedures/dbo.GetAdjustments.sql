SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetAdjustments] 
-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@affordableSubmissionID uniqueidentifier,
	@sending bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	/**** ------------------------------------------ Strings ------------------------------------------ ****/
	-- This sproc is so long that it's easier to manage the strings like this, it 
	-- also makes the rest of the sproc shorter and a little easier to understand
	-- Cert Types
	DECLARE @AR nvarchar(15) = 'Recertification',
			@IR nvarchar(7) = 'Interim',
			@IC nvarchar(7) = 'Initial',
			@MI nvarchar(7) = 'Move-in',
			@MO nvarchar(8) = 'Move-out',
			@TM nvarchar(11) = 'Termination',
			@GR nvarchar(25) = 'Gross Rent Change Interim',
			@UT nvarchar(16) = 'Transfer Interim',
	-- Submission Statuses
			@Sent nvarchar(4) = 'Sent',
			@Success nvarchar(7) = 'Success',
			@CorrectionsNeeded nvarchar(18) = 'Corrections Needed',
	-- Subsidy Types
			@RAP nvarchar(3) = 'RAP',
			@RentSupplement nvarchar(15) = 'Rent Supplement',
	-- Affordable Submission Item Object Types
			@Certification nvarchar(13) = 'Certification',
			@AssistancePayment nvarchar(18) = 'Assistance Payment',
			@Adjustment nvarchar(10) = 'Adjustment',
	-- Termination Reasons
			@NoSubsidy nvarchar(24) = 'Resident did not qualify',
			@DoubleSubsidy nvarchar(14) = 'Double subsidy',
	--Random
			@Tenant nvarchar(6) = 'Tenant', --AffordableSubmissionType
			@PaidByTreasuryCode nvarchar(5) = 'VSP00', --Signifies that the voucher was paid by HUD
			@DeathOfSoleFamilyMember nvarchar(27) = 'Death of sole family member', --Move out reason
			@HeadOfHousehold nvarchar(17) = 'Head of Household',
	-- XML Helpers
			@ActivityLogType nvarchar(10) = 'ADJUSTMENT',
			@ObjectName nvarchar(7) = 'Voucher',
			@UnbilledUncutCertificationsActivity nvarchar(27) = 'UnbilledUncutCertifications', 
			@SemiFilteredCertificationsActivity nvarchar(26) = 'SemiFilteredCertifications',
			@UnitLeaseGroupActivity nvarchar(15) = 'UnitLeaseGroups',
			@DeadzonesActivity nvarchar(9) = 'Deadzones',
			@TimelineActivity nvarchar(8) = 'Timeline',
			@OrderedTimelineActivity nvarchar(15) = 'OrderedTimeline',
			@NewTimelineActivity nvarchar(11) = 'NewTimeline'

	DECLARE @AdjustmentGroupCounterOverride int = NULL

	-- Want to double check that your strings are the right lengths?
	--SELECT @AR, @IR, @IC, @MI, @MO, @TM, @GR, @UT, @Sent, @Success, @CorrectionsNeeded, @RAP, @RentSupplement, @Certification,
	--	   @AssistancePayment, @Adjustment, @NoSubsidy, @DoubleSubsidy, @Tenant, @PaidByTreasuryCode, @DeathOfSoleFamilyMember, @HeadOfHousehold,
	--	   @ActivityLogType, @ObjectName, @UnbilledUncutCertificationsActivity, @SemiFilteredCertifications, @UnitLeaseGroupActivity, 
	--	   @DeadzonesActivity, @TimelineActivity, @OrderedTimelineActivity, @NewTimelineActivity

	-- This is a table we use to stage adjustments that are closed to finished, this isn't the final object that we return, this whole table gets cleaned 
	-- and put into another table before we can return it
	CREATE TABLE #Adjustments (GroupNumber int, AdjustmentID uniqueidentifier, RowNumber int not null identity(1,1), CertificationID uniqueidentifier, UnitID uniqueidentifier, 
							   HoHFirstName nvarchar(50), HoHMiddleInitial nvarchar(1), HoHLastName nvarchar(50), UnitNumber nvarchar(50), 
							   PriorOrNewBilling nvarchar(5), NewCert nvarchar(1), CertType nvarchar(6), EffectiveDate date, AssistancePayment int, 
							   BeginningDate date, EndingDate date, BeginningNoOfDays int, BeginningDailyRate money, NoOfMonths int, MonthlyRate int, 
							   EndingNoOfDays int, EndingDailyRate money, Amount int, Requested int, Paid int, PaddedUnitNumber nvarchar(20))

	-- First let's figure out if this voucher is in a sent, success or corrections needed status, if it's in any of those statuses then we just need to 
	-- show the adjustment data that is already in our database for this voucher, if the voucher is in error or pending status then we have to dynamically
	-- figure out what is supposed to be tied to this voucher
	DECLARE @VoucherLocked bit = 0
	SELECT @VoucherLocked = CASE WHEN [Status] IN (@Sent, @Success, @CorrectionsNeeded) THEN 1 ELSE 0 END
	FROM AffordableSubmission
	WHERE AccountID = @accountID
		  AND AffordableSubmissionID = @affordableSubmissionID

	-- We just need to show the data already in our database, no need to dynamically calculate anything, thank goodness!
	IF @VoucherLocked = 1
	BEGIN 
		INSERT INTO #Adjustments
			SELECT ca.GroupNumber AS 'GroupNumber',
				   ca.CertificationAdjustmentID AS 'AdjustmentID',
				   ca.CertificationID AS 'CertificationID', 
				   ulg.UnitID AS 'UnitID', 
				   ca.FirstName AS 'HoHFirstName', 
				   ca.MiddleInitial 'HoHMiddleInitial', 
				   ca.LastName AS 'HoHLastName', 
				   ca.UnitNumber AS 'UnitNumber', 
				   ca.IsPrior AS 'PriorOrNewBilling', 
				   ca.NewCert AS 'NewCert', 
				   ca.CertType AS 'CertType', 
				   ca.EffectiveDate AS 'EffectiveDate', 
				   ca.AssistancePayment AS 'AssistancePayment', 
				   ca.BeginningDate AS 'BeginningDate', 
				   ca.EndingDate AS 'EndingDate', 
				   ca.BeginningNoOfDays AS 'BeginningNoOfDays', 
				   ca.BeginningDailyRate AS 'BeginningDailyRate', 
				   ca.NoOfMonths AS 'NoOfMonths', 
				   ca.AssistancePayment AS 'MonthlyRate', 
				   ca.EndingNoOfDays AS 'EndingNoOfDays', 
				   ca.EndingDailyRate AS 'EndingDailyRate',
				   ca.Amount AS 'Amount', 
				   ca.Requested AS 'Requested',
				   asi.PaidAmount AS 'Paid',
				   u.PaddedNumber AS 'PaddedUnitNumber'
			FROM CertificationAdjustment ca
			INNER JOIN Certification c ON c.CertificationID = ca.CertificationID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
			INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = ca.CertificationAdjustmentID
			INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi.AffordableSubmissionID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			WHERE a.AffordableSubmissionID = @affordableSubmissionID

			-- Adding these blank rows because on the form it's harder to create blank rows in between groups
			INSERT INTO #Adjustments
					SELECT GroupNumber AS 'GroupNumber', 
						   NULL AS 'AdjustmentID',
						   NULL AS 'CertificationID',
						   NULL AS 'UnitID',
						   NULL AS 'HoHFirstName',
						   NULL AS 'HoHMiddleInitial',
						   NULL AS 'HoHLastName',
						   NULL AS 'UnitNumber',
						   NULL AS 'PriorOrNewBilling',
						   NULL AS 'NewCert',
						   NULL AS 'CertType',
						   NULL AS 'EffectiveDate',
						   NULL AS 'AssistancePayment',
						   NULL AS 'BeginningDate',
						   NULL AS 'EndingDate',
						   NULL AS 'BeginningNoOfDays',
						   NULL AS 'BeginningDailyRate',
						   NULL AS 'NoOfMonths',
						   NULL AS 'MonthlyRate',
						   NULL AS 'EndingNoOfDays',
						   NULL AS 'EndingDailyRate',
						   NULL AS 'Amount',
						   NULL AS 'Requested',
						   NULL AS 'Paid',
						   NULL AS 'PaddedUnitNumber'
					FROM AffordableSubmission a
					INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissionID = a.AffordableSubmissionID
					INNER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
					WHERE a.AffordableSubmissionID = @affordableSubmissionID
					-- Groups by group number, adds a blank row after each group, the final group's 
					-- blank row will be cleaned off later at the end of this sproc
					GROUP BY GroupNumber
	END
	-- This else means that we have to dynamically calculate the adjustments that should be included in this voucher
	-- This is where all the complex stuff happens, this else statement pretty much ends at the very end of this sproc
	-- everything else in this sproc is contained in this else statement except the final cleaning
	ELSE
	BEGIN
		DECLARE @voucherMonth datetime = NULL,
				@affordableProgramAllocationID uniqueidentifier = NULL,
				@IsVoucherCorrection bit = 0

		-- Variables that will hold our XML snapshots (nvarchar max is faster storage than the XML type)
		-- If we are calculating adjustments because right now we're trying to send this submission
		-- then we'll save our temp tables in the activity log as we go, we have to convert into nvarchar to save on the activity log anyways
		DECLARE @UnbilledUncutCertifications nvarchar(max), -- all the certifications before any of the cuts
				@SemiFilteredCertifications nvarchar(max), -- all the certifications after the first three cuts
				@UnitLeaseGroups nvarchar(max), -- can be used to get a list of certifications after all cuts
				@Deadzones nvarchar(max),
				@Timeline nvarchar(max),
				@OrderedTimeline nvarchar(max),
				@NewTimeline nvarchar(max)

		-- This Unbilled Certifications table is all of the qualifying new certifications that we need to bill for, these certifications will constitute the
		-- new billing rows on the adjustments that are also new certs, so billing = "New", New Cert = "Y" on the adjustment form, these certifications
		-- to be billed determine our adjustment window, this table is just a pool, after we perform our cuts we'll have to break this pool up into
		-- unit lease group chains
		CREATE TABLE #UnbilledCertifications (CertificationID uniqueidentifier, UnitLeaseGroupID uniqueidentifier, TransferGroupID uniqueidentifier, 
											  [Type] nvarchar(25), EffectiveDate date)
	
		-- Now we need to know which month this is for and what subsidy it's for
		SELECT @voucherMonth = a.StartDate,
			   @affordableProgramAllocationID = a.AffordableProgramAllocationID,
			   @IsVoucherCorrection = CASE WHEN originalVoucher.AffordableSubmissionID IS NULL THEN 0 ELSE 1 END
		FROM AffordableSubmission a
		LEFT OUTER JOIN AffordableSubmission originalVoucher ON originalVoucher.CorrectedByID = a.AffordableSubmissionID
		WHERE a.AccountID = @accountID
			  AND a.AffordableSubmissionID = @affordableSubmissionID

		-- This just gives us a complete list of all certifications that have been successfully sent to HUD for this contract in tenant submissions
		-- These certifications have not been billed yet, this query is just the beginning, the Unbilled Certifications table will have to go through
		-- several "cuts" before we actually have the correct data, each "cut" filters out a certain number of certifications that don't qualify
		-- to be billed for a number of different reasons
		INSERT INTO #UnbilledCertifications 
			SELECT DISTINCT c.CertificationID AS 'CertificationID',
				   c.UnitLeaseGroupID AS 'UnitLeaseGroupID',
				   ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID),
				   c.[Type] AS 'Type',
				   -- One very important thing to consider here is that we're changing the effective date on our own
				   -- certification table but the real certification database table now has the wrong effective date, so in the 
				   -- rest of this stored procedure we can't just join in the certification table and use the effective
				   -- date because that could potentially be wrong since it hasn't had this rule applied to it yet
				   -- In the rest of this sproc you'll see that if we need more certification information we always join
				   -- to our own certification table instead of the regular certification table, because we want
				   -- to make sure that we're always getting the updated effective date, there are a couple places where
				   -- we join to the regular certification database table, but that's on purpose because we're looking 
				   -- at certifications that may have already been billed before (prior adjustment section), in those 
				   -- places we'll have to apply this rule again
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
			WHERE c.DateCompleted IS NOT NULL
				  -- Make sure that we are only looking at certs for the same allocation as the voucher we're doing this whole sproc for
				  AND apa.AffordableProgramAllocationID = @affordableProgramAllocationID
				  AND asi.ObjectType = @Certification AND asi.[Status] IN (@Sent, @Success, @CorrectionsNeeded)
				  AND a.AccountID = @accountID
				  -- When the certification was submitted the baseline flag must be set at 0, if the baseline flag was set to true (1) then 
				  -- we never count those tenant submissions towards billing, of course, the certification can 
				  -- just be put on another submission and not be sent as a baseline then it would be considered for billing
				  AND asi.IsBaseline = 0
				  -- Make sure that none of these certifications have successfully paid adjustments or assistance payments
				  -- Of course, there may be an adjustment or assistance payment that has been sent for these certifications
				  -- that hasn't received payment from HUD yet, the user may be trying to perform a voucher correction with this
				  -- voucher submission
				  AND c.CertificationID NOT IN (
					SELECT c.CertificationID 
					FROM Certification c 
					LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationID = c.CertificationID
					INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID IN (c.CertificationID, ca.CertificationAdjustmentID)
					INNER JOIN AffordableSubmissionPayment asp ON asp.AffordableSubmissionID = asi.AffordableSubmissionID AND asp.Code = @PaidByTreasuryCode)

		/**** ------------------------------------------ XML Snapshot #1 - Unbilled Uncut Certifications ------------------------------------------ ****/
		-- We're trying to send this submission right now so let's save our uncut unbilled certification table in the activity log
		IF @sending = 1
		BEGIN
			SET @UnbilledUncutCertifications = (SELECT CONVERT(nvarchar(max), (SELECT * FROM #UnbilledCertifications FOR XML RAW ('UnbilledUncutCertification'), ROOT('UnbilledUncutCertifications'))))
			INSERT INTO ActivityLog (ActivityLogID, AccountID, ActivityLogType, ObjectName, ObjectID, Activity, [Timestamp], ExceptionCaught, Exception)
				   VALUES (NEWID(), @accountID, @ActivityLogType, @ObjectName, @affordableSubmissionID, @UnbilledUncutCertificationsActivity, 
						   SYSUTCDATETIME(), 0, @UnbilledUncutCertifications)			   
		END
		
		/**** ------------------------------------------ Cut #1 - Corrections that Override ------------------------------------------ ****/
		-- Now we need to remove all original certifications that are either permanently ignored or are going to start being ignored from this voucher on
		DECLARE @CertificationsToPurge GuidCollection
		INSERT INTO @CertificationsToPurge 
			SELECT CertificationID FROM #UnbilledCertifications

		-- We built a table-valued function that removes all of the ignorable certifications, because the assistance payment logic needs the same logic
		DELETE FROM #UnbilledCertifications
		WHERE CertificationID NOT IN (
			SELECT * FROM dbo.RemoveIgnoredCertifications(@accountID, @CertificationsToPurge))

		/**** ------------------------------------------ Cut #2 - Same Day Certifications ------------------------------------------ ****/
		-- Now remove certifications that share effective dates with other certifications but were not sent as recently as other certifications
		-- If we have a GRC, an IR and an AR that all fall on 10/30/2016, then whichever one was sent to HUD most recently is the only certification
		-- that gets to stick around
		DELETE FROM #UnbilledCertifications
		WHERE CertificationID IN (
			SELECT ubc.CertificationID 
			FROM #UnbilledCertifications ubc
			-- Get rid of this certification if it's not the certification that is the most recently sent to HUD
			-- Look at other certifications that are in the same unit lease group chain and are on the same effective date
			WHERE ubc.CertificationID <> (SELECT TOP 1 subUbc.CertificationID 
										  FROM #UnbilledCertifications subUbc
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

		-- Possible cut, we could do another cut here that handles the sequence of TRACS processing, specifically TRACS nature that handles move-outs first,
		-- terminations second, full certifications thirdly and partial certifications last, this could affect which certifications we cut out of this list, 
		-- but in ResMan we are planning on limiting a user to only send a single certification for a household in a single tenant submission, once we 
		-- finish that development then this cut wouldn't be necessary anymore, if we aren't planning on doing that development, then this cut will need to be
		-- developed here

		/**** ------------------------------------------ Cut #3 - Anticipated Voucher Date ------------------------------------------ ****/
		-- Remove any certifications that don't belong in this voucher month, these certifications will have to wait for future months
		-- to be submitted, of course, we could have put this logic in our original query that gets all of All Certifications, but we need
		-- to apply the correction override logic (Cut #1) and the Cut #2 first before we do this cut

		-- Basically this query just gets a list of certification IDs that we know have to be adjustments that also fit in this month,
		-- then we just remove everything from our list that isn't a qualified adjustment for the month, this does the dual role of 
		-- getting rid of certifications that will be adjustments but don't fit in this month and also gets rid of the certifications
		-- that could just be billed as assistance payments instead
		DELETE FROM #UnbilledCertifications
		WHERE CertificationID IN (
			SELECT CertificationID
			FROM #UnbilledCertifications
			WHERE dbo.FirstHUDMonthBillable(CertificationID, @accountID, 0) > @voucherMonth)

		DELETE FROM #UnbilledCertifications
		WHERE CertificationID NOT IN (
			-- This is a kind of confusing query because we're using a NOT IN above, essentially the sub query is just returning a list of 
			-- all of the certs that we know must be billed as adjustments, then we just remove any certification from our master list
			-- that don't absolutely have to be adjustments
			SELECT c.CertificationID 
			FROM #UnbilledCertifications c
			-- The first month that this cert could be reported has come and gone therefore it has to be an adjustment
			WHERE (dbo.FirstHUDMonthBillable(c.CertificationID, @accountID, 0) < @voucherMonth 
				   -- Or this is the first month that this cert could be reported but it's effective date isn't on the first, which means
				   -- that it must have an adjustment
				   OR (dbo.FirstHUDMonthBillable(c.CertificationID, @accountID, 0) = @voucherMonth AND c.EffectiveDate <> @voucherMonth))) 

		/**** ------------------------------------------ XML Snapshot #2 - Semi Filtered Certifications ------------------------------------------ ****/
		-- We're trying to send this submission right now so let's save our unbilled certification list in the activity log, obviously only half of
		-- the cuts are done so far, that's fine, the unit lease groups table acts as a list for the certifications after all cuts
		IF @sending = 1
		BEGIN
			SET @SemiFilteredCertifications = (SELECT CONVERT(nvarchar(max), (SELECT * FROM #UnbilledCertifications FOR XML RAW ('SemiFilteredCertification'), ROOT('SemiFilteredCertifications'))))
			INSERT INTO ActivityLog (ActivityLogID, AccountID, ActivityLogType, ObjectName, ObjectID, Activity, [Timestamp], ExceptionCaught, Exception)
					VALUES (NEWID(), @accountID, @ActivityLogType, @ObjectName, @affordableSubmissionID, @SemiFilteredCertificationsActivity, 
							SYSUTCDATETIME(), 0, @SemiFilteredCertifications)			   
		END

		/**** ------------------------------------------ Split the Certifiation Pool ------------------------------------------ ****/
		-- Up until this point we've gathered up certifications into a big pool (#UnbilledCertifications), none of them are organized or 
		-- connected to each other.  Adjustments are done as groups though and now we can no longer treat the certifications in a pool, 
		-- we'll need to group them together into their respective unit lease group chains

		-- Unit Lease Group Counter can't be an identity because several rows in the unit lease group table will have the same value
		CREATE TABLE #UnitLeaseGroups (UnitLeaseGroupCounter int, CertificationID uniqueidentifier)
		CREATE TABLE #RemainingCerts (CertificationID uniqueidentifier)

		-- We keep a list of all the certs in the master list, when we add a cert to unit lease group, we'll take it off this list
		INSERT INTO #RemainingCerts SELECT CertificationID FROM #UnbilledCertifications
		DECLARE @RemainingCertsCount int = 0,
				@UnitLeaseGroupCounter int = 1 -- This is the int we'll use group number, helps us easily navigate between groups
		-- Obviously this is always going to be the same count as the unbilled certification count, but as we start the loop this will change
		SELECT @RemainingCertsCount = COUNT(*) FROM #RemainingCerts

		WHILE @RemainingCertsCount > 0
		BEGIN
			DECLARE @currentTransferGroupID uniqueidentifier = NULL
			--Pick a cert that we haven't work with yet and get it's transfer group
			SELECT TOP 1 @currentTransferGroupID = ubc.TransferGroupID
			FROM #RemainingCerts rc
			INNER JOIN #UnbilledCertifications ubc ON ubc.CertificationID = rc.CertificationID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = ubc.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			ORDER BY ISNULL(u.HudUnitNumber, u.Number)
			
			-- Out of our remaining certifications grab all of the certications that belong in the same unit lease group chain
			-- as the random certification that we selected at the start of this iteration
			INSERT INTO #UnitLeaseGroups 
				SELECT @UnitLeaseGroupCounter AS 'UnitLeaseGroupCounter', 
					   rc.CertificationID AS 'CertificationID'
				FROM #RemainingCerts rc
				INNER JOIN Certification c ON c.CertificationID = rc.CertificationID
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
				WHERE ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @currentTransferGroupID) OR ulg.UnitLeaseGroupID = @currentTransferGroupID)

			-- Now delete all of the certs from the remaining cert table that we just added to the unit lease group table
			DELETE FROM #RemainingCerts
			WHERE CertificationID IN (SELECT CertificationID FROM #UnitLeaseGroups WHERE UnitLeaseGroupCounter = @UnitLeaseGroupCounter)

			--Prepare for next iteration in loop
			SELECT @UnitLeaseGroupCounter = @UnitLeaseGroupCounter + 1
			SELECT @RemainingCertsCount = COUNT(*) FROM #RemainingCerts
		END
		TRUNCATE TABLE #RemainingCerts
		
		/**** ------------------------------------------ Start Working in Unit Lease Groups ------------------------------------------ ****/
		DECLARE @LastAdjustmentGroup int = 0,
				@AdjustmentGroupCounter int = 1
		SELECT @LastAdjustmentGroup = MAX(UnitLeaseGroupCounter) FROM #UnitLeaseGroups

		-- Create all of the tables that we'll need in the upcoming loop, yeah it's a lot I know...
		CREATE TABLE #Deadzones (Startdate datetime, EndDate datetime)
		CREATE TABLE #Timeline (StartDate datetime, EndDate datetime, AffordableSubmissionItemID uniqueidentifier)
		CREATE TABLE #AffordableSubmissions (AffordableSubmissionID uniqueidentifier)
		CREATE TABLE #OrderedTimeline ([Counter] int, StartDate datetime, EndDate datetime, AffordableSubmissionItemID uniqueidentifier, CertificationID uniqueidentifier)
		CREATE TABLE #TimelineItemsToReverse (ItemID uniqueidentifier)
		-- We could have just make the Counter in #NewTimeline an identity column but we delete stuff from that table and then we'd have to correct the counters
		-- to correct the counters you have to do an update and you can't update an identity column
		CREATE TABLE #NewTimeline ([Counter] int, StartDate datetime, EndDate datetime, AffordableSubmissionItemID uniqueidentifier, CertificationID uniqueidentifier)
		CREATE TABLE #TouchedTimelineItems (ItemID uniqueidentifier)

		-- Here we go!  From this point on we're going to just be working inside of unit lease group chains, now we're just looking at a group of certifications
		-- that are all related, there were a couple more cuts that we weren't able to perform until we started into this huge while loop
		WHILE @AdjustmentGroupCounter <= @LastAdjustmentGroup
		BEGIN
			/**** ------------------------------------------ Cut #4 - Billing Deadzones ------------------------------------------ ****/
			-- This cut removes certifications that have effective dates after a move-out or termination and/or before a move-in or initial
			-- These certifications basically are irrelevant and don't apply anymore, usually happens with gross rent changes or back-dated certs
			DECLARE @RandomUnitLeaseGroupNumber uniqueidentifier = NULL,
				    @TransferGroupID uniqueidentifier = NULL
			SELECT @RandomUnitLeaseGroupNumber = c.UnitLeaseGroupID,
				   @TransferGroupID = ISNULL(ulg2.TransferGroupID, ulg2.UnitLeaseGroupID)
			FROM #UnitLeaseGroups ulg
			INNER JOIN Certification c ON c.CertificationID = ulg.CertificationID
			INNER JOIN UnitLeaseGroup ulg2 ON ulg2.UnitLeaseGroupID = c.UnitLeaseGroupID
			WHERE ulg.UnitLeaseGroupCounter = @AdjustmentGroupCounter

			-- Look at all certifications in this unit lease group chain that have been successfully reported to HUD
			-- This is looking at more than just the un-billed certifications, this is looking at a complete representation
			-- of all of the certifications that HUD has for this unit lease group chain
			INSERT INTO #RemainingCerts
				SELECT DISTINCT c.CertificationID
				FROM Certification c 
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
				INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
				INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = capa.CertificationAffordableProgramAllocationID
				WHERE ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @TransferGroupID) OR ulg.UnitLeaseGroupID = @TransferGroupID)
					  AND asi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
					  AND asi.IsBaseline = 0
					  AND c.AccountID = @accountID
					  AND c.DateCompleted IS NOT NULL
					  -- We only care about these types that either mark the start or the end of a deadzone
					  AND c.[Type] IN (@MI, @IC, @TM, @MO)

			-- What used to be deadzones may not be deadzones anymore, the effective dates of move-outs or terminations may have
			-- changed, we want any certifications that have qualifying corrections to be removed, we are going to keep in their
			-- corrections, because those corrections will tell us what the current deadzones are, not what the deadzones used to be
			DELETE FROM #RemainingCerts
			WHERE CertificationID IN (SELECT udc.CertificationID -- Delete cert that was corrected
									  FROM #RemainingCerts udc
									  INNER JOIN Certification c ON c.CertificationID = udc.CertificationID
									  -- Make sure this cert was corrected by something else
									  INNER JOIN #RemainingCerts udc2 ON udc2.CertificationID = c.CorrectedByCertificationID)
			-- This isn't deleting the certifications that have effective dates that are being infringed upon by other certifications, for
			-- instance you send in one certification for 1/1/2016 and then a second certification gets sent to HUD with an effective date
			-- of 1/1/2016, because we're only looking at MI, IC, MO and TM then is situation should never happen because TRACS should give
			-- the user some fatal error saying that they can't submit certifications on the day when the person is moving out or moving in

			-- Get the earliest effective date and then everything before that until the beginning of time is where the first deadzone lays
			INSERT INTO #Deadzones
				SELECT '1800-01-01' AS 'Startdate', 
					   (SELECT TOP 1 c.EffectiveDate
						-- Move in or initial certs
						FROM Certification c
						INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
						INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
						-- That were successfully sent to HUD
						INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = capa.CertificationAffordableProgramAllocationID
						INNER JOIN AffordableHousehold ah ON ah.ObjectID = c.UnitLeaseGroupID
						-- Termination due to double subsidy or no subsidy that would cancel out this move in or initial
						LEFT OUTER JOIN Certification c2 ON c2.EffectiveDate = c.EffectiveDate
															AND c2.AccountID = @accountID
															AND c2.[Type] = @TM
															AND c2.TerminationReason IN (@DoubleSubsidy, @NoSubsidy)
															AND c2.DateCompleted IS NOT NULL
															AND ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @TransferGroupID) OR ulg.UnitLeaseGroupID = @TransferGroupID)
						LEFT OUTER JOIN CertificationAffordableProgramAllocation capa2 ON capa2.CertificationID = c2.CertificationID
						-- Was a termination like this ever successfully sent to HUD?
						LEFT OUTER JOIN AffordableSubmissionItem asi2 ON asi2.ObjectID = capa2.CertificationAffordableProgramAllocationID
																			AND asi2.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
																			AND asi2.IsBaseline = 0
						WHERE ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @TransferGroupID) OR ulg.UnitLeaseGroupID = @TransferGroupID)
							  AND asi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
							  AND asi.IsBaseline = 0
							  AND c.AccountID = @accountID
							  AND c.DateCompleted IS NOT NULL
							  --AND c.[Type] IN (@MI, @IC)
							  -- Make sure that there was never a termination that would have reversed this move-in or initial cert
							  AND asi2.AffordableSubmissionItemID IS NULL
						-- Earliest effective date
						ORDER BY c.EffectiveDate) AS 'EndDate'

			SELECT @RemainingCertsCount = COUNT(*) FROM #RemainingCerts
			
			-- Start looping through all of our certs that were ever sent successfully to HUD to get the complete list of deadzones
			WHILE @RemainingCertsCount > 0
			BEGIN
				DECLARE @ThisUntouchedCert uniqueidentifier = NULL,                         
						@ThisUntouchedCertType nvarchar(30) = NULL,
						@ThisUntouchedCertDate datetime = NULL
				-- Pick a certification that remains
				-- We have to apply the death date rule again because these certifications are not in our UnbilledCertification table, these
				-- are all certifications including those that were previously billed, the UnbilledCertification table is obviously only for
				-- unbilled certs, so some certs may be on both UnbilledCertification and Remaining Cert table, but some may not
				SELECT TOP 1 @ThisUntouchedCert = udc.CertificationID,
							 @ThisUntouchedCertType = c.[Type],
							 @ThisUntouchedCertDate = CASE WHEN (c.EffectiveDate > DATEADD(D, 14, ah.DeathDate) AND c.[Type] = @MO) 
														   THEN DATEADD(D, 14, ah.DeathDate) ELSE c.EffectiveDate END
				FROM #RemainingCerts udc
				INNER JOIN Certification c ON c.CertificationID = udc.CertificationID
				INNER JOIN AffordableHousehold ah ON ah.ObjectID = c.UnitLeaseGroupID
				-- Why are we doing the death date rule again?  Remember that the certifications inside UntouchedDeadzoneCerts don't have to be in the UnbilledCertifications
				-- table, we're looking at the entire timeline of all certifications sent successfully to HUD, so unfortunately the UnbilledCertifications.EffectiveDate 
				-- won't help us
				ORDER BY CASE WHEN (c.EffectiveDate > DATEADD(D, 14, ah.DeathDate) AND c.[Type] = @MO) THEN DATEADD(D, 14, ah.DeathDate) ELSE c.EffectiveDate END

				-- Move-out/terminations mark the start of our deadzone, if we find one then try to find the next move-in or initial
				-- so that we can mark the start and end of this deadzone
				IF @ThisUntouchedCertType IN (@MO, @TM)
				BEGIN
					-- We found a move-out or termination, now we need to find the next chronologic move-in or initial if one exists
					DECLARE @NextMIIC uniqueidentifier = NULL
					SELECT TOP 1 @NextMIIC = udc.CertificationID
					FROM #RemainingCerts udc
					INNER JOIN Certification c ON c.CertificationID = udc.CertificationID
					INNER JOIN AffordableHousehold ah ON ah.ObjectID = c.UnitLeaseGroupID
					-- Don't have to apply the death date rule here because we're only looking at IC and MI's not MO's
					WHERE c.EffectiveDate > @ThisUntouchedCertDate
						  AND c.[Type] IN (@IC, @MI)
					ORDER BY c.EffectiveDate
					-- We couldn't find a move-in or initial after that move-out or termination, 
					-- so this deadzone will continue until the year 3000 at which poverty will
					-- be completely eliminated so we won't need subsidized housing anymore
					IF @NextMIIC IS NULL
					BEGIN
						INSERT INTO #Deadzones
							SELECT @ThisUntouchedCertDate AS 'Startdate', 
							'2999-12-31 00:00:00.000' AS 'EndDate'
						-- We can go ahead and remove anything else from the queue to be looked at
						TRUNCATE TABLE #RemainingCerts
					END
					-- There was a move-in or initial after this move-out or termination, so the deadzone will be finite
					ELSE 
					BEGIN
						INSERT INTO #Deadzones	
							SELECT @ThisUntouchedCertDate AS 'Startdate', -- Start date is the effective date of the move-out or termination
								   c.EffectiveDate AS 'EndDate' -- End date is the effective date of the move-in or initial that we found after our move-out or termination
							FROM #RemainingCerts udc
							INNER JOIN Certification c ON c.CertificationID = udc.CertificationID
							WHERE udc.CertificationID = @NextMIIC
						-- There may be more deadzones, remove this move in or initial and the move out or termination from our remaining certs
						-- We're going to have to keep going through this loop till we find every deadzone
						DELETE FROM #RemainingCerts
						WHERE CertificationID = @NextMIIC
					END
				END -- End of if statement that tries to find a move-out or termination
				DELETE FROM #RemainingCerts
				WHERE CertificationID = @ThisUntouchedCert
				SELECT @RemainingCertsCount = COUNT(*) FROM #RemainingCerts
			END -- End of loop

			/**** ------------------------------------------ XML Snapshot #3 - Deadzones ------------------------------------------ ****/
			-- We're trying to send this submission right now so let's save our deadzones in the activity log
			IF @sending = 1
			BEGIN
				SET @Deadzones = (SELECT CONVERT(nvarchar(max), (SELECT * FROM #Deadzones FOR XML RAW ('Deadzone'), ROOT('Deadzones'))))
				INSERT INTO ActivityLog (ActivityLogID, AccountID, ActivityLogType, ObjectName, ObjectID, Activity, [Timestamp], ExceptionCaught, Exception, IntegrationPartnerID)
					   VALUES (NEWID(), @accountID, @ActivityLogType, @ObjectName, @affordableSubmissionID, @DeadzonesActivity, 
							   SYSUTCDATETIME(), 0, @Deadzones, @AdjustmentGroupCounter)			   
			END

			-- Now we have the deadzones, so let's remove all the certifications that fall in deadzones
			DELETE FROM #UnitLeaseGroups
			WHERE CertificationID IN (
				SELECT ulg.CertificationID
				FROM #UnitLeaseGroups ulg
				INNER JOIN #UnbilledCertifications c ON c.CertificationID = ulg.CertificationID
				-- because we're not using >= or <= this means that we will keep our move-in, initials, move-outs and terminations in
				-- that is what we want because those deadzone markers are still valid and will need billing
				INNER JOIN #Deadzones d ON c.EffectiveDate > d.Startdate AND c.EffectiveDate < d.EndDate
				WHERE ulg.UnitLeaseGroupCounter = @AdjustmentGroupCounter)

			/**** ------------------------------------------ XML Snapshot #4 - Unit Lease Groups ------------------------------------------ ****/
			-- We're trying to send this submission right now so let's save our unit lease group temp table in the activity log, only
			-- need to save this on the last iteration through this group, it contains the same data no matter what iteration we're in so
			-- we don't need to redundantly save it, of course we can only save this snapshot now because the cuts to the unit lease group table
			-- have all occured
			IF @sending = 1 AND @AdjustmentGroupCounter = @LastAdjustmentGroup
			BEGIN
				SET @UnitLeaseGroups = (SELECT CONVERT(nvarchar(max), (SELECT * FROM #UnitLeaseGroups FOR XML RAW ('UnitLeaseGroup'), ROOT('UnitLeaseGroups'))))
				INSERT INTO ActivityLog (ActivityLogID, AccountID, ActivityLogType, ObjectName, ObjectID, Activity, [Timestamp], ExceptionCaught, Exception)
					   VALUES (NEWID(), @accountID, @ActivityLogType, @ObjectName, @affordableSubmissionID, @UnitLeaseGroupActivity, SYSUTCDATETIME(), 0, @UnitLeaseGroups)			   
			END

			/**** ------------------------------------------ Get The Billing Timeline For the Unit Lease Group Chain ------------------------------------------ ****/
			-- This is going to give us the complete timeline of how this unit lease group chain was billed.  This billing can consist of several assistance payments and
			-- adjustments spread across several vouchers.  This timeline represents all recent billing and is what may need to be reversed in the prior section, this timeline
			-- excludes assistance payments or adjustments that were already reversed and so are no longer relevant

			-- Find all paid vouchers for this allocation, these could be either original vouchers or corrections that beat out their originals
			INSERT INTO #AffordableSubmissions
				SELECT a.AffordableSubmissionID
				FROM AffordableSubmission a
				INNER JOIN AffordableSubmissionPayment asp ON asp.AffordableSubmissionID = a.AffordableSubmissionID
				-- Is there a voucher correction for this submission?
				LEFT OUTER JOIN AffordableSubmission correction ON correction.AffordableSubmissionID = a.CorrectedByID
				LEFT OUTER JOIN AffordableSubmissionPayment asp2 ON asp2.AffordableSubmissionID = correction.AffordableSubmissionID AND asp2.Code = @PaidByTreasuryCode
				WHERE a.AccountID = @accountID
					  -- Get all voucher submissions for the same allocation that are successfully paid
					  -- and don't have successfully paid corrections
					  AND a.AffordableProgramAllocationID = @affordableProgramAllocationID
					  AND a.[Status] IN (@CorrectionsNeeded, @Success)
					  AND a.HUDSubmissionType = 'Voucher'
					  AND asp.Code = @PaidByTreasuryCode
					  AND asp2.AffordableSubmissionPaymentID IS NULL
					  -- Obviously we don't care about our current voucher because it hasn't been billed yet if we're dynamically
					  -- trying to find adjustments for it with this sproc
					  AND a.AffordableSubmissionID <> @affordableSubmissionID

			-- Start Looping Backwards Through Time, through the most recent submissions to the oldest
			WHILE (SELECT COUNT(*) FROM #AffordableSubmissions) > 0
			BEGIN
				DECLARE @ThisAffordableSubmission uniqueidentifier = NULL
				-- Start from the most current submission and then go backwards in the next iterations
				-- Pick the most rent submission
				SELECT TOP 1 @ThisAffordableSubmission = AffordableSubmissionID
				FROM AffordableSubmission
				WHERE AffordableSubmissionID IN (SELECT * FROM #AffordableSubmissions)
				ORDER BY StartDate DESC

				-- Add adjustments to the timeline if there are any
				INSERT INTO #Timeline
					SELECT ca.BeginningDate AS 'StartDate', 
						   ca.EndingDate AS 'EndDate', 
						   asi.AffordableSubmissionItemID AS 'AffordableSubmissionItemID'
					FROM Certification c 
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
					INNER JOIN CertificationAdjustment ca ON ca.CertificationID = c.CertificationID
					INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = ca.CertificationAdjustmentID
					LEFT OUTER JOIN Certification paidCorrection ON paidCorrection.CertificationID = (
						SELECT TOP 1 subC.CertificationID 
						FROM Certification subC
						LEFT OUTER JOIN CertificationAdjustment subCa ON subCa.CertificationID = subC.CertificationID
						INNER JOIN AffordableSubmissionItem subAsi ON subAsi.ObjectID IN (subCa.CertificationAdjustmentID, subC.CertificationID)
						INNER JOIN AffordableSubmissionPayment subAsp ON subAsp.AffordableSubmissionID = subAsi.AffordableSubmissionID
						WHERE subC.CertificationID = c.CorrectedByCertificationID
							  AND subAsp.Code = @PaidByTreasuryCode)
					WHERE ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @TransferGroupID) OR ulg.UnitLeaseGroupID = @TransferGroupID)
						  AND asi.AffordableSubmissionID = @ThisAffordableSubmission
						  AND ca.IsPrior = 0
						  AND paidCorrection.CertificationID IS NULL
						  AND ca.CertType NOT IN ('UT-O', 'UT-O*')

				-- Add assistance payments to the timeline if there are any
				INSERT INTO #Timeline 
					SELECT a.StartDate AS 'StartDate', 
						   DATEADD(D, -1, a.EndDate) AS 'EndDate', 
						   asi.AffordableSubmissionItemID AS 'AffordableSubmissionItemID'
					FROM Certification c
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
					INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = c.CertificationID
					INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi.AffordableSubmissionID
					LEFT OUTER JOIN #Timeline t ON t.StartDate <= a.StartDate AND t.EndDate >= DATEADD(D, -1, a.EndDate)
					-- Here we make sure that the assistance payment isn't covering up a more recent billing
					LEFT OUTER JOIN #Timeline toeSteppingFront ON toeSteppingFront.StartDate <= a.StartDate AND toeSteppingFront.EndDate >= a.StartDate
					LEFT OUTER JOIN #Timeline toeSteppingBack ON toeSteppingBack.StartDate <= DATEADD(D, -1, a.EndDate) AND toeSteppingBack.EndDate >= DATEADD(D, -1, a.EndDate)
					LEFT OUTER JOIN Certification paidCorrection ON paidCorrection.CertificationID = (
						SELECT TOP 1 subC.CertificationID 
						FROM Certification subC
						LEFT OUTER JOIN CertificationAdjustment subCa ON subCa.CertificationID = subC.CertificationID
						INNER JOIN AffordableSubmissionItem subAsi ON subAsi.ObjectID IN (subCa.CertificationAdjustmentID, subC.CertificationID)
						INNER JOIN AffordableSubmissionPayment subAsp ON subAsp.AffordableSubmissionID = subAsi.AffordableSubmissionID
						WHERE subC.CertificationID = c.CorrectedByCertificationID
							  AND subAsp.Code = @PaidByTreasuryCode)
					WHERE ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @TransferGroupID) OR ulg.UnitLeaseGroupID = @TransferGroupID)
						  AND a.AffordableSubmissionID = @ThisAffordableSubmission
						  AND t.AffordableSubmissionItemID IS NULL
						  AND toeSteppingFront.AffordableSubmissionItemID IS NULL
						  AND toeSteppingBack.AffordableSubmissionItemID IS NULL
						  AND paidCorrection.CertificationID IS NULL

				DELETE FROM #AffordableSubmissions
				WHERE AffordableSubmissionID = @ThisAffordableSubmission
			END

			/**** ------------------------------------------ XML Snapshot #5 - Timeline ------------------------------------------ ****/
			-- We're trying to send this submission right now so let's save our timeline temp table in the activity log
			IF @sending = 1
			BEGIN
				SET @Timeline = (SELECT CONVERT(nvarchar(max), (SELECT * FROM #Timeline FOR XML RAW ('Timeline'), ROOT('Timelines'))))
				INSERT INTO ActivityLog (ActivityLogID, AccountID, ActivityLogType, ObjectName, ObjectID, Activity, [Timestamp], ExceptionCaught, Exception, IntegrationPartnerID)
					   VALUES (NEWID(), @accountID, @ActivityLogType, @ObjectName, @affordableSubmissionID, @TimelineActivity, SYSUTCDATETIME(), 0, @Timeline, @AdjustmentGroupCounter)			   
			END

			/**** ------------------------------------------ Lone Termination Stop ------------------------------------------ ****/
			-- This is a very specific situation that can potentially occur, if a move-in or an initial was sent in and then a termination
			-- due to double subsidy or no subsidy is submitted later for the same effective day that is completely valid.  Think about what would
			-- happen in this situation, above we have Cut #2 which eliminates a certification that shares an effective date with another certification
			-- that is sent to TRACS later, this cut actually works perfectly with termination due to DS or NS, in our example that we mentioned above
			-- if we just had a single move-in and then a termination on the same day the move-in would be eliminated, but in addition to that the termination
			-- can be eliminated too, of course there needs to be no billing history and this termination should be completely by itself, if there is no
			-- history and the termination is by itself, that means that it eliminated some other certification that it shared and effective date with,
			-- a termination stranded on it's own like this, doesn't need to be billed, there's nothing to reverse, because the original move-in or initial
			-- was never billed in the first place, the following logic looks for this very specific situation and then stops the whole unit lease group
			-- from being touched at all if the entire unit lease group chain is just a stranded termination by itself
			DECLARE @NoBillingHistory bit = 0,
					@LonelyTermination bit = 0

			SELECT @NoBillingHistory = CASE WHEN (SELECT COUNT(*) FROM #Timeline) = 0 THEN 1 ELSE 0 END
			
			-- The total number of items in this unit lease group chain should be 1 and there should be one termination stranded by itself,
			-- if the move-in or initial is being reversed by a DS or NS termination and there is no billing history, then that means that
			-- the deadzone for this unit lease group chain is essentially forever, there was never a valid move-in or initial because it 
			-- was reversed, there should be no other certifications in this unit lease group chain, because they have all been eliminated
			-- by the deadzone cut, the termination is now stranded by itself because it survived the deadzone cut

			-- Both the total count of all items in this unit lease group chain and the count of items in the chain that are DS/NS terminations should be 1
			SELECT @LonelyTermination = CASE WHEN (SELECT COUNT(*) FROM #UnitLeaseGroups WHERE UnitLeaseGroupCounter = @AdjustmentGroupCounter) =
												  (SELECT COUNT(*) 
												   FROM #UnitLeaseGroups ulg
												   INNER JOIN Certification c ON c.CertificationID = ulg.CertificationID 
												   WHERE ulg.UnitLeaseGroupCounter = @AdjustmentGroupCounter
													     AND c.[Type] = @TM
													     AND c.TerminationReason IN (@NoSubsidy, @DoubleSubsidy)) THEN 1 ELSE 0 END
			
			-- Maybe it has no billing history but it doesn't have a lonely termination, maybe it does have a termination but it does have some
			-- billing history that will need to be reversed, in these cases we'll continue, otherwise we can't just move onto the next unit lease group
			-- If both of these conditions are not true then for this entire unit lease group we're not going to do a single thing, there is no need
			-- to create any billing, pretty rare that both of these conditions would be false, probably never going to happen
			IF (@NoBillingHistory = 0 OR @LonelyTermination = 0)
			BEGIN

				/**** ------------------------------------------ Explanation of the 3 Timelines ------------------------------------------ ****/
				-- From this point on we're going to be dealing with a lot of different timelines (models), there are three main timelines:
					-- #1). #Timeline - shows a history of all billed instances, shows individual assistance payments and adjustments
					-- #2). #OrderedTimeline - shows a history of all certifications billed
					-- #3). #NewTimeline - shows a model of certifications to be involved in new billing
			
				-- The #Timeline is where we start, at this point in the sproc, it's already been constructed, the #Timeline shows a complete timeline
				-- of all current billing instances for this unit lease group chain, it is a timeline of all newly billed instances and forgets about
				-- the adjustments or assistance payments that were already reversed, everything on the #Timeline table could potentially be eligible to
				-- be reversed because none of the billing instances on that timeline have been reversed yet, they are all "fresh"

				-- The #OrderedTimeline views the billing history as a history of certifications that were billed, it forgets about individual billing instances
				-- and whether they were adjustments or assistance payments, it is a condescend view of the #timeline table because it merges billing instances for
				-- same certifications, for instance if there is an adjustment and an assistance payment for the same certification then those two rows on the #Timeline
				-- table would be condescened into a single row on the #OrderedTimeline table, viewing the billing history in this way helps us figure out how to reverse
				-- a certification that has been cut into by a backdated certification, this model is used to create the prior billing sections of adjustment groups

				-- The #NewTimeline is a model that helps to identify how the new certifications should be billed.  This model is then used to create the whole new billing
				-- section of adjustments, anything in this table that has an affordable submission item id needs to be a new billing not new cert adjustment, anything on
				-- this table that has a certification ID is a new certification that should be in the new billing new cert section of adjustments

				-- Only with these models is it possible to accurately construct the prior and new sections of adjustments, the real work of producing adjustments is in
				-- making sure that these models are accurate, as long as these models are correct then we can just print out results from the models to create adjustments

				/**** ------------------------------------------ Construct Ordered Timeline ------------------------------------------ ****/
				-- This could be done by making the first column of the timeline table an indentity column, then the int would just auto increment and 
				-- we wouldn't need a while loop doing this, however the problem is that you can't do updates on and identity column and later on this 
				-- sproc we update our first column to close gaps after we've delete a row or merged rows, so unfortunately we'll have to keep this while loop
				DECLARE	@OrderedTimelineTotal int,
						@OrderedCounter int = 0
				SELECT @OrderedTimelineTotal = COUNT(*) FROM #Timeline
				WHILE @OrderedTimelineTotal > @OrderedCounter
				BEGIN
					DECLARE @ThisTimelineItem uniqueidentifier
					SELECT @ThisTimelineItem = AffordableSubmissionItemID
					FROM #Timeline
					WHERE AffordableSubmissionItemID NOT IN (SELECT * FROM #TouchedTimelineItems)
					ORDER BY StartDate DESC
					-- Just pop everything in the #Timeline table into the ordered timeline, too bad we can't do this with an identity column
					INSERT INTO #OrderedTimeline
						SELECT @OrderedCounter AS 'Counter', 
							   t.StartDate AS 'StartDate', 
							   t.EndDate AS 'EndDate', 
							   t.AffordableSubmissionItemID AS 'AffordableSubmissionItemID', 
							   c.CertificationID AS 'CertificationID'
						FROM #Timeline t
						INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissionItemID = t.AffordableSubmissionItemID
						LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
						INNER JOIN Certification c ON c.CertificationID IN (ca.CertificationID, asi.ObjectID)
						WHERE t.AffordableSubmissionItemID = @ThisTimelineItem

					INSERT INTO #TouchedTimelineItems SELECT @ThisTimelineItem
					SELECT @OrderedCounter = @OrderedCounter + 1
				END
			
				TRUNCATE TABLE #TouchedTimelineItems

				/**** ------------------------------------------ Condense the Ordered Timeline ------------------------------------------ ****/
				-- This is where the ordered timeline takes on it's true form, we merge rows with the same certification ID, then we get the min
				-- and max for their start and end date, this transforms our #Timeline table which is just a table of all of the billing instances
				-- into a table that shows which certifications had their billing take up certain portions of time, it's just a different way to 
				-- look at the billing history, this model helps us figure out adjustment windows etc...
			
				-- Going to update all of the rows with the same certification ID
				UPDATE ot SET ot.StartDate = ot2.StartDate, ot.EndDate = ot3.EndDate
				FROM #OrderedTimeline ot
				-- Get the lowest start date for the certification
				INNER JOIN (SELECT MIN(StartDate) AS StartDate, CertificationID
							FROM #OrderedTimeline 
							GROUP BY CertificationID) AS ot2 ON ot2.CertificationID = ot.CertificationID
				-- Get the end date from the last row for the certification
				INNER JOIN #OrderedTimeline ot3 ON ot3.[Counter] = (SELECT TOP 1 [Counter]
																	FROM #OrderedTimeline
																	WHERE CertificationID = ot.CertificationID
																	ORDER BY [Counter] DESC)
				-- We updated all of the rows with the same certification ID, now all the rows with the same 
				-- certification ID except the first row are pretty much useless so let's get rid of them
				DELETE FROM #OrderedTimeline
				WHERE [Counter] IN (
					SELECT ot2.[Counter] 
					FROM #OrderedTimeline ot
					INNER JOIN #OrderedTimeline ot2 ON ot2.CertificationID = ot.CertificationID
					AND ot2.[Counter] <> (SELECT TOP 1 [Counter] 
										  FROM #OrderedTimeline ot3
										  WHERE ot3.CertificationID = ot.CertificationID
										  ORDER BY ot3.[Counter]))
			
				-- Fix the temp IDs so they're completely chronological
				-- Since we were merging items the counters may have gaps, if we merged
				-- 2 into 1 then there were be a row for 1 then the next row would be for 3
				-- let's close those gaps so we have no problems navigating the table
				-- Here we're updating the Counter column, if we weren't doing this
				-- then we could have just used an identity column for the counter
				DECLARE @OldTempCounter int = -1
				SELECT @OrderedTimelineTotal = COUNT(*) FROM #OrderedTimeline
				SELECT @OrderedCounter = 0
				WHILE @OrderedCounter < @OrderedTimelineTotal
				BEGIN
					SELECT TOP 1 @OldTempCounter = [Counter]
					FROM #OrderedTimeline
					WHERE [Counter] > @OldTempCounter
					ORDER BY [Counter] 
					-- The ordered counter is just a counter of the iterations of this while loop
					-- we now overwrite the ordered timeline counters with this counter, this will
					-- make sure that each row has a counter immediately following the previous value
					UPDATE #OrderedTimeline SET [Counter] = @OrderedCounter
					WHERE [Counter] = @OldTempCounter
					SELECT @OrderedCounter = @OrderedCounter + 1
				END

				-- Clean the ordered timeline
				UPDATE ot
				SET ot.EndDate = DATEADD(D, -1, ot2.StartDate)
				FROM #OrderedTimeline ot
				INNER JOIN #OrderedTimeline ot2 ON (ot.[Counter] + 1) = ot2.[Counter]

				/**** ------------------------------------------ XML Snapshot #6 - Ordered Timeline ------------------------------------------ ****/
				-- We're trying to send this submission right now so let's save our ordered timeline temp table in the activity log
				IF @sending = 1
				BEGIN
					SET @OrderedTimeline = (SELECT CONVERT(nvarchar(max), (SELECT * FROM #OrderedTimeline FOR XML RAW ('OrderedTimeline'), ROOT('OrderedTimelines'))))
					INSERT INTO ActivityLog (ActivityLogID, AccountID, ActivityLogType, ObjectName, ObjectID, Activity, [Timestamp], ExceptionCaught, Exception, IntegrationPartnerID)
						   VALUES (NEWID(), @accountID, @ActivityLogType, @ObjectName, @affordableSubmissionID, @OrderedTimelineActivity, SYSUTCDATETIME(), 
								   0, @OrderedTimeline, @AdjustmentGroupCounter)			   
				END

				/**** ------------------------------------------ Define Adjustment Window ------------------------------------------ ****/
				-- It's extremely important that we define the window of adjustment for this group of certifications, so many things are dependent
				-- on this window and it also helps us do a lot of fixing and tweaking of the timelines and adjustments, this is also used
				-- a lot for validating what we're doing, making sure our adjustment makes logical sense
				DECLARE @WindowStart datetime = NULL,
						@WindowEnd datetime = NULL

				-- There is no billing history for this unit lease group chain
				-- If there is no billing history for this unit lease group then we know that the start of the window must
				-- be the effective date of the earliest cert and it ends right before the voucher month
				IF (SELECT COUNT(*) FROM #Timeline) = 0
				BEGIN
					SELECT TOP 1 @WindowStart = c.EffectiveDate, @WindowEnd = DATEADD(D, -1, @voucherMonth)
					FROM #UnitLeaseGroups ulgs
					INNER JOIN #UnbilledCertifications c ON c.CertificationID = ulgs.CertificationID
					WHERE ulgs.UnitLeaseGroupCounter = @AdjustmentGroupCounter
					ORDER BY c.EffectiveDate
				END
				-- This group of certs does have some billing history
				ELSE
				BEGIN
					-- We need to find the earliest new cert we are going to be billing for and 
					-- the last cert that we are going to be doing new billing for
					DECLARE @EarliestCertEffDate datetime = NULL,
							@LatestCertID uniqueidentifier = NULL

					-- Find the earliest cert
					-- If it's a move-out or a termination then the adjustment actually starts taking place on the next day, other certifications
					-- it's fine to use the regular effective date
					SELECT @EarliestCertEffDate = MIN(CASE WHEN c.[Type] IN (@TM, @MO) AND correctionParent.CertificationID IS NULL THEN DATEADD(D, 1, c.EffectiveDate) 
														   ELSE ISNULL(correctionParent.EffectiveDate, c.EffectiveDate) END)
					FROM #UnitLeaseGroups ulg
					INNER JOIN #UnbilledCertifications c ON c.CertificationID = ulg.CertificationID
					LEFT OUTER JOIN Certification correctionParent ON correctionParent.CertificationID = (
						SELECT TOP 1 subC.CertificationID 
						FROM Certification subC
						LEFT OUTER JOIN CertificationAdjustment subCa ON subCa.CertificationID = subC.CertificationID 
						INNER JOIN AffordableSubmissionItem subAsi ON subAsi.ObjectID IN (subCa.CertificationAdjustmentID, subC.CertificationID)
						INNER JOIN AffordableSubmissionPayment subAsp ON subAsp.AffordableSubmissionID = subAsi.AffordableSubmissionID
						WHERE subC.CorrectedByCertificationID = c.CertificationID
							  AND subAsp.Code = @PaidByTreasuryCode
							  AND subC.EffectiveDate < c.EffectiveDate)
					WHERE ulg.UnitLeaseGroupCounter = @AdjustmentGroupCounter

					-- Find the last cert
					SELECT TOP 1 @LatestCertID = c.CertificationID
					FROM #UnitLeaseGroups ulg
					INNER JOIN #UnbilledCertifications c ON c.CertificationID = ulg.CertificationID
					WHERE ulg.UnitLeaseGroupCounter = @AdjustmentGroupCounter
					ORDER BY c.EffectiveDate DESC

					-- Find the previous billed instance where our earliest cert intersects, it could be intersecting a previous adjustment
					-- or assistance payment, in either case we need to know when the billing for that instance started
					SELECT @WindowStart = CASE WHEN asi.ObjectType = @Adjustment 
												-- If the beginning date is in the same month as the month of the effective date
												THEN CASE WHEN dbo.FirstOfMonth(ca.BeginningDate) = dbo.FirstOfMonth(@EarliestCertEffDate) 
															THEN ca.BeginningDate
															ELSE dbo.FirstOfMonth(@EarliestCertEffDate) END -- This else may be unnecessary, test this
												ELSE dbo.FirstOfMonth(@EarliestCertEffDate) END
					FROM #OrderedTimeline t
					INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissionItemID = t.AffordableSubmissionItemID
					LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
					WHERE t.StartDate <= @EarliestCertEffDate AND t.EndDate >= @EarliestCertEffDate

					-- Right off the bat, we know that if this is the last certification for this cert group chain, then it must not obey early stoppage
					-- and we should just be adjusting to the end of the month right before our voucher month
					DECLARE @LastCertIsRealLastCert bit = 0
					SELECT @LastCertIsRealLastCert = CASE WHEN realLastCert.CertificationID IS NULL THEN 1 
														  WHEN realLastCert.CertificationID = @LatestCertID THEN 1
														  ELSE 0 END
					FROM Certification c
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
					LEFT OUTER JOIN Certification realLastCert ON realLastCert.CertificationID = (
						SELECT TOP 1 subC.CertificationID
						FROM Certification subC
						INNER JOIN UnitLeaseGroup subUlg ON subUlg.UnitLeaseGroupID = subC.UnitLeaseGroupID
						INNER JOIN CertificationAffordableProgramAllocation subCapa ON subCapa.CertificationID = subC.CertificationID
						INNER JOIN AffordableSubmissionItem subAsi ON subAsi.ObjectID = subCapa.CertificationAffordableProgramAllocationID
						LEFT OUTER JOIN Certification correction ON correction.CertificationID = subC.CorrectedByCertificationID
						LEFT OUTER JOIN CertificationAffordableProgramAllocation correctionCapa ON correctionCapa.CertificationID = correction.CertificationID
						LEFT OUTER JOIN AffordableSubmissionItem correctionAsi ON correctionAsi.ObjectID = correctionCapa.CertificationAffordableProgramAllocationID
																				  AND correctionAsi.[Status] IN (@Sent, @Success, @CorrectionsNeeded)
						WHERE subAsi.[Status] IN (@Sent, @Success, @CorrectionsNeeded)
							  AND ISNULL(subUlg.TransferGroupID, subUlg.UnitLeaseGroupID) = ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID)
							  AND correctionAsi.AffordableSubmissionItemID IS NULL
						ORDER BY subC.EffectiveDate DESC)
					WHERE c.CertificationID = @LatestCertID

					IF @LastCertIsRealLastCert = 1
					BEGIN
						SET @WindowEnd = DATEADD(D, -1, @voucherMonth)
					END

					ELSE 
					BEGIN
						-- Checks for instances where early stoppage rule may be applicable, early stoppage means that we wouldn't keep adjusting
						-- until the last day of the previous month to our voucher month, most of the time we adjustment up until our voucher month,
						-- but sometimes that's not always necessary, those cases would be "early stoppage"
						SELECT @WindowEnd = t.EndDate
						FROM #OrderedTimeline t
						INNER JOIN #UnbilledCertifications lastCert ON lastCert.CertificationID = @LatestCertID
						LEFT OUTER JOIN Certification c ON c.CorrectedByCertificationID = lastCert.CertificationID
						-- Find the timeline item on which the last certification infringes upon
						WHERE t.StartDate <= ISNULL(c.EffectiveDate, lastCert.EffectiveDate) AND t.EndDate >= ISNULL(c.EffectiveDate, lastCert.EffectiveDate)
							  -- If the last cert was a move-out or termination then the adjustment window end should always be up until the voucher month
							  -- because we will need to claim that for up until our voucher month that there is no subsidy needed for this houshold
							  AND lastCert.[Type] NOT IN (@TM, @MO)
						-- Of course, this above query could return no results, it could fail to set the window end date, which is completely exceptable
						-- we have a catch later on that finds where this end date isn't set and then sets it to right before this voucher month which is correct
						-- really the above query just finds the instance of early stoppage only, if there was no early stopped then we just always use the date
						-- before our voucher month	

						-- Stop Bad Early Stoppage
						-- Here's a crazy situation, let's say that we have an interim certification on 11/18 and then a unit transfer on 11/22 and a 
						-- gross rent change on 11/25, both of these later certs (UT and GRC) are going to be changed to early certification dates, so 
						-- the new timeline would be UT 11/5, GRC 11/12, Interim 11/18, we're looking at the ordered timeline (the billing history) to
						-- find the last adjustment/assistance payment that our latest cert encroaches upon, the problem is that we may want to do early
						-- stoppage, but the cert that we're stopping at may be reversing order and come sooner, this would create a billing gap, in our
						-- above example, if there was a correction on the interim then we would do early stoppage so the last adjustment would be for the 
						-- interim for 11/18 - 11/22, but that 11/22 certification is going to be reversed, and then the interim needs to take over the billing
						-- for that time, the certs are basically trading times that they're qualified to bill
						-- The following query gets the last instance of a billing history item that has a current correction that is forcing it's effective
						-- date to be sooner than what we determined to be the last certification, this query essentially finds those billing gaps, and then 
						-- affects the window end date so we fill in that gap
						SELECT TOP 1 @WindowEnd = ISNULL(t2.EndDate, @WindowEnd) -- If we couldn't find a gap then just leave the window end alone
						FROM #OrderedTimeline t
						INNER JOIN #UnbilledCertifications lastCert ON lastCert.CertificationID = @LatestCertID
						-- Now join in the billing history items that are after the last item we thought we were encroaching on
						INNER JOIN #OrderedTimeline t2 ON t2.StartDate > t.StartDate 
						INNER JOIN Certification c ON c.CertificationID = t2.CertificationID
						-- Only care about billing history items that are being corrected right now
						INNER JOIN #UnbilledCertifications weirdCert ON c.CorrectedByCertificationID = weirdCert.CertificationID
						WHERE t.StartDate <= lastCert.EffectiveDate AND t.EndDate >= lastCert.EffectiveDate
								-- Even though the billing history item happens after the new effective date it's before the last cert effective date
								AND weirdCert.EffectiveDate < lastCert.EffectiveDate
						-- Just get the billing history item where this crap happens
						ORDER BY t2.StartDate DESC
					END
				END -- End of else statement for "This group of certs does have some billing history" 

				-- This just makes sure that we haven't made any critical mistakes
				IF @WindowStart IS NULL
				BEGIN
					SELECT @WindowStart = @EarliestCertEffDate
				END
				-- If there was no early stoppage then we can just always use the day before our voucher month
				IF @WindowEnd IS NULL
				BEGIN
					SELECT @WindowEnd = DATEADD(D, -1, @voucherMonth)
				END

				/**** ------------------------------------------ Create Prior Billing Section ------------------------------------------ ****/
				-- The ordered timeline is just a timeline of previous billing instances, the adjustment window shows us the timeframe in which
				-- new billing will take place, if there is any overlap of previously billed instances into our adjustment window then we know that
				-- we'll need to reverse them, so we use the following query to find all of the previously billed instances that will need to be reversed
				INSERT INTO #TimelineItemsToReverse
					SELECT AffordableSubmissionItemID 
					FROM #OrderedTimeline 
					WHERE EndDate >= @WindowStart
						  AND EndDate <= @WindowEnd
					ORDER BY StartDate

				-- Start looping through the previously billed instances that will need to be reversed
				WHILE (SELECT COUNT(*) FROM #TimelineItemsToReverse) > 0
				BEGIN
					DECLARE @ThisItem uniqueidentifier = NULL,
							@BeginningDate datetime = NULL,
							@EndingDate datetime = NULL
					SELECT TOP 1 @ThisItem = ItemID
					FROM #TimelineItemsToReverse

					-- Figure out what the next billed instance was, when we find that it will help us 
					-- define when we should stop reversing the billing for the current instance we're working on
					DECLARE @NextChronoItemStartDate datetime = NULL
					SELECT TOP 1 @NextChronoItemStartDate = StartDate 
					FROM #Timeline
					WHERE AffordableSubmissionItemID <> @ThisItem
						  AND AffordableSubmissionItemID IN (SELECT * FROM #TimelineItemsToReverse)
					ORDER BY StartDate 

					-- Now figure out the start and end date for what we're reversing
					SELECT @EndingDate = CASE WHEN (SELECT COUNT(*) FROM #TimelineItemsToReverse) = 1 
												THEN @WindowEnd 
												-- If there is another item to reverse, then we obviously know that this current item needs to 
												-- end right before that next one starts
												WHEN @NextChronoItemStartDate IS NOT NULL 
												THEN DATEADD(D, -1, @NextChronoItemStartDate) 
												ELSE EndDate END,
						   -- This is just doing some validation before we set the beginning date, just being safe 
						   @BeginningDate = CASE WHEN StartDate > @WindowStart THEN StartDate ELSE @WindowStart END
					FROM #Timeline 
					WHERE AffordableSubmissionItemID = @ThisItem

					-- Now we have all the information we need to actually create our first adjustment
					INSERT INTO #Adjustments 
						SELECT DISTINCT @AdjustmentGroupCounter AS 'GroupNumber', 
								NULL AS 'AdjustmentID',
								c.CertificationID AS 'CertificationID',
								ulg.UnitID AS 'UnitID',
								-- If we're reversing a previous adjustment then just use the same info that was on that adustment
								-- otherwise we're reversing an assistance payment and we should use the snapshot that was recorded
								-- when the certification was originally reported to HUD, of course, if this certification is a 
								-- partial certification then it won't have a snapshot so we have no choice but to use the current 
								-- information in ResMan
								COALESCE(ca.FirstName, certAsi.HeadOfHouseholdFirstName, p.FirstName) AS 'HoHFirstName',
								LEFT(COALESCE(ca.MiddleInitial, certAsi.HeadOfHouseholdMiddleName, p.MiddleName), 1) AS 'HoHMiddleInitial',
								COALESCE(ca.LastName, certAsi.HeadOfHouseholdLastname, p.LastName) AS 'HoHLastName',
								COALESCE(ca.UnitNumber, certAsi.UnitNumber, u.HudUnitNumber, u.Number) AS 'UnitNumber',
								-- We're only doing prior rows right now
								'Prior' AS 'PriorOrNewBilling',
								NULL AS 'NewCert',
								-- We have to translate our certification type into what will actually appear on the form
								-- if this is a correction, it will always be followed by an asterisk, the asterisk denotes a correction
								CASE c.[Type] 
									WHEN @IR THEN 'IR' WHEN @GR THEN 'GR' WHEN @AR THEN 'AR' 
									WHEN @UT THEN 'UT-O' WHEN @IC THEN 'IC' WHEN @MI THEN 'MI' 
									WHEN @MO THEN CASE WHEN (SELECT ReasonForLeaving
															 FROM PersonLease
															 WHERE PersonID = cp.PersonID
																   AND LeaseID = c.LeaseID) = @DeathOfSoleFamilyMember
													   THEN 'MO-D'
													   ELSE 'MO' END 
									WHEN @TM THEN CASE WHEN c.TerminationReason = @NoSubsidy THEN 'TM-N'
														WHEN c.TerminationReason = @DoubleSubsidy THEN 'TM-D'
														ELSE 'TM' END END
								+ CASE WHEN c.IsCorrection = 1 THEN '*' ELSE '' END AS 'CertType',
								-- Here we're using the effective date and we're not applying the death date rule, that's actually the way it's supposed to be
								-- on the adjustment forms we're supposed to still show the regular effective date, the death date rule just affects our 
								-- adjusting window start and end, on the form, the effective date field should be a the original effective date that they reported
								CASE WHEN c.[Type] = @UT THEN DATEADD(D, -1, c.EffectiveDate) ELSE c.EffectiveDate END AS 'EffectiveDate',
								-- If we're reversing any of the following types then we know that the assistance payment should be zero, of course with recent
								-- changes in ResMan the c.HUDassistancepayment may already be zero, but let's just force it to be 0 anyways
								CASE WHEN c.[Type] IN (@MO, @TM, @UT) THEN 0 ELSE c.HUDAssistancePayment END AS 'AssistancePayment',
								@BeginningDate AS 'BeginningDate',
								@EndingDate AS 'EndingDate',
								-- The rest of these fields we're going to get from our GetAdjustmentCalculationDetail Table Valued Function
								d.BeginningNoOfDays AS 'BeginningNoOfDays',
								d.BeginningDailyRate AS 'BeginningDailyRate',
								d.NoOfMonths AS 'NoOfMonths',
								d.MonthlyRate AS 'MonthlyRate',
								d.EndingNoOfDays AS 'EndingNoOfDays',
								d.EndingDailyRate AS 'EndingDailyRate',
								d.Amount AS 'Amount',
								NULL AS 'Requested',
								NULL AS 'Paid',
								u.PaddedNumber AS 'PaddedUnitNumber'
						FROM AffordableSubmissionItem asi 
						INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi.AffordableSubmissionID
						LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
						INNER JOIN Certification c ON c.CertificationID IN (asi.ObjectID, ca.CertificationID)
						INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
						-- Go find the affordable submission item where this certification was originally reported to HUD, if it's a full
						-- certification then it will have a snapshot of head of household information
						INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
						-- Remember that a certification can be sent as many times as the user wants so we could get multiple instances
						-- of when this certification was sent in, make sure it isn't the baseline one or an instance where the submission
						-- failed, still this doesn't filter out all redundant submissions, but at least it helps us better find
						-- the snapshot from a valid submission attempt
						INNER JOIN AffordableSubmissionItem certAsi ON certAsi.ObjectID = capa.CertificationAffordableProgramAllocationID
																	   AND certAsi.IsBaseline = 0
																	   AND certAsi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
						INNER JOIN Unit u ON u.UnitID = ulg.UnitID
						INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
						INNER JOIN Person p ON p.PersonID = cp.PersonID
						CROSS APPLY dbo.GetAdjustmentCalculationDetail(@BeginningDate, @EndingDate, c.HUDAssistancePayment, 
							CASE WHEN c.[Type] IN (@MO, @TM, @UT) THEN 0 ELSE 1 END, CASE WHEN c.[Type] IN (@MO, @TM, @UT) THEN 1 ELSE 0 END) AS d
						WHERE asi.AffordableSubmissionItemID = @ThisItem
							  AND cp.HouseholdStatus = @HeadOfHousehold

					DELETE FROM #TimelineItemsToReverse
					WHERE ItemID = @ThisItem
				END -- End of looping through all items to reverse, our prior section is now done for this unit lease group chain

				/**** ------------------------------------------ Compile New Timeline ------------------------------------------ ****/
				-- This takes the prior timeline and injects new certifications, it also clips the prior timeline and makes other changes
				-- Once finished this new timeline will be the model which will be used to create the new billing section

				-- The new timeline has the following structure (Counter int, StartDate, EndDate, AffordableSubmissionItemID, CertificationID)
				-- so at the end of this table we have two columns that could contain ids that we need, if there is a value in the affordable submission
				-- item ID column then that means that is represents a previously billed instance, if there is just a certification ID then that means
				-- that row is a new certification that we need to bill for, a single row can't have both a value for affordable submission item ID and
				-- certification ID, it must either be for previous billing or new billing, one or the other, but never both
				
				-- Any new timeline item that has an affordable submission item ID will become a new billing not new cert row, any new timeline item that
				-- has a certification ID will become a new billing new cert row

				-- Some new billing not new cert rows may just be here for the sake of filling in timeline gaps, really the next couple of steps really come
				-- down to a shuffle like as if a person where shuffling cards by just push two decks together, the two decks we're pushing together here are
				-- the old item on the ordered timeline that are in our adjustment window and then the other desk is our Unbilled Certification table, pushing
				-- these two things together gives us a timeline of the new billing, it doesn't leave any gaps, we could have any order or new cert or old cert,
				-- may have two new certs and then one old cert that we're just requesting a new amount for, could be any combination, depending on where all their
				-- dates fall

				-- Step #1). Insert the clipped old timeline into the new timeline
				INSERT INTO #NewTimeline
					SELECT NULL AS 'Counter', 
						   StartDate AS 'StartDate', 
						   EndDate AS 'EndDate', 
						   AffordableSubmissionItemID AS 'AffordableSubmissionIemID', 
						   NULL AS 'CertificationID'
					FROM #OrderedTimeline
					WHERE EndDate >= @WindowStart
						  AND EndDate <= @WindowEnd

				-- Step #2). Delete old items that have corrections in this voucher
				-- We know that their corrections will take their places in the next step
				DELETE FROM #NewTimeline
				WHERE AffordableSubmissionItemID IN (
					SELECT nt.AffordableSubmissionItemID
					FROM #NewTimeline nt
					-- First we need to find the certification for this billing item
					INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissionItemID = nt.AffordableSubmissionItemID
					LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
					INNER JOIN Certification c ON c.CertificationID IN (asi.ObjectID, ca.CertificationID)
					-- Now we need to find the tenant submission that this was sent on
					INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
					INNER JOIN AffordableSubmissionItem asi2 ON asi2.ObjectID = capa.CertificationAffordableProgramAllocationID
					INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi2.AffordableSubmissionID
					-- Now we need to find the certications on our new billing list that are in the same group and are the same type
					-- and the same effective date
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
					INNER JOIN #UnbilledCertifications ubc ON c.CorrectedByCertificationID = ubc.CertificationID
					-- Now figure out when that tenant submission was sent
					INNER JOIN CertificationAffordableProgramAllocation capa2 ON capa2.CertificationID = ubc.CertificationID
					INNER JOIN AffordableSubmissionItem asi3 ON asi3.ObjectID = capa2.CertificationAffordableProgramAllocationID
					INNER JOIN AffordableSubmission a3 ON a3.AffordableSubmissionID = asi3.AffordableSubmissionID
					-- The new billing certification should be submitted after the old billing item, it must be a correction then
					-- and must be further down the correction chain, since we enforce sending certifications in their chain order
					WHERE asi2.[Status] IN (@Sent, @Success, @CorrectionsNeeded)
						  AND asi2.IsBaseline = 0
						  AND asi3.[Status] IN (@Sent, @Success, @CorrectionsNeeded)
						  AND asi3.IsBaseline = 0)

				-- Step #3). Inject New Certifications
				-- Inject new certifications into the #NewTimeline, make sure that they don't fall into the deadzones that we
				-- already found a lot earlier in this same loop
				INSERT INTO #NewTimeline
					-- You may have noticed that we haven't even attempted putting in a value for the first column which is Counter,
					-- we're just going to re-adjust our timeline anyways in a little bit so there's no need to even to attempt to
					-- guess there order at this juncture
					SELECT NULL AS 'Counter', 
						   -- Terminations (not DS or NS) and move-outs start adjusting on the following day
						   CASE WHEN (c.[Type] = @MO OR (c.[Type] = @TM AND c2.TerminationReason NOT IN (@NoSubsidy, @DoubleSubsidy))) 
								THEN DATEADD(D, 1, c.EffectiveDate) ELSE c.EffectiveDate END AS 'StartDate', 
						   -- We're not going to attempt to put an end date in, we're going to basically order these items and then just
						   -- get the end date from the start date of the next chronological item, this way we're guaranteed to have a timeline
						   -- that has no gaps between items
						   NULL AS 'EndDate', 
						   NULL AS 'AffordableSubmissionItemID', 
						   ulgs.CertificationID AS 'CertificationID'
					FROM #UnitLeaseGroups ulgs
					INNER JOIN #UnbilledCertifications c ON c.CertificationID = ulgs.CertificationID
					INNER JOIN Certification c2 ON c2.CertificationID = c.CertificationID
					-- This better be null or it falls into a deadzone
					LEFT OUTER JOIN #Deadzones d ON d.Startdate < c.EffectiveDate AND d.EndDate > c.EffectiveDate
					WHERE ulgs.UnitLeaseGroupCounter = @AdjustmentGroupCounter
						  -- Make sure to snip off any new certifications that would be in a deadzone
					      -- If the certification is a move-in or initial then it doesn't really care above deadzones, because by
						  -- it's nature it can break a deadzone, despite this, this first part of the OR statement here
						  -- may be unecessary because the move-in or initial certs here should already be on the timeline
						  -- and should have created a section of time that isn't a deadzone, no harm in leaving this first part
						  -- of the OR statment in anyways
						  AND (c.[Type] IN (@MI, @IC) OR d.Startdate IS NULL)

				-- This is the only time we clear out the deadzone table, we won't use it in the rest of this while loop for this unit lease group chain
				TRUNCATE TABLE #Deadzones

				-- Step #4). Fill holes in the timeline
				DECLARE @WindowStartHole bit = 0
				SELECT @WindowStartHole = CASE WHEN (SELECT TOP 1 StartDate
													 FROM #NewTimeline
													 WHERE AffordableSubmissionItemID IS NULL 
													 ORDER BY StartDate) < @WindowStart
											   THEN 1 
											   ELSE 0 END

				IF @WindowStartHole = 1
				BEGIN

					DECLARE @EarliestTimelineMemberCertID uniqueidentifier = NULL
					SELECT TOP 1 @EarliestTimelineMemberCertID = CertificationID
					FROM #NewTimeline 
					ORDER BY StartDate

					INSERT INTO #NewTimeline
						SELECT NULL, 
							   @WindowStart, 
							   NULL, 
							   (SELECT TOP 1 ot.AffordableSubmissionItemID
								FROM #OrderedTimeline ot
								--LEFT OUTER JOIN Certification correctionParent ON correctionParent.CorrectedByCertificationID = ot.CertificationID
								WHERE ot.CertificationID <> @EarliestTimelineMemberCertID
									  AND StartDate < @WindowStart
									  --AND correctionParent.CertificationID IS NULL
								ORDER BY StartDate DESC), 
							   NULL

				END

				-- Clean the new timeline just in case
				DELETE FROM #NewTimeline 
				WHERE AffordableSubmissionItemID IS NULL AND CertificationID IS NULL

				-- Step #5). Assign Counters and End Dates to the New Timeline
				-- Up until this point we've just mushed two things together, our ordered timeline and our unbilled certification table, now we
				-- have to actually order them, and then simultaneously assign their end dates so that there are absolutely no gaps in our new timeline
				DECLARE @Counter int = 0,
						@TotalNewTimelineItems int = 0
				SELECT @TotalNewTimelineItems = COUNT(*) FROM #NewTimeline

				WHILE @Counter < @TotalNewTimelineItems
				BEGIN
					-- Pick an item we haven't worked with yet
					DECLARE @ThisID uniqueidentifier = NULL
					SELECT @ThisID = CASE WHEN AffordableSubmissionItemID IS NOT NULL THEN AffordableSubmissionItemID ELSE CertificationID END
					FROM #NewTimeline 
					WHERE [Counter] IS NULL
					ORDER BY StartDate DESC

					-- Update the counter, double check the start date, then find the next row's start date and use it to make our end date
					UPDATE nt SET [Counter] = @Counter,
								  -- Doing more validation with the adjustment window start date just to be safe
								  StartDate = CASE WHEN @WindowStart > nt.StartDate THEN @WindowStart ELSE nt.StartDate END,
								  -- the start date of the next item in the list
								  EndDate = ISNULL(DATEADD(D, -1, nt2.StartDate), @WindowEnd)
					FROM #NewTimeline nt
					-- The next item in the new timeline
					LEFT OUTER JOIN #NewTimeline nt2 ON nt2.StartDate = (SELECT MIN(StartDate) FROM #NewTimeline WHERE StartDate > nt.StartDate)
					-- This could have either of these ids, depending on where it came from
					WHERE nt.AffordableSubmissionItemID = @ThisID OR nt.CertificationID = @ThisID
					
					SELECT @Counter = @Counter + 1
				END

				-- Clean up the New Timeline
				DELETE FROM #NewTimeline 
				WHERE [Counter] IN (
					SELECT nt2.[Counter] FROM #NewTimeline nt
					INNER JOIN Certification c ON c.CertificationID = nt.CertificationID AND c.[Type] IN (@TM, @MO)
					INNER JOIN #NewTimeline nt2 ON nt2.[Counter] > nt.[Counter])

				DELETE FROM #NewTimeline
				WHERE [Counter] IN (
					SELECT nt.[Counter] FROM #NewTimeline nt
					INNER JOIN #NewTimeline nt2 ON nt2.StartDate = nt.StartDate AND nt2.EndDate = nt.EndDate AND nt2.AffordableSubmissionItemID IS NULL
					WHERE nt.CertificationID IS NULL )

				UPDATE nt
				SET nt.EndDate = @WindowEnd
				FROM #NewTimeline nt
				WHERE nt.[Counter] = (SELECT TOP 1 [Counter] FROM #NewTimeline ORDER BY [Counter] DESC) 

				/**** ------------------------------------------ XML Snapshot #7 - New Timeline ------------------------------------------ ****/
				-- We're trying to send this submission right now so let's save our new timeline temp table in the activity log
				IF @sending = 1
				BEGIN
					SET @NewTimeline = (SELECT CONVERT(nvarchar(max), (SELECT * FROM #NewTimeline FOR XML RAW ('NewTimeline'), ROOT('NewTimelines'))))
					INSERT INTO ActivityLog (ActivityLogID, AccountID, ActivityLogType, ObjectName, ObjectID, Activity, [Timestamp], ExceptionCaught, Exception, IntegrationPartnerID)
							VALUES (NEWID(), @accountID, @ActivityLogType, @ObjectName, @affordableSubmissionID, @NewTimelineActivity, SYSUTCDATETIME(), 
									0, @NewTimeline, @AdjustmentGroupCounter)			   
				END

				/**** ------------------------------------------ Create New Billing Section ------------------------------------------ ****/
				-- Now that we have the new timeline created, we should just be able to follow that model to compile the new billing section
				SELECT @Counter = 0

				-- Now we start looping through certification by certification for all certifications that need new billing
				WHILE @Counter < @TotalNewTimelineItems
				BEGIN
					DECLARE @Requested int = 0

					-- If this item on the #NewTimeline has an affordable submission item ID then it's a previously billed cert that needs a new amount
					IF (SELECT AffordableSubmissionItemID FROM #NewTimeline WHERE [Counter] = @Counter) IS NOT NULL
					BEGIN


						-- Is this a unit transfer correction that is trying to change the effective date to an earlier date, if so then we have
						-- to do some special logic, because it's going to try to create a new billing not new cert row for the unit transfer out
						-- and we don't want that
						DECLARE @WeirdoSituation bit = 0
						SELECT @WeirdoSituation = CASE WHEN weirdSituation.CertificationID IS NOT NULL THEN 1 ELSE 0 END
						FROM #NewTimeline nt
						INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissionItemID = nt.AffordableSubmissionItemID
						LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
						INNER JOIN Certification c ON c.CertificationID IN (ca.CertificationID, asi.ObjectID)
						LEFT OUTER JOIN Certification weirdSituation ON weirdSituation.CertificationID = (
							SELECT TOP 1 parentOfCorrection.CertificationID 
							FROM Certification parentOfCorrection
							LEFT OUTER JOIN CertificationAdjustment ca2 ON ca2.CertificationID = parentOfCorrection.CertificationID
							INNER JOIN AffordableSubmissionItem asi2 ON asi2.ObjectID IN (ca2.CertificationAdjustmentID, parentOfCorrection.CertificationID)
							INNER JOIN AffordableSubmissionpayment asp ON asp.AffordableSubmissionID = asi2.AffordableSubmissionID
																	  AND asp.Code = @PaidByTreasuryCode
							WHERE parentOfCorrection.CorrectedByCertificationID = c.CertificationID
								  AND parentOfCorrection.EffectiveDate < c.EffectiveDate
								  AND c.[Type] = @UT)
						WHERE nt.[Counter] = @Counter

						IF @WeirdoSituation = 1
						BEGIN

							-- Find the certification ID of the certification we're actually going to be billing for the period that is now uncovered
							-- because the effective date of the unit transfer is changing
							DECLARE @SwappingCertificationID uniqueidentifier = NULL
							SELECT @SwappingCertificationID = ot.CertificationID
							FROM #NewTimeline nt
							INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissionItemID = nt.AffordableSubmissionItemID
							LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
							INNER JOIN Certification c ON c.CertificationID IN (ca.CertificationID, asi.ObjectID)
							INNER JOIN #OrderedTimeline ot ON ot.StartDate < DATEADD(D, -1, c.EffectiveDate) AND ot.EndDate >= DATEADD(D, -1, c.EffectiveDate)
							WHERE nt.[Counter] = @Counter

							IF @SwappingCertificationID IS NULL 
							BEGIN
								SELECT @SwappingCertificationID = c.CertificationID
								FROM #NewTimeline nt
								INNER JOIN AffordableSubmissionItem asi ON asi.AffordableSubmissionItemID = nt.AffordableSubmissionItemID
								LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
								INNER JOIN Certification c ON c.CertificationID = ca.CertificationID
								WHERE nt.[Counter] = @Counter
							END

							INSERT INTO #Adjustments 
								SELECT DISTINCT ISNULL(@AdjustmentGroupCounterOverride, @AdjustmentGroupCounter) AS 'GroupNumber', 
										NULL AS 'AdjustmentID',
										@SwappingCertificationID AS 'CertificationID',
										ulg.UnitID AS 'UnitID',
										ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName) AS 'HoHFirstName',
										LEFT(ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName), 1) AS 'HoHMiddleInitial',
										ISNULL(certAsi.HeadofHouseholdLastName, p.LastName) AS 'HoHLastName',
										COALESCE(certAsi.UnitNumber, u.HudUnitNumber, u.Number) AS 'UnitNumber',
										'New' AS 'PriorOrNewBilling',
										NULL AS 'NewCert',
										CASE c.[Type]
											WHEN @IR THEN 'IR' WHEN @GR THEN 'GR' WHEN @AR THEN 'AR' 
											WHEN @UT THEN 'UT-I' WHEN @IC THEN 'IC' WHEN @MI THEN 'MI' 
											WHEN @MO THEN CASE WHEN (SELECT ReasonForLeaving
																	 FROM PersonLease
																	 WHERE PersonID = cp.PersonID
																		   AND LeaseID = c.LeaseID) = @DeathOfSoleFamilyMember
															   THEN 'MO-D'
															   ELSE 'MO' END 
											WHEN @TM THEN CASE WHEN c.TerminationReason = @NoSubsidy THEN 'TM-N'
																WHEN c.TerminationReason = @DoubleSubsidy THEN 'TM-D'
																ELSE 'TM' END END
										+ CASE WHEN c.IsCorrection = 1 THEN '*' ELSE '' END AS 'CertType',
										c.EffectiveDate AS 'EffectiveDate',
										c.HUDAssistancePayment AS 'AssistancePayment',
										t.StartDate AS 'BeginningDate',
										t.EndDate AS 'EndingDate',
										d.BeginningNoOfDays AS 'BeginningNoOfDays',
										d.BeginningDailyRate AS 'BeginningDailyRate',
										d.NoOfMonths AS 'NoOfMonths',
										d.MonthlyRate AS 'MonthlyRate',
										d.EndingNoOfDays AS 'EndingNoOfDays',
										d.EndingDailyRate AS 'EndingDailyRate',
										d.Amount AS 'Amount',
										NULL AS 'Requested',
										NULL AS 'Paid',
										u.PaddedNumber AS 'PaddedUnitNumber'
								FROM AffordableSubmissionItem asi 
								INNER JOIN #NewTimeline t ON t.AffordableSubmissionItemID = asi.AffordableSubmissionItemID
								INNER JOIN Certification c ON c.CertificationID = @SwappingCertificationID
								INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
								INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
								-- Now try to find the submission item of when this certification was originally sent in
								-- we'll need it to get the snapshot of the head of household and unit information that was sent
								-- Again, there could be several instances of when this cert was reported to HUD, so let's try to get one
								-- where it wasn't a baseline and it was successful
								LEFT OUTER JOIN AffordableSubmissionItem certAsi ON certAsi.ObjectID = capa.CertificationAffordableProgramAllocationID
																			   AND certAsi.IsBaseline = 0
																			   AND certAsi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
								INNER JOIN Unit u ON u.UnitID = ulg.UnitID
								INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
								INNER JOIN Person p ON p.PersonID = cp.PersonID
								CROSS APPLY dbo.GetAdjustmentCalculationDetail(t.StartDate, t.EndDate, c.HUDAssistancePayment, 0, 0) AS d
								WHERE t.[Counter] = @Counter
									  AND cp.HouseholdStatus = @HeadOfHousehold
						END -- End of the weirdo situation
						-- It's not a weird situation, do the new billing not new cert row as normal
						ELSE 
						BEGIN

							INSERT INTO #Adjustments 
								-- This is the first time that we're running into the counter override, up until this point that group counter
								-- has always been equal to the group counter that we have on the unit lease group table, the table that has the 
								-- certifications broken into chunks according to their unit lease group chains, but now we have the counter override
								-- which needs to exist when there is a unit transfer, if there was a unit transfer then we may have departed from using
								-- the counter that is given to us by the unit lease group table, the unit transfers may have created several new groups
								-- of adjustments, so if the override does exist that means that there must have been at least one unit transfer and we 
								-- need to use that group counter override instead
								SELECT DISTINCT ISNULL(@AdjustmentGroupCounterOverride, @AdjustmentGroupCounter) AS 'GroupNumber', 
										NULL AS 'AdjustmentID',
										c.CertificationID AS 'CertificationID',
										ulg.UnitID AS 'UnitID',
										-- In the previous insert that put a row into the adjustment table there were three places that we got potential head
										-- of household and unit data from, but on a new billing row we obviously don't have a previous billed instance that we
										-- could pull head of household or unit data from
										ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName) AS 'HoHFirstName',
										LEFT(ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName), 1) AS 'HoHMiddleInitial',
										ISNULL(certAsi.HeadofHouseholdLastName, p.LastName) AS 'HoHLastName',
										COALESCE(certAsi.UnitNumber, u.HudUnitNumber, u.Number) AS 'UnitNumber',
										'New' AS 'PriorOrNewBilling',
										NULL AS 'NewCert',
										CASE c.[Type]
											WHEN @IR THEN 'IR' WHEN @GR THEN 'GR' WHEN @AR THEN 'AR' 
											WHEN @UT THEN 'UT-I' WHEN @IC THEN 'IC' WHEN @MI THEN 'MI' 
											WHEN @MO THEN CASE WHEN (SELECT ReasonForLeaving
																		FROM PersonLease
																		WHERE PersonID = cp.PersonID
																			AND LeaseID = c.LeaseID) = @DeathOfSoleFamilyMember
																THEN 'MO-D'
																ELSE 'MO' END 
											WHEN @TM THEN CASE WHEN c.TerminationReason = @NoSubsidy THEN 'TM-N'
																WHEN c.TerminationReason = @DoubleSubsidy THEN 'TM-D'
																ELSE 'TM' END END
										+ CASE WHEN c.IsCorrection = 1 THEN '*' ELSE '' END AS 'CertType',
										-- Again we don't care about the death rule here, that's why it's okay to pull the effective date
										-- from the regular certification database record
										c.EffectiveDate AS 'EffectiveDate',
										c.HUDAssistancePayment AS 'AssistancePayment',
										t.StartDate AS 'BeginningDate',
										t.EndDate AS 'EndingDate',
										d.BeginningNoOfDays AS 'BeginningNoOfDays',
										d.BeginningDailyRate AS 'BeginningDailyRate',
										d.NoOfMonths AS 'NoOfMonths',
										d.MonthlyRate AS 'MonthlyRate',
										d.EndingNoOfDays AS 'EndingNoOfDays',
										d.EndingDailyRate AS 'EndingDailyRate',
										d.Amount AS 'Amount',
										NULL AS 'Requested',
										NULL AS 'Paid',
										u.PaddedNumber AS 'PaddedUnitNumber'
								FROM AffordableSubmissionItem asi 
								INNER JOIN #NewTimeline t ON t.AffordableSubmissionItemID = asi.AffordableSubmissionItemID
								INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = asi.AffordableSubmissionID
								LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationAdjustmentID = asi.ObjectID
								-- The NewTimeline table has a column for certification ID but for these new billing not new cert rows
								-- that column should always be blank so unfortunately we'll have to hunt for the certification by doing
								-- all these joins
								INNER JOIN Certification c ON c.CertificationID IN (asi.ObjectID, ca.CertificationID)
								INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
								INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
								-- Now try to find the submission item of when this certification was originally sent in
								-- we'll need it to get the snapshot of the head of household and unit information that was sent
								-- Again, there could be several instances of when this cert was reported to HUD, so let's try to get one
								-- where it wasn't a baseline and it was successful
								LEFT OUTER JOIN AffordableSubmissionItem certAsi ON certAsi.ObjectID = capa.CertificationAffordableProgramAllocationID
																				AND certAsi.IsBaseline = 0
																				AND certAsi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
								INNER JOIN Unit u ON u.UnitID = ulg.UnitID
								INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
								INNER JOIN Person p ON p.PersonID = cp.PersonID
								CROSS APPLY dbo.GetAdjustmentCalculationDetail(t.StartDate, t.EndDate, c.HUDAssistancePayment, 0, 0) AS d
								WHERE t.[Counter] = @Counter
									  AND cp.HouseholdStatus = @HeadOfHousehold
									  AND t.EndDate <= @WindowEnd
						END
					END
					ELSE 
					-- New Billing New Cert
					BEGIN
						-- We have to figure out if this is a unit transfer cert because if it is then it has completely unique logic
						DECLARE @UnitTransfer bit = 0
						SELECT @UnitTransfer = CASE WHEN c.[Type] = @UT THEN 1 ELSE 0 END
						FROM Certification c
						INNER JOIN #NewTimeline t ON t.CertificationID = c.CertificationID
						WHERE t.[Counter] = @Counter

						-- It's not a unit transfer, thank heaven
						IF @UnitTransfer = 0
						BEGIN
							INSERT INTO #Adjustments 
								SELECT DISTINCT ISNULL(@AdjustmentGroupCounterOverride, @AdjustmentGroupCounter) AS 'GroupNumber', 
									   NULL AS 'AdjustmentID',
									   c.CertificationID AS 'CertificationID',
									   ulg.UnitID AS 'UnitID',
									   ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName) AS 'HoHFirstName',
									   LEFT(ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName), 1) AS 'HoHMiddleInitial',
									   ISNULL(certAsi.HeadofHouseholdLastName, p.LastName) AS 'HoHLastName',
									   COALESCE(certAsi.UnitNumber, u.HudUnitNumber, u.Number) AS 'UnitNumber',
									   'New' AS 'PriorOrNewBilling',
									   'Y' AS 'NewCert',
									   CASE c.[Type] 
											WHEN @IR THEN 'IR' WHEN @GR THEN 'GR' WHEN @AR THEN 'AR' 
											WHEN @UT THEN 'UT-O' WHEN @IC THEN 'IC' WHEN @MI THEN 'MI' 
											WHEN @MO THEN CASE WHEN (SELECT ReasonForLeaving
																	 FROM PersonLease
																	 WHERE PersonID = cp.PersonID
																		   AND LeaseID = c.LeaseID) = @DeathOfSoleFamilyMember
															   THEN 'MO-D'
															   ELSE 'MO' END 
											WHEN @TM THEN CASE WHEN c.TerminationReason = @NoSubsidy THEN 'TM-N'
																WHEN c.TerminationReason = @DoubleSubsidy THEN 'TM-D'
																ELSE 'TM' END END
									   + CASE WHEN c.IsCorrection = 1 THEN '*' ELSE '' END AS 'CertType',
									   -- We don't want the altered effective date if the death date rule applies, we just want the regular
									   -- certification effective date that was reported to HUD
									   c.EffectiveDate AS 'EffectiveDate',
									   CASE WHEN c.[Type] IN (@MO, @TM) THEN 0 ELSE c.HUDAssistancePayment END AS 'AssistancePayment',
									   t.StartDate AS 'BeginningDate',
									   t.EndDate AS 'EndingDate',
									   d.BeginningNoOfDays AS 'BeginningNoOfDays',
									   d.BeginningDailyRate AS 'BeginningDailyRate',
									   d.NoOfMonths AS 'NoOfMonths',
									   d.MonthlyRate AS 'MonthlyRate',
									   d.EndingNoOfDays AS 'EndingNoOfDays',
									   d.EndingDailyRate AS 'EndingDailyRate',
									   d.Amount AS 'Amount',
									   NULL AS 'Requested',
									   NULL AS 'Paid',
									   u.PaddedNumber AS 'PaddedUnitNumber'
								FROM #NewTimeline t
								INNER JOIN Certification c ON c.CertificationID = t.CertificationID
								INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
								INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
								INNER JOIN AffordableSubmissionItem certAsi ON certAsi.ObjectID = capa.CertificationAffordableProgramAllocationID
																			   AND certAsi.IsBaseline = 0
																			   AND certAsi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
								INNER JOIN Unit u ON u.UnitID = ulg.UnitID
								INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
								INNER JOIN Person p ON p.PersonID = cp.PersonID
								CROSS APPLY dbo.GetAdjustmentCalculationDetail(t.StartDate, t.EndDate, c.HUDAssistancePayment, 0,
									CASE WHEN c.[Type] IN (@MO, @TM) THEN 1 ELSE 0 END) AS d
								WHERE t.[Counter] = @Counter
									  AND cp.HouseholdStatus = @HeadOfHousehold

						END
						-- This is a new unit transfer, hold on we're about to go off the rails
						ELSE
						BEGIN
							/**** ------------------------------------------ Unit Transfer Special Logic ------------------------------------------ ****/
							-- We've hit a unit transfer which means that we need to create a unit transfer out row (UT-O) out of thin air, then we need to end
							-- the current adjustment group, we may need to create a UT-I correction adjustment group if this unit transfer is a correction
							-- We also need to create the regular UT-I row in a new adjustment group, after we do all of this we can return to our normal
							-- programming and we can continue looping through our new timeline certifications, one thing to make note of is that this may
							-- not be the first time in this unit lease group chain that we've encountered a unit transfer, this may be the second or third
							-- new unit transfer in which case we will just continue incrementing the adjustment group counter override etc...
							-- Otherwise if this is the first time that we've encountered a unit transfer from this point on the @AdjustmentGroupCounter is
							-- no longer an accurate counter for the groups in the adjustment table, from this point on we're going to have to use the 
							-- override value instead

							DECLARE @FullCertTypes StringCollection
							INSERT @FullCertTypes SELECT @MI
							INSERT @FullCertTypes SELECT @IC
							INSERT @FullCertTypes SELECT @IR
							INSERT @FullCertTypes SELECT @AR

							-- Step #1). Create a UT-O row out of thin air that wraps up this section
							INSERT INTO #Adjustments 
								SELECT DISTINCT ISNULL(@AdjustmentGroupCounterOverride, @AdjustmentGroupCounter) AS 'GroupNumber', 
									   NULL AS 'AdjustmentID',
									   c.CertificationID AS 'CertificationID',
									   -- We're creating this adjustment based on the unit transfer in ResMan which is really just a 
									   -- UT-I adjustment row, what we're working on right now is the UT-O row, which should actually
									   -- have information from the previous unit that this household used to live in, so it's weird
									   -- because some of the certification information comes from the unit transfer certification,
									   -- and other parts of our data will have to come from other sources, below is a perfect example,
									   -- the unit ID is really the unit ID of were the household used to live not the unit ID that is
									   -- associate to this certification because this certification should be attached to the new unit
									   -- and the new lease, etc
									   -- The first place that we're going to try to get data from is from what we can calculate is the last
									   -- certification in the previous unit lease group, if that fails then we can try another strategy
									   -- of just looking at our adjustment table and stealing information from a previous row, if there even
									   -- is a previous row, there may not be, if neither of these tricks works then this sproc will crash
									   -- and we'll fail but both attempts should not fail, really there should pretty much never be a situation
									   -- in which the first part in the is null is actually null, HUD is validating all of these certifications
									   -- as we go, the only way for the first part of this is null to fail is if the property has some corrupted data
									   ISNULL(prevUlg.UnitID, 
											  (SELECT TOP 1 UnitID FROM #Adjustments
											   WHERE RowNumber < (SELECT MAX(RowNumber) FROM #Adjustments)
											   ORDER BY RowNumber DESC)) AS 'UnitID',
									   ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName) AS 'HoHFirstName',
									   LEFT(ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName), 1) AS 'HoHMiddleInitial',
									   ISNULL(certAsi.HeadofHouseholdLastName, p.LastName) AS 'HoHLastName',
									   COALESCE(prevUnit.HudUnitNumber, prevUnit.Number, 
											  (SELECT TOP 1 UnitNumber FROM #Adjustments
											   WHERE RowNumber < (SELECT MAX(RowNumber) FROM #Adjustments)
											   ORDER BY RowNumber DESC)) AS 'UnitNumber',
									   'New' AS 'PriorOrNewBilling',
									   'Y' AS 'NewCert',
									   CASE WHEN c.IsCorrection = 1 THEN 'UT-O*' ELSE 'UT-O' END AS 'CertType',
									   DATEADD(D, -1, c.EffectiveDate) AS 'EffectiveDate',
									   0 AS 'AssistancePayment',
									   c.EffectiveDate AS 'BeginningDate',
									   @WindowEnd AS 'EndingDate',
									   d.BeginningNoOfDays AS 'BeginningNoOfDays',
									   d.BeginningDailyRate AS 'BeginningDailyRate',
									   d.NoOfMonths AS 'NoOfMonths',
									   d.MonthlyRate AS 'MonthlyRate',
									   d.EndingNoOfDays AS 'EndingNoOfDays',
									   d.EndingDailyRate AS 'EndingDailyRate',
									   d.Amount AS 'Amount',
									   NULL AS 'Requested',
									   NULL AS 'Paid',
									   u.PaddedNumber AS 'PaddedUnitNumber'
								FROM #NewTimeline t
								INNER JOIN Certification c ON c.CertificationID = t.CertificationID
								INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
								INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
								INNER JOIN AffordableSubmissionItem certAsi ON certAsi.ObjectID = capa.CertificationAffordableProgramAllocationID
																			   AND certAsi.IsBaseline = 0
																			   AND certAsi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
								INNER JOIN Unit u ON u.UnitID = ulg.UnitID
								INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
								INNER JOIN Person p ON p.PersonID = cp.PersonID
								CROSS APPLY dbo.GetAdjustmentCalculationDetail(c.EffectiveDate, @WindowEnd, 0, 0, 1) AS d
								-- Now try to find the previous cert
								LEFT OUTER JOIN Certification prevCert ON prevCert.CertificationID = (
									SELECT dbo.GetPreviousCertificationID(@accountID, c.UnitLeaseGroupID, NULL, c.CertificationID, @FullCertTypes, 1, 1))
								LEFT OUTER JOIN UnitLeaseGroup prevUlg ON prevUlg.UnitLeaseGroupID = prevCert.UnitLeaseGroupID
								LEFT OUTER JOIN Unit prevUnit ON prevUnit.UnitID = prevUlg.UnitID
								WHERE t.[Counter] = @Counter
									  AND cp.HouseholdStatus = @HeadOfHousehold

							-- We're done with an adjustment group so we need to calculated it's requested column amount,
							-- this is just part of the normal routine of wrapping up an adjustment section, typically this occurs
							-- in our regular while loop after we finish a unit lease group chain, we have to put it in here,
							-- since we've going away from our unit lease group chains
							SELECT @Requested = SUM(Amount) FROM #Adjustments 
							WHERE GroupNumber = ISNULL(@AdjustmentGroupCounterOverride, @AdjustmentGroupCounter)
							UPDATE #Adjustments SET Requested = @Requested
							WHERE RowNumber = (SELECT MAX(RowNumber) FROM #Adjustments WHERE CertificationID IS NOT NULL)

							-- Whatever we do next is going to be in a new section with an overriden adjustment group ID
							IF @AdjustmentGroupCounterOverride IS NULL 
							BEGIN
								-- This is the first time we've encountered the override so we have to set it
								SELECT @AdjustmentGroupCounterOverride = MAX(UnitLeaseGroupCounter) + 1 FROM #UnitLeaseGroups
							END
							ELSE
							BEGIN
								SET @AdjustmentGroupCounterOverride = @AdjustmentGroupCounterOverride + 1
							END

							DECLARE @UnitTransferEndingDate datetime = NULL
							SELECT @UnitTransferEndingDate = ot.EndDate
							FROM #NewTimeline nt
							INNER JOIN Certification correction ON correction.CorrectedByCertificationID = nt.CertificationID
							INNER JOIN Certification c ON c.CertificationID = nt.CertificationID
							INNER JOIN #OrderedTimeline ot ON ot.CertificationID = ISNULL(correction.CertificationID, c.CertificationID)
							WHERE nt.[Counter] = @Counter 

							-- Step #2). Create the prior row for the unit transfer correction, now we're in another adjustment group
							-- This entire insert statement may never happen because there is no correction, we inner join on the correction
							-- so if there is no correction then this insert will do nothing
							INSERT INTO #Adjustments 
								SELECT DISTINCT @AdjustmentGroupCounterOverride AS 'GroupNumber', -- We know it's going to be the override
									   NULL AS 'AdjustmentID',
									   c.CertificationID AS 'CertificationID',
									   ulg.UnitID AS 'UnitID',
									   COALESCE(ca.FirstName, certAsi.HeadOfHouseholdFirstName, p.FirstName) AS 'HoHFirstName',
									   LEFT(COALESCE(ca.MiddleInitial, certAsi.HeadOfHouseholdMiddleName, p.MiddleName), 1) AS 'HoHMiddleInitial',
									   COALESCE(ca.LastName, certAsi.HeadofHouseholdLastName, p.LastName) AS 'HoHLastName',
									   COALESCE(ca.UnitNumber, certAsi.UnitNumber, u.HudUnitNumber, u.Number) AS 'UnitNumber',
									   'Prior' AS 'PriorOrNewBilling',
									   NULL AS 'NewCert',
									   CASE WHEN IsCorrection = 1 THEN 'UT-I*' ELSE 'UT-I' END AS 'CertType',
									   c.EffectiveDate AS 'EffectiveDate',
									   c.HUDAssistancePayment AS 'AssistancePayment',
									   -- We're either trying to reverse an adjustment or an assistance payment, if there is an adjustment
									   -- then that definitely takes precedent, it's going to be more recent than an assistance payment
									   -- the is null should work just fine here without hitch
									   ISNULL(ca.BeginningDate, a.StartDate) AS 'BeginningDate',
									   COALESCE(@UnitTransferEndingDate, ca.EndingDate, EOMONTH(a.StartDate)) AS 'EndingDate',
									   d.BeginningNoOfDays AS 'BeginningNoOfDays',
									   d.BeginningDailyRate AS 'BeginningDailyRate',
									   d.NoOfMonths AS 'NoOfMonths',
									   d.MonthlyRate AS 'MonthlyRate',
									   d.EndingNoOfDays AS 'EndingNoOfDays',
									   d.EndingDailyRate AS 'EndingDailyRate',
									   d.Amount AS 'Amount',
									   NULL AS 'Requested',
									   NULL AS 'Paid',
									   u.PaddedNumber AS 'PaddedUnitNumber'
								FROM #NewTimeline t
								INNER JOIN Certification c ON c.CorrectedByCertificationID = t.CertificationID
								INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
								-- Maybe it's an adjustment
								LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationID = c.CertificationID
								-- Maybe it's an assistance payment
								LEFT OUTER JOIN AffordableSubmissionItem ap ON ap.ObjectID = c.CertificationID
								LEFT OUTER JOIN AffordableSubmission a ON a.AffordableSubmissionID = ap.AffordableSubmissionID
								INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
								INNER JOIN AffordableSubmissionItem certAsi ON certAsi.ObjectID = capa.CertificationAffordableProgramAllocationID
																			   AND certAsi.IsBaseline = 0
																			   AND certAsi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
								INNER JOIN Unit u ON u.UnitID = ulg.UnitID
								INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
								INNER JOIN Person p ON p.PersonID = cp.PersonID
								CROSS APPLY dbo.GetAdjustmentCalculationDetail(ISNULL(ca.BeginningDate, a.StartDate), 
											COALESCE(@UnitTransferEndingDate, ca.EndingDate, EOMONTH(a.StartDate)), c.HUDAssistancePayment, 1, 0) AS d
								WHERE ca.NewCert = 1 AND ca.CertType IN ('UT-I', 'UT-I*')
									  AND t.[Counter] = @Counter 
									  AND (ca.CertificationAdjustmentID IS NOT NULL OR a.AffordableSubmissionID IS NOT NULL)
									  AND cp.HouseholdStatus = @HeadOfHousehold

							-- Now it's time to make the new billing not new cert row for the unit transfer correction
							-- Again this whole insert may do nothing if there is no correction, the inner join to the correction
							-- will make sure of that
							INSERT INTO #Adjustments 
								SELECT DISTINCT @AdjustmentGroupCounterOverride AS 'GroupNumber', -- We know it's going to be the override
									   NULL AS 'AdjustmentID',
									   c.CertificationID AS 'CertificationID',
									   ulg.UnitID AS 'UnitID',
									   ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName) AS 'HoHFirstName',
									   LEFT(ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName), 1) AS 'HoHMiddleInitial',
									   ISNULL(certAsi.HeadofHouseholdLastName, p.LastName) AS 'HoHLastName',
									   COALESCE(certAsi.UnitNumber, u.HudUnitNumber, u.Number) AS 'UnitNumber',
									   'New' AS 'PriorOrNewBilling',
									   NULL AS 'NewCert',
									   CASE WHEN IsCorrection = 1 THEN 'UT-I*' ELSE 'UT-I' END AS 'CertType',
									   c.EffectiveDate AS 'EffectiveDate',
									   0 AS 'AssistancePayment',
									   -- We're either trying to reverse an adjustment or an assistance payment, if there is an adjustment
									   -- then that definitely takes precedent, it's going to be more recent than an assistance payment
									   -- the is null should work just fine here without hitch
									   ISNULL(ca.BeginningDate, a.StartDate) AS 'BeginningDate',
									   COALESCE(@UnitTransferEndingDate, ca.EndingDate, EOMONTH(a.StartDate)) AS 'EndingDate',
									   d.BeginningNoOfDays AS 'BeginningNoOfDays',
									   d.BeginningDailyRate AS 'BeginningDailyRate',
									   d.NoOfMonths AS 'NoOfMonths',
									   d.MonthlyRate AS 'MonthlyRate',
									   d.EndingNoOfDays AS 'EndingNoOfDays',
									   d.EndingDailyRate AS 'EndingDailyRate',
									   d.Amount AS 'Amount',
									   NULL AS 'Requested',
									   NULL AS 'Paid',
									   u.PaddedNumber AS 'PaddedUnitNumber'
								FROM #NewTimeline t
								INNER JOIN Certification c ON c.CorrectedByCertificationID = t.CertificationID
								INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
								-- Maybe it's an adjustment
								LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationID = c.CertificationID
								-- Maybe it's an assistance payment
								LEFT OUTER JOIN AffordableSubmissionItem ap ON ap.ObjectID = c.CertificationID
								LEFT OUTER JOIN AffordableSubmission a ON a.AffordableSubmissionID = ap.AffordableSubmissionID
								INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
								INNER JOIN AffordableSubmissionItem certAsi ON certAsi.ObjectID = capa.CertificationAffordableProgramAllocationID
																			   AND certAsi.IsBaseline = 0
																			   AND certAsi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
								INNER JOIN Unit u ON u.UnitID = ulg.UnitID
								INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
								INNER JOIN Person p ON p.PersonID = cp.PersonID
								CROSS APPLY dbo.GetAdjustmentCalculationDetail(ISNULL(ca.BeginningDate, a.StartDate), 
											COALESCE(@UnitTransferEndingDate, ca.EndingDate, EOMONTH(a.StartDate)), c.HUDAssistancePayment, 0, 1) AS d
								WHERE ca.NewCert = 1 AND ca.CertType IN ('UT-I', 'UT-I*')
									  AND t.[Counter] = @Counter
									  AND cp.HouseholdStatus = @HeadOfHousehold 

							-- Now we can wrap up this group
							UPDATE #Adjustments SET Requested = (SELECT SUM(Amount) FROM #Adjustments WHERE GroupNumber = @AdjustmentGroupCounterOverride)
							WHERE RowNumber = (SELECT MAX(RowNumber) FROM #Adjustments WHERE CertificationID IS NOT NULL)
								  AND Requested IS NULL

							INSERT INTO #Adjustments
								SELECT @AdjustmentGroupCounterOverride AS 'GroupNumber', 
										NULL AS 'AdjustmentID',
										NULL AS 'CertificationID',
										NULL AS 'UnitID',
										NULL AS 'HoHFirstName',
										NULL AS 'HoHMiddleInitial',
										NULL AS 'HoHLastName',
										NULL AS 'UnitNumber',
										NULL AS 'PriorOrNewBilling',
										NULL AS 'NewCert',
										NULL AS 'CertType',
										NULL AS 'EffectiveDate',
										NULL AS 'AssistancePayment',
										NULL AS 'BeginningDate',
										NULL AS 'EndingDate',
										NULL AS 'BeginningNoOfDays',
										NULL AS 'BeginningDailyRate',
										NULL AS 'NoOfMonths',
										NULL AS 'MonthlyRate',
										NULL AS 'EndingNoOfDays',
										NULL AS 'EndingDailyRate',
										NULL AS 'Amount',
										NULL AS 'Requested',
										NULL AS 'Paid',
										NULL AS 'PaddedUnitNumber'

							-- Last thing we need to do is increment the override again, because the next group will need it
							SELECT @AdjustmentGroupCounterOverride = @AdjustmentGroupCounterOverride + 1

							-- Step #3). Create a UT-I row in a new adjustment group
							-- After this, our unit transfer disruptions are over and we'll be able to return to normal looping through
							-- other certifications
							INSERT INTO #Adjustments 
									SELECT DISTINCT @AdjustmentGroupCounterOverride AS 'GroupNumber', -- We know it's going to be the override
										   NULL AS 'AdjustmentID',
										   c.CertificationID AS 'CertificationID',
										   ulg.UnitID AS 'UnitID',
										   ISNULL(certAsi.HeadOfHouseholdFirstName, p.FirstName) AS 'HoHFirstName',
										   LEFT(ISNULL(certAsi.HeadOfHouseholdMiddleName, p.MiddleName), 1) AS 'HoHMiddleInitial',
										   ISNULL(certAsi.HeadofHouseholdLastName, p.LastName) AS 'HoHLastName',
										   COALESCE(certAsi.UnitNumber, u.HudUnitNumber, u.Number) AS 'UnitNumber',
										   'New' AS 'PriorOrNewBilling',
										   'Y' AS 'NewCert',
										   CASE WHEN IsCorrection = 1 THEN 'UT-I*' ELSE 'UT-I' END AS 'CertType',
										   c.EffectiveDate AS 'EffectiveDate',
										   c.HUDAssistancePayment AS 'AssistancePayment',
										   t.StartDate AS 'BeginningDate',
										   t.EndDate AS 'EndingDate',
										   d.BeginningNoOfDays AS 'BeginningNoOfDays',
										   d.BeginningDailyRate AS 'BeginningDailyRate',
										   d.NoOfMonths AS 'NoOfMonths',
										   d.MonthlyRate AS 'MonthlyRate',
										   d.EndingNoOfDays AS 'EndingNoOfDays',
										   d.EndingDailyRate AS 'EndingDailyRate',
										   d.Amount AS 'Amount',
										   NULL AS 'Requested',
										   NULL AS 'Paid',
										   u.PaddedNumber AS 'PaddedUnitNumber'
									FROM #NewTimeline t
									INNER JOIN Certification c ON c.CertificationID = t.CertificationID
									INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
									INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
									INNER JOIN AffordableSubmissionItem certAsi ON certAsi.ObjectID = capa.CertificationAffordableProgramAllocationID
																				   AND certAsi.IsBaseline = 0
																				   AND certAsi.[Status] IN (@Sent, @CorrectionsNeeded, @Success)
									INNER JOIN Unit u ON u.UnitID = ulg.UnitID
									INNER JOIN CertificationPerson cp ON cp.CertificationID = c.CertificationID
									INNER JOIN Person p ON p.PersonID = cp.PersonID
									CROSS APPLY dbo.GetAdjustmentCalculationDetail(t.StartDate, t.EndDate, c.HUDAssistancePayment, 0, 0) AS d
									WHERE t.[Counter] = @Counter
										  AND cp.HouseholdStatus = @HeadOfHousehold

						END -- The end of our special unit transfer logic

						-- Step #4). Return to normal looping through the new timeline, we're done creating unit transfer rows out of thin air
						-- Add our blank space row just once
						IF @AdjustmentGroupCounterOverride IS NOT NULL AND (SELECT COUNT(*) FROM #Adjustments WHERE GroupNumber = @AdjustmentGroupCounterOverride AND RowNumber IS NULL) = 0
						BEGIN
							INSERT INTO #Adjustments
							SELECT @AdjustmentGroupCounterOverride AS 'GroupNumber', 
									NULL AS 'AdjustmentID',
									NULL AS 'CertificationID',
									NULL AS 'UnitID',
									NULL AS 'HoHFirstName',
									NULL AS 'HoHMiddleInitial',
									NULL AS 'HoHLastName',
									NULL AS 'UnitNumber',
									NULL AS 'PriorOrNewBilling',
									NULL AS 'NewCert',
									NULL AS 'CertType',
									NULL AS 'EffectiveDate',
									NULL AS 'AssistancePayment',
									NULL AS 'BeginningDate',
									NULL AS 'EndingDate',
									NULL AS 'BeginningNoOfDays',
									NULL AS 'BeginningDailyRate',
									NULL AS 'NoOfMonths',
									NULL AS 'MonthlyRate',
									NULL AS 'EndingNoOfDays',
									NULL AS 'EndingDailyRate',
									NULL AS 'Amount',
									NULL AS 'Requested',
									NULL AS 'Paid',
									NULL AS 'PaddedUnitNumber'
						END

					END -- End of New Billing New Cert section

					-- Prepare for the next iteration
					SELECT @Counter = @Counter + 1

					-- There should never be any adjustments where a unit transfer out row in the new section has a greater amount than 0
					-- This happens when we are using unit transfers to fill in gaps in our billing timeline, this is just a sloppy solution
					-- that removes these rows, of course if we remove these rows then we are creating a gap in our billing timeline, this gap
					-- will be fixed later on when we clean up our result set, there is probably a better solution than this, but do you want
					-- to take the time to change the way we do the models to fix this?  ... yeah I didn't think so
					DELETE FROM #Adjustments
					WHERE GroupNumber = ISNULL(@AdjustmentGroupCounterOverride, @AdjustmentGroupCounter)
						  AND CertType IN ('UT-O*', 'UT-O')
						  AND PriorOrNewBilling = 'New' 
						  AND NewCert IS NULL
						  AND Amount > 0

				END -- The end of looping through all certifications for this particular unit lease group chain

				/**** ------------------------------------------ Get Requested Amount for Group ------------------------------------------ ****/
				-- We need to wrap up the adjustment group, we should be all finished with our new certifications now, of course, we won't need 
				-- to wrap up the adjustment group if it had unit transfers, the special unit transfer logic should have already wrapped up itself
				SELECT @Requested = SUM(Amount) FROM #Adjustments 
				WHERE GroupNumber = ISNULL(@AdjustmentGroupCounterOverride, @AdjustmentGroupCounter)
				UPDATE #Adjustments SET Requested = @Requested
				WHERE RowNumber = (SELECT MAX(RowNumber) FROM #Adjustments WHERE CertificationID IS NOT NULL)

				-- Again need to wrap up this whole group with an empty row
				INSERT INTO #Adjustments
					SELECT @AdjustmentGroupCounter AS 'GroupNumber', 
							NULL AS 'AdjustmentID',
							NULL AS 'CertificationID',
							NULL AS 'UnitID',
							NULL AS 'HoHFirstName',
							NULL AS 'HoHMiddleInitial',
							NULL AS 'HoHLastName',
							NULL AS 'UnitNumber',
							NULL AS 'PriorOrNewBilling',
							NULL AS 'NewCert',
							NULL AS 'CertType',
							NULL AS 'EffectiveDate',
							NULL AS 'AssistancePayment',
							NULL AS 'BeginningDate',
							NULL AS 'EndingDate',
							NULL AS 'BeginningNoOfDays',
							NULL AS 'BeginningDailyRate',
							NULL AS 'NoOfMonths',
							NULL AS 'MonthlyRate',
							NULL AS 'EndingNoOfDays',
							NULL AS 'EndingDailyRate',
							NULL AS 'Amount',
							NULL AS 'Requested',
							NULL AS 'Paid',
							NULL AS 'PaddedUnitNumber'

			END-- The end of the lone termination stop

			-- Prepare for the next iteration, the next iteration will be for the next chunk of certifications in the same unit lease group chain
			SELECT @AdjustmentGroupCounter = @AdjustmentGroupCounter + 1
			SELECT @AdjustmentGroupCounterOverride = NULL
			TRUNCATE TABLE #Timeline
			TRUNCATE TABLE #NewTimeline
			TRUNCATE TABLE #OrderedTimeline

		END -- The end of looping through all of the unit lease group chains

		-- Now that we're done with all of our unit lease groups, then we can go through each row and assign it an adjustment ID, of course we're
		-- not going to bother to give blanks rows an adjustment iD
		UPDATE #Adjustments SET AdjustmentID = NEWID()
		WHERE CertificationID IS NOT NULL

		/**** ------------------------------------------ Delete All Of Our Uncommon Temp Tables ------------------------------------------ ****/
		/*
		DROP TABLE #UnbilledCertifications
		DROP TABLE #UnitLeaseGroups
		DROP TABLE #RemainingCerts
		DROP TABLE #Deadzones
		DROP TABLE #Timeline
		DROP TABLE #AffordableSubmissions
		DROP TABLE #OrderedTimeline
		DROP TABLE #TimelineItemsToReverse
		DROP TABLE #NewTimeline
		DROP TABLE #TouchedTimelineItems
		*/

	END -- The end of the else statement that checks if we have to dynamically create adjustments or just get the existing ones
	-- In either situation we still have to do the following clean up

	/**** ------------------------------------------ Clean Result Set ------------------------------------------ ****/
	-- We have all of our result set now, but before we return it there is some cleaning that needs to be done, also
	-- we want to double check a couple things, run some basic unit test to make sure that we aren't going to return
	-- results that have any business logic errors, a lot of the things in this section are hacks that take care of 
	-- weaknesses in our models that create adjustments, a lot of the following code before could be removed if we
	-- had smarter models that never made any mistakes, making the models infallible would be extremely difficult and 
	-- would require an entire rework of the whole stored procedure

	DELETE FROM #Adjustments 
	WHERE BeginningDate > EndingDate

	-- Find any unit transfers in the prior section that don't have a separate section actually reversing it's billing
	SELECT a.AdjustmentID
	INTO #IncompleteUnitTransferAdjustments
	FROM #Adjustments a
	LEFT OUTER JOIN #Adjustments a2 ON a2.CertificationID = a.CertificationID
									   AND a2.CertType IN ('UT-I', 'UT-I*')
									   AND a2.PriorOrNewBilling = 'Prior'
									   AND a2.BeginningDate = a.BeginningDate
									   AND a2.EndingDate = a.EndingDate
	LEFT OUTER JOIN #Adjustments a3 ON a3.CertificationID = a.CertificationID
									   AND a2.CertType IN ('UT-I', 'UT-I*')
									   AND a2.PriorOrNewBilling = 'New'
									   AND a2.NewCert IS NULL
									   AND a2.BeginningDate = a.BeginningDate
									   AND a2.EndingDate = a.EndingDate
	WHERE a.PriorOrNewBilling = 'Prior'
		  AND a.CertType IN ('UT-O', 'UT-O*')
		  AND a2.AdjustmentID IS NULL
		  AND a3.AdjustmentID IS NULL
	
	-- Now loop through all the unit transfer adjustments that aren't complete
	WHILE (SELECT COUNT(*) FROM #IncompleteUnitTransferAdjustments) > 0
	BEGIN

		DECLARE @ThisIncompleteUnitTransfer uniqueidentifier = NULL
		SELECT TOP 1 @ThisIncompleteUnitTransfer = AdjustmentID
		FROM #IncompleteUnitTransferAdjustments

		-- Whatever we do next is going to be in a new section with an overriden adjustment group ID
		IF @AdjustmentGroupCounterOverride IS NULL 
		BEGIN
			-- This is the first time we've encountered the override so we have to set it
			SELECT @AdjustmentGroupCounterOverride = MAX(GroupNumber) + 1 FROM #Adjustments
		END
		ELSE
		BEGIN
			SET @AdjustmentGroupCounterOverride = @AdjustmentGroupCounterOverride + 1
		END

		-- Insert the missing rows
		INSERT INTO #Adjustments 
			SELECT DISTINCT @AdjustmentGroupCounterOverride AS 'GroupNumber',
					NEWID() AS 'AdjustmentID',
					a.CertificationID AS 'CertificationID',
					a.UnitID AS 'UnitID',
					a.HoHFirstName AS 'HoHFirstName',
					a.HoHMiddleInitial AS 'HoHMiddleInitial',
					a.HoHLastName AS 'HoHLastName',
					a.UnitNumber AS 'UnitNumber',
					'Prior' AS 'PriorOrNewBilling',
					NULL AS 'NewCert',
					CASE WHEN c.IsCorrection = 1 THEN 'UT-I*' ELSE 'UT-I' END AS 'CertType',
					DATEADD(D, 1, a.EffectiveDate) AS 'EffectiveDate',
					c.HUDAssistancePayment AS 'AssistancePayment',
					a.BeginningDate AS 'BeginningDate',
					a.EndingDate AS 'EndingDate',
					d.BeginningNoOfDays AS 'BeginningNoOfDays',
					d.BeginningDailyRate AS 'BeginningDailyRate',
					d.NoOfMonths AS 'NoOfMonths',
					d.MonthlyRate AS 'MonthlyRate',
					d.EndingNoOfDays AS 'EndingNoOfDays',
					d.EndingDailyRate AS 'EndingDailyRate',
					d.Amount AS 'Amount',
					NULL AS 'Requested',
					NULL AS 'Paid',
					a.PaddedUnitNumber AS 'PaddedUnitNumber'
			FROM #Adjustments a
			INNER JOIN Certification c ON c.CertificationID = a.CertificationID
			CROSS APPLY dbo.GetAdjustmentCalculationDetail(a.BeginningDate, a.EndingDate, c.HUDAssistancePayment, 1, 0) AS d
			WHERE a.AdjustmentID = @ThisIncompleteUnitTransfer

		INSERT INTO #Adjustments 
			SELECT DISTINCT @AdjustmentGroupCounterOverride AS 'GroupNumber',
					NEWID() AS 'AdjustmentID',
					a.CertificationID AS 'CertificationID',
					a.UnitID AS 'UnitID',
					a.HoHFirstName AS 'HoHFirstName',
					a.HoHMiddleInitial AS 'HoHMiddleInitial',
					a.HoHLastName AS 'HoHLastName',
					a.UnitNumber AS 'UnitNumber',
					'New' AS 'PriorOrNewBilling',
					NULL AS 'NewCert',
					CASE WHEN c.IsCorrection = 1 THEN 'UT-I*' ELSE 'UT-I' END AS 'CertType',
					DATEADD(D, 1, a.EffectiveDate) AS 'EffectiveDate',
					0 AS 'AssistancePayment',
					a.BeginningDate AS 'BeginningDate',
					a.EndingDate AS 'EndingDate',
					d.BeginningNoOfDays AS 'BeginningNoOfDays',
					d.BeginningDailyRate AS 'BeginningDailyRate',
					d.NoOfMonths AS 'NoOfMonths',
					d.MonthlyRate AS 'MonthlyRate',
					d.EndingNoOfDays AS 'EndingNoOfDays',
					d.EndingDailyRate AS 'EndingDailyRate',
					d.Amount AS 'Amount',
					NULL AS 'Requested',
					NULL AS 'Paid',
					a.PaddedUnitNumber AS 'PaddedUnitNumber'
			FROM #Adjustments a
			INNER JOIN Certification c ON c.CertificationID = a.CertificationID
			CROSS APPLY dbo.GetAdjustmentCalculationDetail(a.BeginningDate, a.EndingDate, c.HUDAssistancePayment, 0, 1) AS d
			WHERE a.AdjustmentID = @ThisIncompleteUnitTransfer
			
		-- Now we can wrap up this group
		UPDATE #Adjustments SET Requested = (SELECT SUM(Amount) FROM #Adjustments WHERE GroupNumber = @AdjustmentGroupCounterOverride)
		WHERE RowNumber = (SELECT MAX(RowNumber) FROM #Adjustments WHERE CertificationID IS NOT NULL)
				AND Requested IS NULL

		INSERT INTO #Adjustments
			SELECT @AdjustmentGroupCounterOverride AS 'GroupNumber', 
					NULL AS 'AdjustmentID',
					NULL AS 'CertificationID',
					NULL AS 'UnitID',
					NULL AS 'HoHFirstName',
					NULL AS 'HoHMiddleInitial',
					NULL AS 'HoHLastName',
					NULL AS 'UnitNumber',
					NULL AS 'PriorOrNewBilling',
					NULL AS 'NewCert',
					NULL AS 'CertType',
					NULL AS 'EffectiveDate',
					NULL AS 'AssistancePayment',
					NULL AS 'BeginningDate',
					NULL AS 'EndingDate',
					NULL AS 'BeginningNoOfDays',
					NULL AS 'BeginningDailyRate',
					NULL AS 'NoOfMonths',
					NULL AS 'MonthlyRate',
					NULL AS 'EndingNoOfDays',
					NULL AS 'EndingDailyRate',
					NULL AS 'Amount',
					NULL AS 'Requested',
					NULL AS 'Paid',
					NULL AS 'PaddedUnitNumber'

		DELETE FROM #IncompleteUnitTransferAdjustments
		WHERE AdjustmentID = @ThisIncompleteUnitTransfer

	END

	-- Are there two adjustments in the same group that are of the same type, have the exact same adjustment date range, 
	-- have the same exact adjustment amounts, have the same effective dates, somehow if this has happened the new billing
	-- not new cert row should go away, it's serving no purpose, it's not helping to fill in a gap because there is no gap
	DELETE FROM #Adjustments
	WHERE AdjustmentID IN (
		SELECT a.AdjustmentID FROM #Adjustments a 
		INNER JOIN #Adjustments a2 ON a2.GroupNumber = a.GroupNumber
		WHERE a.NewCert IS NULL
			  AND a.PriorOrNewBilling = 'New'
			  AND a2.AdjustmentID <> a.AdjustmentID
			  AND a2.BeginningDate = a.BeginningDate
			  AND a2.EndingDate = a.EndingDate
			  AND a2.NewCert = 'Y'
			  AND (a2.CertType = (a.CertType + '*') OR a2.CertType = a.CertType)
			  AND a2.PriorOrNewBilling = 'New'
			  AND a2.EffectiveDate = a.EffectiveDate)

	-- Delete any adjustments that are their own group and they're just a blank row
	-- because regardless of what adjustments are created we always add in a blank row after each unit lease group chain
	DELETE FROM #Adjustments
	WHERE GroupNumber IN (SELECT GroupNumber 
						  FROM #Adjustments
						  GROUP BY GroupNumber
						  HAVING COUNT(GroupNumber) = 1)

	-- Are there two rows in the new section that start on the exact same day, does the first one have
	-- a zero amount, if it does then there is no need for that row, because the next row should take care
	-- of the same timeline, this is kind of a hackey solution
	DELETE FROM #Adjustments
	WHERE AdjustmentID IN (
		SELECT a.AdjustmentID
		FROM #Adjustments a
		INNER JOIN #Adjustments a2 ON a2.GroupNumber = a.GroupNumber
		WHERE a.AdjustmentID IS NOT NULL
			  AND a2.AdjustmentID IS NOT NULL
			  AND a.AdjustmentID <> a2.AdjustmentID
			  AND a2.RowNumber = (a.RowNumber + 1)
			  AND a.PriorOrNewBilling = 'New'
			  AND a2.PriorOrNewBilling = 'New'
			  AND a.BeginningDate = a2.BeginningDate
			  AND a.Amount = 0)

	-- Are there two rows in a new section where an old certification is directly followed by it's correction?  That situation doesn't make sense, there should never 
	-- be the original certification and the correction to that certification in the same section, there is no reason to be billing for both, only the correction should
	-- have billing anymore, that's the whole purpose of doing a correction to override any billing for the previous certification, typically, this issue comes from weird
	-- unit transfer corrections that are changing dates
	DELETE FROM #Adjustments 
	WHERE AdjustmentID = (
		SELECT a.AdjustmentID 
		FROM #Adjustments a 
		INNER JOIN Certification c ON c.CertificationID = a.CertificationID
		-- The next row from the group
		INNER JOIN #Adjustments a2 ON a2.GroupNumber = a.GroupNumber AND a2.RowNumber = (a.RowNumber + 1)
		INNER JOIN Certification c2 ON c2.CertificationID = a2.CertificationID
		WHERE c.CorrectedByCertificationID = c2.CertificationID
			  AND a.PriorOrNewBilling = 'New'
			  AND a2.PriorOrNewBilling = 'New')

	-- This is the real result set that gets returned, we have to use another table that is identical to our adjustment table, because we have to sort
	-- the adjustment table and there's no way to sort a temp table and save the sorted result
	CREATE TABLE #ReturnAdjustments (GroupNumber int, AdjustmentID uniqueidentifier, RowNumber int not null identity(1,1), CertificationID uniqueidentifier, 
									 UnitID uniqueidentifier, HoHFirstName nvarchar(50), HoHMiddleInitial nvarchar(1), HoHLastName nvarchar(50), UnitNumber nvarchar(50), 
									 PriorOrNewBilling nvarchar(5), NewCert nvarchar(1), CertType nvarchar(6), EffectiveDate date, AssistancePayment int, 
									 BeginningDate date, EndingDate date, BeginningNoOfDays int, BeginningDailyRate money, NoOfMonths int, MonthlyRate int, 
									 EndingNoOfDays int, EndingDailyRate money, Amount int, Requested int, Paid int, PaddedUnitNumber nvarchar(20))

	-- Reorder the adjustments and change the row numbers so that they're properly ordered
	INSERT INTO #ReturnAdjustments
		SELECT GroupNumber, AdjustmentID, CertificationID, UnitID, HoHFirstName, HoHMiddleInitial, HoHLastName , UnitNumber, PriorOrNewBilling, NewCert, CertType, 
			   EffectiveDate, AssistancePayment, BeginningDate, EndingDate, BeginningNoOfDays, BeginningDailyRate, NoOfMonths, MonthlyRate, EndingNoOfDays, 
			   EndingDailyRate, Amount, Requested, Paid, PaddedUnitNumber 
		FROM #Adjustments
		ORDER BY GroupNumber, PriorOrNewBilling DESC, BeginningDate	
	
	-- Find the last row where it has content and delete every following row that doesn't have content
	DELETE FROM #ReturnAdjustments
	WHERE RowNumber > (
		SELECT TOP 1 RowNumber
		FROM #ReturnAdjustments
		WHERE CertificationID IS NOT NULL
		ORDER BY RowNumber DESC)

	-- Remove any rows that are higher than other rows but have lesser effective dates in the 
	--same section and the same group, those rows simply don't make any sense
	DELETE FROM #ReturnAdjustments
	WHERE AdjustmentID IN (
		SELECT a.AdjustmentID
		FROM #ReturnAdjustments a
		INNER JOIN #ReturnAdjustments a2 ON a2.GroupNumber = a.GroupNumber AND a2.AdjustmentID <> a.AdjustmentID AND a.PriorOrNewBilling = a2.PriorOrNewBilling
		WHERE a.RowNumber > a2.RowNumber
			  AND a.EffectiveDate < a2.EffectiveDate)

	-- This should take care of what the first delete above was trying to do, this is just more comprehensive
	DELETE FROM #ReturnAdjustments
	WHERE RowNumber IN (
		SELECT ra.RowNumber
		FROM #ReturnAdjustments ra
		WHERE ra.RowNumber > (SELECT TOP 1 RowNumber
							  FROM #ReturnAdjustments ra2
							  WHERE ra2.GroupNumber = ra.GroupNumber
							  AND ra2.CertificationID IS NULL
							  ORDER BY RowNumber))

	-- Find the adjustments to correct
	SELECT a.AdjustmentID
	INTO #AdjustmentsToCorrect
	FROM #ReturnAdjustments a
	INNER JOIN #ReturnAdjustments a2 ON a2.GroupNumber = a.GroupNumber
	WHERE a.AdjustmentID IS NOT NULL
		  AND a2.AdjustmentID IS NOT NULL
		  AND a.AdjustmentID <> a2.AdjustmentID
		  AND a2.RowNumber = (a.RowNumber + 1)
		  AND a.NewCert = 'Y'
		  AND a2.NewCert = 'Y'
		  AND a2.BeginningDate <> DATEADD(D, 1, a.EndingDate)

	-- Make sure that our members in each new section always follow each other sequentially
	UPDATE a
	SET a.EndingDate = DATEADD(D, -1, a2.BeginningDate)
	FROM #ReturnAdjustments a
	INNER JOIN #ReturnAdjustments a2 ON a2.RowNumber = (a.RowNumber + 1)
	WHERE a.AdjustmentID IN (SELECT * FROM #AdjustmentsToCorrect)

	-- If we've offset any dates then we have to redo the math
	UPDATE a 
	SET a.BeginningNoOfDays = d.BeginningNoOfDays,
		a.BeginningDailyRate = d.BeginningDailyRate,
		a.NoOfMonths = d.NoOfMonths,
		a.MonthlyRate = d.MonthlyRate,
		a.EndingNoOfDays = d.EndingNoOfDays,
		a. EndingDailyRate = d.EndingDailyRate,
		a.Amount = d.Amount
	FROM #ReturnAdjustments a
	CROSS APPLY dbo.GetAdjustmentCalculationDetail(a.BeginningDate, a.EndingDate, a.AssistancePayment, 0, 0) AS d
	WHERE a.AdjustmentID IN (SELECT * FROM #AdjustmentsToCorrect)

	-- Update the requested amount for each group
	UPDATE a
	SET Requested = (SELECT SUM(a2.Amount) FROM #ReturnAdjustments a2 WHERE a2.GroupNumber = a.GroupNumber)
	FROM #ReturnAdjustments a 
	WHERE a.Requested IS NOT NULL

	-- Add more spaces if a group of adjustments is going to split a multiple of 30, this makes sure that adjustment groups
	-- never get broken up between pages on the 52670A - Part 3 form
	-- There is a problem with this functionality, sometimes it adds additional rows where they are not needed, can't really
	-- figure out why, if you think you can fix this, go ahead, otherwise we'll just occasionally have some extra blank rows
	CREATE TABLE #TouchedAdjustments (AdjustmentID uniqueidentifier)
	DECLARE @GroupCount int = 0, -- The total number of groups (last group number)
			@GroupCounter int = 1,
			@AdjustmentItemCounter int = 1, -- Keeps track of the real row number that an adjustment will appear on
			@OffsetCounter int = 0

	SELECT @GroupCount = MAX(GroupNumber) FROM #ReturnAdjustments
	-- Start looping through the groups
	WHILE @GroupCounter <= @GroupCount
	BEGIN
		-- If any of the group can be split by a multiple of 30 then we'll shift the group by adding blank rows to the previous group
		DECLARE @SplitByMultipleOf30 bit = 0,
				@ThisGroupAdjustmentCount int = 0,
				@ThisGroupCounter int = 0 -- The number of items that we're looped through in this group
		SELECT @ThisGroupAdjustmentCount = COUNT(*) FROM #ReturnAdjustments WHERE GroupNumber = @GroupCounter
		
		-- Start looping through adjustments in this group
		-- Of course if the total number of adjustments for the group (@ThisGroupAdjustmentCount) is greater than thirty than there
		-- is no point of this because the whole group will overflow the page anyways, hopefully this never happens because I believe
		-- that the totals for the form pages would be wrong, should never have 30 adjustments for a single group anyways
		WHILE @ThisGroupCounter < @ThisGroupAdjustmentCount AND @ThisGroupAdjustmentCount <= 30 AND @SplitByMultipleOf30 = 0
		BEGIN

			-- Pick an adjustment that hasn't been touched yet
			DECLARE @ThisAdjustment uniqueidentifier = NULL
			SELECT TOP 1 @ThisAdjustment = AdjustmentID 
			FROM #ReturnAdjustments
			WHERE AdjustmentID NOT IN (SELECT * FROM #TouchedAdjustments)
				  AND GroupNumber = @GroupCounter
			-- Always up the total item count by one
			SELECT @AdjustmentItemCounter = @AdjustmentItemCounter + 1
			-- If we're on our final iteration for this group then we don't care if this last row is on thirty
			-- however we still have to be inside this loop to increase the adjustment item counter etc
			IF @ThisGroupCounter <> @ThisGroupAdjustmentCount
			BEGIN
				-- Figure out if this row is a multiple of 30 and if it's not a blank row, if it is a blank row then wonderful we don't have to do anything
				SELECT @SplitByMultipleOf30 = CASE WHEN (@AdjustmentItemCounter - 1 + @OffsetCounter) % 30 = 0 THEN 1 ELSE 0 END 
				FROM #ReturnAdjustments
				WHERE AdjustmentID = @ThisAdjustment
					  AND RowNumber IS NOT NULL
					  AND GroupNumber = @GroupCounter
			END
			-- Increment the number of adjustments we've been through in this group
			SELECT @ThisGroupCounter = @ThisGroupCounter + 1
			-- Mark this adjustment as touched
			INSERT INTO #TouchedAdjustments SELECT @ThisAdjustment
		END

		-- Were there any adjustments in the entire group that were not a blank row and were divisible by 30?
		IF @SplitByMultipleOf30 = 1
		BEGIN

			-- If the group is going to be broken up then we need to start adding extra rows, the ThisGroupCounter
			-- let's us know how many adjustments we get through until we hit that row that is divible by 30, so 
			-- for each of those rows we've been through already we'll need to add a blank space, so if 3 adjustments
			-- would be on the previous page, then we need to add 3 blank lines to make sure the entire group is visible 
			-- on the next page
			WHILE @ThisGroupCounter > 0
			BEGIN
				INSERT INTO #ReturnAdjustments
					SELECT (@GroupCounter - 1) AS 'GroupNumber', -- The previous group to this one
							NULL AS 'AdjustmentID',
							NULL AS 'CertificationID',
							NULL AS 'UnitID',
							NULL AS 'HoHFirstName',
							NULL AS 'HoHMiddleInitial',
							NULL AS 'HoHLastName',
							NULL AS 'UnitNumber',
							NULL AS 'PriorOrNewBilling',
							NULL AS 'NewCert',
							NULL AS 'CertType',
							NULL AS 'EffectiveDate',
							NULL AS 'AssistancePayment',
							NULL AS 'BeginningDate',
							NULL AS 'EndingDate',
							NULL AS 'BeginningNoOfDays',
							NULL AS 'BeginningDailyRate',
							NULL AS 'NoOfMonths',
							NULL AS 'MonthlyRate',
							NULL AS 'EndingNoOfDays',
							NULL AS 'EndingDailyRate',
							NULL AS 'Amount',
							NULL AS 'Requested',
							NULL AS 'Paid',
							NULL AS 'PaddedUnitNumber'
				-- Minus 1 from the number of rows that we still need to add
				SELECT @ThisGroupCounter = @ThisGroupCounter - 1
				-- Need to make sure this is bumping up our total of all adjustment rows or we're going to be off after finding a split group once
				-- This is really the big reason why we have to use this while loop, because when we add in extra rows that throws off the row number
				-- so really once we start tweaking this table, row number is completely unreliable so we have to rely on adjustment item counter
				SELECT @AdjustmentItemCounter = @AdjustmentItemCounter + 1
				SET @OffsetCounter = @OffsetCounter + 1
			END
		END
		
		-- Now we're ready to go onto the next group of adjustments
		TRUNCATE TABLE #TouchedAdjustments
		SELECT @GroupCounter = @GroupCounter + 1
	END

	-- Extra precaution to make sure 100% that every group in these results is absolutely going to have a requested amount
	UPDATE a
	SET Requested = (SELECT SUM(a2.Amount) FROM #ReturnAdjustments a2 WHERE a2.GroupNumber = a.GroupNumber)
	FROM #ReturnAdjustments a
	WHERE a.RowNumber IN (SELECT MAX(RowNumber) 
						  FROM #ReturnAdjustments
						  WHERE AdjustmentID IS NOT NULL
						  GROUP BY GroupNumber) 

	SELECT * FROM #ReturnAdjustments
	ORDER BY GroupNumber, PriorOrNewBilling DESC, BeginningDate	

	/**** ------------------------------------------ Delete All Of Our Common Temp Tables ------------------------------------------ ****/
	/*
	DROP TABLE #Adjustments
	DROP TABLE #ReturnAdjustments
	DROP TABLE #TouchedAdjustments
	DROP TABLE #AdjustmentsToCorrect
	DROP TABLE #IncompleteUnitTransferAdjustments
	*/

END
GO
