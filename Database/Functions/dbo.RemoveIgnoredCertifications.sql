SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[RemoveIgnoredCertifications] 
(	
	-- Add the parameters for the function here
	@accountID bigint,
	@certificationIDs GuidCollection READONLY
)
RETURNS @RelevantCertifications TABLE(CertificationID uniqueidentifier)

AS
BEGIN
	
	INSERT INTO @RelevantCertifications SELECT * FROM @certificationIDs

	DECLARE @PaidByTreasuryCode nvarchar(5) = 'VSP00'

	DECLARE @CertificationsInvolvedInCorrections AS TABLE (CertificationID uniqueidentifier)

	INSERT INTO @CertificationsInvolvedInCorrections
		SELECT c.CertificationID
		FROM @RelevantCertifications c
		INNER JOIN Certification c2 ON c2.CertificationID = c.CertificationID
		WHERE IsCorrection = 1 OR CorrectedByCertificationID IS NOT NULL

	DECLARE @CountOfInvolvedCertifications int = 0,
			@ChainCounter int = 0,
			@CounterStartingPoint int = 100
	SELECT @CountOfInvolvedCertifications = COUNT(*) FROM @CertificationsInvolvedInCorrections

	-- This is the table that will house all of the chains of corrections, the Counter column basically acts as an ID
	-- that helps us group stuff, we also figure out if the cert was billed and then the sequence tells us what order the 
	-- correction chain is in, sequence makes it easier to handle comparisons instead of using the CorrectedByCertID etc...
	-- We start the sequence at 100, so if there are more than 100 consecutive corrections in a chain then this will break
	DECLARE @CorrectionChains AS TABLE (ChainCounter int, CertificationID uniqueidentifier, Billed bit, Sequence int)

	-- If there are some certifications that have any ties to corrections let's start looping through and finding the correction chains
	WHILE @CountOfInvolvedCertifications > 0
	BEGIN
		SELECT @ChainCounter = @ChainCounter + 1

		DECLARE @ThisInvolvedCertificationID uniqueidentifier = NULL
		SELECT @ThisInvolvedCertificationID = CertificationID 
		FROM @CertificationsInvolvedInCorrections

		DECLARE @CurrentCertificationID uniqueidentifier = NULL
		SELECT @CurrentCertificationID = @ThisInvolvedCertificationID

		SELECT @CounterStartingPoint = 100

		-- Insert the random cert we are starting with into our chain
		INSERT INTO @CorrectionChains
			SELECT DISTINCT @ChainCounter, @CurrentCertificationID, CASE WHEN asp.AffordableSubmissionPaymentID IS NULL THEN 0 ELSE 1 END, @CounterStartingPoint
			FROM Certification c
			LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationID = c.CertificationID
			LEFT OUTER JOIN AffordableSubmissionItem asi ON asi.ObjectID IN (c.CertificationID, ca.CertificationAdjustmentID)
			LEFT OUTER JOIN AffordableSubmissionPayment asp ON asp.AffordableSubmissionID = asi.AffordableSubmissionID AND asp.Code = @PaidByTreasuryCode
			WHERE c.CertificationID = @CurrentCertificationID

		-- Move backwards down the chain
		WHILE @CurrentCertificationID IS NOT NULL 
		BEGIN  
			SET @CurrentCertificationID = (SELECT TOP 1 CertificationID
										   FROM Certification
										   WHERE CorrectedByCertificationID = @CurrentCertificationID
												 AND AccountID = @accountID)
			IF @CurrentCertificationID IS NOT NULL 
			BEGIN
				-- Adjust our sequence number
				SELECT @CounterStartingPoint = @CounterStartingPoint - 1
				INSERT INTO @CorrectionChains 
					SELECT DISTINCT @ChainCounter, @CurrentCertificationID, CASE WHEN asp.AffordableSubmissionPaymentID IS NULL THEN 0 ELSE 1 END, @CounterStartingPoint
					FROM Certification c
					LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationID = c.CertificationID
					LEFT OUTER JOIN AffordableSubmissionItem asi ON asi.ObjectID IN (c.CertificationID, ca.CertificationAdjustmentID)
					LEFT OUTER JOIN AffordableSubmissionPayment asp ON asp.AffordableSubmissionID = asi.AffordableSubmissionID AND asp.Code = @PaidByTreasuryCode
					WHERE c.CertificationID = @CurrentCertificationID
				-- We can remove this from the list of random certs we pick from at the start of a new iteration of this loop
				DELETE FROM @CertificationsInvolvedInCorrections WHERE CertificationID = @CurrentCertificationID	
			END
		END 

		-- Reset the sequence because we're going to move in a different direction of the chain
		SELECT @CounterStartingPoint = 100
		SELECT @CurrentCertificationID = @ThisInvolvedCertificationID

		-- Move forwards through the chain
		WHILE @CurrentCertificationID IS NOT NULL 
		BEGIN  
			SET @CurrentCertificationID = (SELECT TOP 1 CorrectedByCertificationID
											FROM Certification
											WHERE CertificationID = @CurrentCertificationID
												    AND AccountID = @accountID)
			IF @CurrentCertificationID IS NOT NULL 
			BEGIN
				-- Sequence gets augmented up now
				SELECT @CounterStartingPoint = @CounterStartingPoint + 1
				INSERT INTO @CorrectionChains
					SELECT DISTINCT @ChainCounter, @CurrentCertificationID, CASE WHEN asp.AffordableSubmissionPaymentID IS NULL THEN 0 ELSE 1 END, @CounterStartingPoint
					FROM Certification c
					LEFT OUTER JOIN CertificationAdjustment ca ON ca.CertificationID = c.CertificationID
					LEFT OUTER JOIN AffordableSubmissionItem asi ON asi.ObjectID IN (c.CertificationID, ca.CertificationAdjustmentID)
					LEFT OUTER JOIN AffordableSubmissionPayment asp ON asp.AffordableSubmissionID = asi.AffordableSubmissionID AND asp.Code = @PaidByTreasuryCode
					WHERE c.CertificationID = @CurrentCertificationID
				DELETE FROM @CertificationsInvolvedInCorrections WHERE CertificationID = @CurrentCertificationID	
			END
		END 

		DELETE FROM @CertificationsInvolvedInCorrections
		WHERE CertificationID = @ThisInvolvedCertificationID

		-- Reset the count, because we may have removed a chunk of certifications that we don't have to deal with anymore
		SELECT @CountOfInvolvedCertifications = COUNT(*) FROM @CertificationsInvolvedInCorrections

	END

	-- Now we have the basic chains, if there is any chain that only consists of a single member then it's really not
	-- a chain and there's no reason for us to concern ourselves with it
	DELETE FROM @CorrectionChains
	WHERE ChainCounter IN (
		SELECT ChainCounter
		FROM @CorrectionChains
		GROUP BY ChainCounter
		HAVING COUNT(ChainCounter) = 1) 

	-- Delete the permanently ignored from our master certification list
	DELETE FROM @RelevantCertifications
	WHERE CertificationID IN (
		SELECT cc.CertificationID
		FROM @CorrectionChains cc
		INNER JOIN @CorrectionChains cc2 ON cc2.ChainCounter = cc.ChainCounter
		WHERE cc.Sequence < cc2.Sequence
				AND cc2.Billed = 1)
		
	-- Now purge of correction chain of all ignored and billed certs
	DELETE FROM @CorrectionChains
	WHERE CertificationID IN (
		SELECT cc.CertificationID
		FROM @CorrectionChains cc
		INNER JOIN @CorrectionChains cc2 ON cc2.ChainCounter = cc.ChainCounter
		WHERE cc.Sequence < cc2.Sequence
				AND cc2.Billed = 1)
	DELETE FROM @CorrectionChains WHERE Billed = 1

	-- Delete any items in the correction chain that are not represented on the master cert list
	DELETE FROM @CorrectionChains
	WHERE CertificationID NOT IN (
		SELECT CertificationID
		FROM @RelevantCertifications)
		
	-- Again purge the list of any chains that have only one member, this is exactly the same delete
	-- that we did above, but we have to re-apply this because we may have new chains that can be eliminated
	DELETE FROM @CorrectionChains
	WHERE ChainCounter IN (
		SELECT ChainCounter
		FROM @CorrectionChains
		GROUP BY ChainCounter
		HAVING COUNT(ChainCounter) = 1) 

	-- Remove from our master cert table all of the certs except the last one in the chain, this removes all of the original
	-- certs that from this point on will always be ignored, they joined the ranks of the permanently ignored
	DELETE FROM @RelevantCertifications
	WHERE CertificationID IN (
		SELECT cc.CertificationID 
		FROM @CorrectionChains cc
		WHERE cc.CertificationID <> (SELECT TOP 1 CertificationID 
										FROM @CorrectionChains cc2
										WHERE cc2.ChainCounter = cc.ChainCounter
										ORDER BY Sequence DESC))

	RETURN
END
GO
