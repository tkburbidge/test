SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[GetAffordableProgramName] 
(	
	-- Add the parameters for the function here
	@certificationID uniqueidentifier,
	@includeTaxCredit bit = 1,
	@includeHud bit = 1,
	@unitID uniqueidentifier = null,
	@accountID BIGINT,
	@passbookRate DECIMAL,
	@assetImputationLimit INT
)
RETURNS @table TABLE(
CerticationID UNIQUEIDENTIFIER NOT NULL,
ProgramName VARCHAR(100) NULL
) 
AS
BEGIN
DECLARE @section8ami int = dbo.[CalculateSection8AMI](@certificationID, @accountID, @passbookRate, @assetImputationLimit)
 
INSERT INTO @table
	-- Add the SELECT statement with parameter references here
	SELECT 	@certificationID AS 'CerticationID',
			(CASE 
				WHEN @certificationID IS NOT NULL 
				THEN
					STUFF((SELECT ', ' +
									CASE
										WHEN (@includeHud = 1 AND ap.IsHUD = 1 AND apa.ContractNumber IS NULL) THEN
											CASE
												WHEN (apa.SubsidyType = 'Section 8' AND @section8ami = 80) THEN apa.SubsidyType + ' ' + 'LI'
												WHEN (apa.SubsidyType = 'Section 8' AND @section8ami = 50) THEN apa.SubsidyType + ' ' + 'VLI'
												WHEN (apa.SubsidyType = 'Section 8' AND @section8ami = 30) THEN apa.SubsidyType + ' ' + 'ELI'
												ELSE apa.SubsidyType
											END
										WHEN (@includeHud = 1 AND ap.IsHUD = 1 AND apa.ContractNumber IS NOT  NULL) THEN
											CASE
												WHEN (apa.SubsidyType = 'Section 8' AND @section8ami = 80) THEN apa.SubsidyType + ' ' + 'LI' + ' - ' + apa.ContractNumber
												WHEN (apa.SubsidyType = 'Section 8' AND @section8ami = 50) THEN apa.SubsidyType + ' ' + 'VLI' + ' - ' + apa.ContractNumber
												WHEN (apa.SubsidyType = 'Section 8' AND @section8ami = 30) THEN apa.SubsidyType + ' ' + 'ELI' + ' - ' + apa.ContractNumber
												ELSE apa.SubsidyType + ' - ' + apa.ContractNumber
											END
										WHEN (@includeTaxCredit = 1 AND ap.IsHUD = 0) THEN ap.Name + ' - ' + apa.Name
										END					
								FROM Certification certif
									INNER JOIN CertificationAffordableProgramAllocation certifAPA ON certif.CertificationID = certifAPA.CertificationID
									INNER JOIN AffordableProgramAllocation apa ON certifAPA.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
									INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
								WHERE certif.CertificationID = @certificationID
								ORDER BY apa.AmiPercent, apa.Name
								FOR XML PATH ('')), 1, 2, '')
				ELSE
					STUFF((SELECT ', ' +
									CASE
										WHEN (@includeHud = 1 AND ap.IsHUD = 1 AND apa.ContractNumber IS NULL) THEN apa.SubsidyType
										WHEN (@includeHud = 1 AND ap.IsHUD = 1 AND apa.ContractNumber IS NOT  NULL) THEN apa.SubsidyType + ' - ' + apa.ContractNumber
										WHEN (@includeTaxCredit = 1 AND ap.IsHUD = 0) THEN ap.Name + ' - ' + apa.Name
										END					
								FROM AffordableProgramAllocation apa
									INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
									INNER JOIN UnitAffordableProgramDesignation uapd ON apa.AffordableProgramAllocationID = uapd.AffordableProgramAllocationID
								WHERE uapd.UnitID = @unitID
								ORDER BY apa.AmiPercent, apa.Name
								FOR XML PATH ('')), 1, 2, '')
			END) AS 'ProgramName'


RETURN
END
GO
