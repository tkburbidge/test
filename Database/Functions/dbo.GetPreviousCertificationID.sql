SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[GetPreviousCertificationID]
(
	-- Add the parameters for the function here
	@accountID BIGINT,
	@date DATETIME = NULL,
	@certificationID UNIQUEIDENTIFIER = NULL,
	@types StringCollection READONLY,
	@completedOnly BIT = 0,
	@hasSubmissionItem BIT = 0,
	@certificationGroupID UNIQUEIDENTIFIER
)
RETURNS uniqueidentifier
AS
BEGIN

	IF @completedOnly IS NULL
	BEGIN
		SET @completedOnly = 0
	END
	IF @hasSubmissionItem IS NULL
	BEGIN
		SET @hasSubmissionItem = 0
	END

	DECLARE @PreviousCertificationID UNIQUEIDENTIFIER

	SELECT TOP 1 @PreviousCertificationID = c.CertificationID 
	FROM Certification c 
	WHERE c.AccountID = @accountID 
		AND (@date IS NULL OR c.EffectiveDate <= @date) 
		AND (@certificationID IS NULL 
			OR (@certificationID != c.CertificationID 
				AND c.EffectiveDate <= (SELECT c2.EffectiveDate FROM Certification c2 WHERE c2.CertificationID = @certificationID))) 
		AND ((SELECT COUNT(*) FROM @types) = 0 OR c.[Type] in (SELECT Value FROM @types)) 
		AND (@completedOnly = 0 OR (@completedOnly = 1 AND c.DateCompleted IS NOT NULL)) 
		AND (@hasSubmissionItem = 0 OR (SELECT COUNT(*) FROM AffordableSubmissionItem asi 
											JOIN CertificationAffordableProgramAllocation capa ON asi.ObjectID = capa.CertificationAffordableProgramAllocationID
										WHERE asi.AccountID = @accountID  
												AND (asi.[Status] IN ('Corrections Needed', 'Success', 'Sent')) 
											AND capa.CertificationID = c.CertificationID) > 0)
		AND c.CertificationGroupID = @certificationGroupID
		AND c.CorrectedByCertificationID IS NULL
	ORDER BY c.EffectiveDate DESC, c.CreatedDate DESC

	RETURN @PreviousCertificationID

END
GO
