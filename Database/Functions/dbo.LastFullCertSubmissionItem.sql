SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[LastFullCertSubmissionItem] 
(
	-- Add the parameters for the function here
	@accountID bigint,
	@certificationID uniqueidentifier
)
RETURNS uniqueidentifier
AS
BEGIN

	DECLARE @LastSubmittedFullCertID uniqueidentifier = NULL,
			@TransferGroupID uniqueidentifier,
			@CertEffectiveDate date,
			@AR nvarchar(15) = 'Recertification',
			@IR nvarchar(7) = 'Interim',
			@IC nvarchar(7) = 'Initial',
			@MI nvarchar(7) = 'Move-in',
			@AffordableSubmissionItemID uniqueidentifier

	-- Get information on the certification we're trying to find previous info for
	SELECT @TransferGroupID = ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID), 
		   @CertEffectiveDate = c.EffectiveDate,
		   @AffordableSubmissionItemID = CASE WHEN c.[Type] IN (@AR, @IR, @IC, @MI) AND asi.AffordableSubmissionItemID IS NOT NULL 
											  THEN asi.AffordableSubmissionItemID 
											  ELSE NULL END
	FROM Certification c
	INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
	INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
	LEFT OUTER JOIN AffordableSubmissionItem asi ON asi.ObjectID = capa.CertificationAffordableProgramAllocationID
					AND asi.[Status] IN ('Sent', 'Success', 'Corrections Needed')
	WHERE c.AccountID = @accountID
		  AND c.CertificationID = @certificationID

	IF @AffordableSubmissionItemID IS NULL
	BEGIN
		-- Now find all previously sent certs and just pull out the most recent that is a full cert
		SELECT TOP 1 @AffordableSubmissionItemID = asi.AffordableSubmissionItemID
		FROM Certification c
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = c.UnitLeaseGroupID
		INNER JOIN CertificationAffordableProgramAllocation capa ON capa.CertificationID = c.CertificationID
		INNER JOIN AffordableSubmissionItem asi ON asi.ObjectID = capa.CertificationAffordableProgramAllocationID
		WHERE c.AccountID = @accountID
			  AND ISNULL(ulg.TransferGroupID, ulg.UnitLeaseGroupID) = @TransferGroupID
			  AND c.CertificationID <> @certificationID
			  AND c.EffectiveDate < @CertEffectiveDate
			  AND c.[Type] IN (@MI, @IC, @IR, @AR)
			  AND asi.[Status] IN ('Sent', 'Success', 'Corrections Needed')
		ORDER BY c.EffectiveDate DESC
	END

	RETURN @AffordableSubmissionItemID

END
GO
