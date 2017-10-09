SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Thomas Hutchins
-- CREATE date: Feb 15, 2017
-- Description:	Gets a collection of Displayable Repayment Certifications
-- =============================================
CREATE PROCEDURE [dbo].[GetDisplayableRepaymentCertSelections] 
	-- Add the parameters for the stored procedure here
	@accountID BIGINT = null,
	@ulgID UNIQUEIDENTIFIER,
	@apaID UNIQUEIDENTIFIER = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result SETs FROM
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #DisplayableRepaymentCertSelection 
	(
		  CertID UNIQUEIDENTIFIER,
		  UnitNumber NVARCHAR(100),
		  [Transaction] NVARCHAR(100),
		  EffectiveDate DATE,
		  EndDate DATE,
		  Correction BIT,
		  AssistancePayment DECIMAL,
		  PreviousAssistancePayment DECIMAL,
		  SubsidyType NVARCHAR(100)
	)

	DECLARE @transferGroupID UNIQUEIDENTIFIER,
			@types stringcollection

	SET @transferGroupID = (SELECT TOP 1 TransferGroupID FROM UnitLeaseGroup ulg WHERE ulg.UnitLeaseGroupID = @ulgID)

	IF (@transferGroupID IS NULL)
	BEGIN
		SET @transferGroupID = @ulgID
	END


	INSERT INTO #DisplayableRepaymentCertSelection
		SELECT DISTINCT
			c.CertificationID AS 'CertID',
			u.Number AS 'UnitNumber',
			c.[Type] AS 'Transaction',
			c.EffectiveDate AS 'EffectiveDate',
			COALESCE(nc.EffectiveDate, EOMONTH(sub.StartDate), IIF(GETDATE() < c.RecertificationDate, GETDATE(), c.RecertificationDate)) AS 'EndDate',
			c.IsCorrection AS 'Correction',
			ISNULL(c.HUDAssistancePayment, 0) AS 'AssistancePayment',
			COALESCE(cc.HUDAssistancePayment, pc.HUDAssistancePayment, 0) AS 'PreviousAssistancePayment',
			apa.SubsidyType AS 'SubsidyType'
		FROM Certification c
			LEFT JOIN Lease l ON c.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN CertificationStatus cs ON cs.CertificationStatusID = (SELECT TOP 1 CertificationStatusID 
																			 FROM CertificationStatus
																			 WHERE CertificationID = c.CertificationID
																			 ORDER BY DateCreated DESC)
			INNER JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
			LEFT JOIN Certification cc ON c.IsCorrection = 1 AND cc.CorrectedByCertificationID = c.CertificationID
			LEFT JOIN Certification pc ON c.IsCorrection = 0 AND (pc.CertificationID = dbo.GetPreviousCertificationID(@accountID, null, c.CertificationID, @types, 1, 1, c.CertificationGroupID))
			LEFT JOIN Certification nc on nc.CertificationID IN (SELECT TOP 1 ncis.CertificationID FROM Certification ncis 
																	LEFT JOIN Certification ncisc ON ncis.CorrectedByCertificationID = ncisc.CertificationID
																 WHERE ncis.EffectiveDate > c.EffectiveDate AND ncis.CertificationGroupID = c.CertificationGroupID
																	AND (SELECT TOP 1 csncis.[Status] FROM CertificationStatus csncis WHERE CertificationID = ncis.CertificationID ORDER BY DateCreated DESC) = 'Completed'
																	AND ISNULL((SELECT TOP 1 csncisc.[Status] FROM CertificationStatus csncisc WHERE CertificationID = ncisc.CertificationID ORDER BY DateCreated DESC), '') <> 'Completed'
																 ORDER BY ncis.EffectiveDate)
			LEFT JOIN AffordableSubmission sub ON sub.AffordableSubmissionID IN (SELECT TOP 1 sub1.AffordableSubmissionID FROM AffordableSubmission sub1
																					INNER JOIN AffordableSubmissionPayment asp ON asp.AffordableSubmissionID = sub1.AffordableSubmissionID AND asp.Code = 'VSP00'
																				 WHERE sub1.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
																				 ORDER BY sub1.StartDate DESC)
		WHERE c.AccountID = @accountID
			AND (c.UnitLeaseGroupID = @transferGroupID OR ulg.TransferGroupID = @transferGroupID)
			AND c.FlaggedForRepayment = 1
			AND ap.IsHUD = 1
			AND cs.[Status] = 'Completed'
			AND (@apaID IS NULL OR apa.AffordableProgramAllocationID = @apaID)

	SELECT * FROM #DisplayableRepaymentCertSelection

END
GO
