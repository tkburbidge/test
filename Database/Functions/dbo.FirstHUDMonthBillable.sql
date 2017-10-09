SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[FirstHUDMonthBillable] 
(
	-- Add the parameters for the function here
	@certificationID uniqueidentifier,
	@accountID bigint,
	@considerCurrentVoucher bit
)
RETURNS date
AS
BEGIN

	IF @considerCurrentVoucher IS NULL
	BEGIN
		SET @considerCurrentVoucher = 1
	END

	DECLARE @FirstBillingMonth Date,
		--Abbreviation Dictionary--
		@AR nvarchar(15) = 'Recertification',
		@IR nvarchar(7) = 'Interim',
		@IC nvarchar(7) = 'Initial',
		@MI nvarchar(7) = 'Move-in',
		@MO nvarchar(8) = 'Move-out',
		@TM nvarchar(11) = 'Termination',
		@GR nvarchar(25) = 'Gross Rent Change Interim',
		@UT nvarchar(16) = 'Transfer Interim',
		@EffectiveDate datetime,
		@TransferGroupID uniqueidentifier

	DECLARE @CertCompleted bit = 0
	SELECT @CertCompleted = CASE WHEN AnticipatedVoucherDate IS NOT NULL AND DateCompleted IS NOT NULL THEN 1 ELSE 0 END
	FROM Certification 
	WHERE CertificationID = @certificationID

	IF @CertCompleted = 1 AND @considerCurrentVoucher = 1
	BEGIN
		SELECT @FirstBillingMonth = AnticipatedVoucherDate
		FROM Certification 
		WHERE CertificationID = @certificationID
	END

	ELSE 
	BEGIN
		SELECT @EffectiveDate = CASE WHEN c.[Type] = @MO AND c.EffectiveDate > DATEADD(D, 14, ah.DeathDate) 
									 THEN DATEADD(D, 14, ah.DeathDate) 
									 ELSE c.EffectiveDate END,
			   @TransferGroupID = ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID)
		FROM Certification c
		INNER JOIN AffordableHousehold ah ON ah.ObjectID = c.UnitLeaseGroupID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID 
		WHERE c.CertificationID = @certificationID

		SELECT @FirstBillingMonth = CASE 
											--All cases when it can be sent in the same month
											WHEN (apa.SubsidyType IN ('RAP', 'Rent Supplement') AND 
												DAY(@EffectiveDate) = 1 AND  
												c.Type IN (@AR, @IR, @IC, @MI, @GR, @UT))
												OR
												(apa.SubsidyType NOT IN ('RAP', 'Rent Supplement') AND 
												DAY(@EffectiveDate) = 1 AND 
												c.Type IN (@AR, @IR, @IC, @GR))
											THEN dbo.FirstOfMonth(@EffectiveDate)
											--All cases when it can be sent the month after
											WHEN (apa.SubsidyType IN ('RAP', 'Rent Supplement') AND 
												DAY(@EffectiveDate) = 1 AND 
												c.Type IN (@MO, @TM))
												OR
												(apa.SubsidyType IN ('RAP', 'Rent Supplement') AND 
												DAY(@EffectiveDate) != 1 AND 
												c.Type != @AR)
												OR
												(apa.SubsidyType NOT IN ('RAP', 'Rent Supplement') AND 
												DAY(@EffectiveDate) = 1 AND 
												c.Type IN (@MI, @MO, @TM, @UT))
												OR 
												(apa.SubsidyType NOT IN ('RAP', 'Rent Supplement') AND 
												DAY(@EffectiveDate) != 1 AND 
												c.Type = @GR)
											THEN DATEADD(M, 1, dbo.FirstOfMonth(@EffectiveDate))
											--All cases when it can be sent two months after
											WHEN apa.SubsidyType NOT IN ('RAP', 'Rent Supplement') AND 
												DAY(@EffectiveDate) != 1 AND 
												c.Type NOT IN (@GR, @AR)
											THEN DATEADD(M, 2, dbo.FirstOfMonth(@EffectiveDate))
											ELSE DATEADD(M, 2, dbo.FirstOfMonth(@EffectiveDate))
									END
			FROM Certification c
			INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
			INNER JOIN AffordableProgramAllocation apa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
			INNER JOIN AffordableProgram ap ON ap.AffordableProgramID = ap.AffordableProgramID
			WHERE c.CertificationID = @certificationID
					AND ap.IsHUD = 1
					AND c.AccountID = @accountID

		/**** ------------------------------ Find any AVD Drag Scenarios ------------------------------ ****/
		DECLARE @FilteredCerts AS TABLE(CertificationID uniqueidentifier)

		INSERT INTO @FilteredCerts
			SELECT DISTINCT c.CertificationID 
			FROM Certification c
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
			INNER JOIN AffordableHousehold ah ON ah.ObjectID = c.UnitLeaseGroupID
			INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
			INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = capa.CertificationAffordableProgramAllocationID
			LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationID = c.CertificationID
			-- Get both the adjustments and regular assistance payments for the certification
			LEFT OUTER JOIN AffordableSubmissionItem adjRap ON adjRap.ObjectID IN (ca.CertificationAdjustmentID, c.CertificationID)
			LEFT OUTER JOIN AffordableSubmission a ON a.AffordableSubmissionID = adjRap.AffordableSubmissionID
			-- Find certifications in the same unit lease group chain
			WHERE ((ulg.TransferGroupID IS NOT NULL AND ulg.TransferGroupID = @TransferGroupID) OR ulg.UnitLeaseGroupID = @TransferGroupID)
				  -- that occur before the current certification
				  AND (CASE WHEN c.[Type] = @MO AND c.EffectiveDate > DATEADD(D, 14, ah.DeathDate) 
							THEN DATEADD(D, 14, ah.DeathDate) ELSE c.EffectiveDate END) < @EffectiveDate
				  -- have never been billed successfully before  
				  AND (adjRap.AffordableSubmissionItemID IS NULL OR a.[Status] = 'Errors')
				  -- has successfully been submitted as certification to HUD
				  AND asi.[Status] IN ('Sent', 'Success', 'Corrections Needed')

		DECLARE @PossibleAVDDrag bit
		SELECT @PossibleAVDDrag = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END FROM @FilteredCerts

		/**** ------------------------------ Find max date for AVD Drag ------------------------------ ****/
		IF @PossibleAVDDrag = 1
		BEGIN
			DECLARE @QualifiedCertCount int,
					@Counter int = 0
			DECLARE @PossibleMaxDates AS TABLE(VoucherDate datetime)

			SELECT @QualifiedCertCount = COUNT(*)
			FROM Certification
			WHERE CertificationID IN (SELECT CertificationID FROM @FilteredCerts)

			WHILE @Counter < @QualifiedCertCount
			BEGIN
				DECLARE @thisCert uniqueidentifier = NULL,
						@thisCertEffDate datetime = NULL,
						@maxDate datetime
				SELECT TOP 1 @thisCert = fc.CertificationID, 
							 @thisCertEffDate = (CASE WHEN c.[Type] = @MO AND c.EffectiveDate > DATEADD(D, 14, ah.DeathDate) 
													  THEN DATEADD(D, 14, ah.DeathDate) ELSE c.EffectiveDate END)
				FROM @FilteredCerts fc
				INNER JOIN Certification c ON c.CertificationID = fc.CertificationID 
				INNER JOIN AffordableHousehold ah ON ah.ObjectID = c.UnitLeaseGroupID

				-- Apply same exact logic from up top
				SELECT @maxDate = CASE 
							--All cases when it can be sent in the same month
							WHEN (apa.SubsidyType IN ('RAP', 'Rent Supplement') AND 
								DAY(@thisCertEffDate) = 1 AND  
								c.Type IN (@AR, @IR, @IC, @MI, @GR, @UT))
								OR
								(apa.SubsidyType NOT IN ('RAP', 'Rent Supplement') AND 
								DAY(@thisCertEffDate) = 1 AND 
								c.Type IN (@AR, @IR, @IC, @GR))
							THEN dbo.FirstOfMonth(@thisCertEffDate)
							--All cases when it can be sent the month after
							WHEN (apa.SubsidyType IN ('RAP', 'Rent Supplement') AND 
								DAY(@thisCertEffDate) = 1 AND 
								c.Type IN (@MO, @TM))
								OR
								(apa.SubsidyType IN ('RAP', 'Rent Supplement') AND 
								DAY(@thisCertEffDate) != 1 AND 
								c.Type != @AR)
								OR
								(apa.SubsidyType NOT IN ('RAP', 'Rent Supplement') AND 
								DAY(@thisCertEffDate) = 1 AND 
								c.Type IN (@MI, @MO, @TM, @UT))
								OR 
								(apa.SubsidyType NOT IN ('RAP', 'Rent Supplement') AND 
								DAY(@thisCertEffDate) != 1 AND 
								c.Type = @GR)
							THEN DATEADD(M, 1, dbo.FirstOfMonth(@thisCertEffDate))
							--All cases when it can be sent two months after
							WHEN apa.SubsidyType NOT IN ('RAP', 'Rent Supplement') AND 
								DAY(@thisCertEffDate) != 1 AND 
								c.Type NOT IN (@GR, @AR)
							THEN DATEADD(M, 2, dbo.FirstOfMonth(@thisCertEffDate)) END
				FROM Certification c
				INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
				INNER JOIN AffordableProgramAllocation apa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
				INNER JOIN AffordableProgram ap ON ap.AffordableProgramID = ap.AffordableProgramID
				WHERE c.CertificationID = @thisCert
						AND ap.IsHUD = 1
						AND c.AccountID = @accountID

				IF @maxDate > @FirstBillingMonth
				BEGIN
					INSERT INTO @PossibleMaxDates SELECT @maxDate
				END

				DELETE FROM @FilteredCerts
				WHERE CertificationID = @thisCert
				SELECT @Counter = @Counter + 1
			END

			SELECT @FirstBillingMonth = CASE WHEN MAX(VoucherDate) > @FirstBillingMonth 
											 THEN MAX(VoucherDate) 
											 ELSE @FirstBillingMonth END FROM @PossibleMaxDates
		END

		IF @considerCurrentVoucher = 1
		BEGIN
			DECLARE @NextVoucher datetime 
			SELECT @NextVoucher = DATEADD(M, 1, a.StartDate)
			FROM Certification c 
			INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
			INNER JOIN AffordableSubmission a ON a.AffordableSubmissionID = (
				SELECT TOP 1 a.AffordableSubmissionID
				FROM AffordableSubmission a
				INNER JOIN AffordableSubmissionPayment asp ON asp.AffordableSubmissionID = a.AffordableSubmissionID
				WHERE a.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
					  AND asp.Code = 'VSP00'
					  AND a.HUDSubmissionType = 'Voucher'
				ORDER BY a.StartDate DESC)
			WHERE c.CertificationID = @certificationID
				  AND (c.DateCompleted IS NULL OR c.AnticipatedVoucherDate IS NOT NULL)

			IF @NextVoucher IS NOT NULL AND @NextVoucher > @FirstBillingMonth
			BEGIN
				SET @FirstBillingMonth = @NextVoucher
			END
		END
	END

	RETURN @FirstBillingMonth

END
GO
