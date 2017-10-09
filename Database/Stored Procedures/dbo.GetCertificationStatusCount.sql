SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetCertificationStatusCount] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@date datetime,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		EndDate [Date] NOT NULL)

	CREATE TABLE #result ( 
	PropertyID uniqueidentifier,
	PropertyName nvarchar(50) not null,
	PendingVerification int, 
	PendingApproval int,
	Approved int, 
	Denied int,
	CorrectionsNeeded int,
	PreApprovedWithCorrections int,
	CompletedUnreported int)

	INSERT #PropertiesAndDates 
		SELECT #pids.PropertyID, COALESCE(pap.EndDate, @date)
			FROM #PropertyIDs #pids 
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT INTO #result (PropertyID, PropertyName)
		SELECT #pad.PropertyID,
			p.Name
		FROM #PropertiesAndDates #pad
			INNER JOIN Property p ON #pad.PropertyID = p.PropertyID


	UPDATE #result SET PendingVerification = (SELECT COUNT(*) 
												FROM CertificationStatus cs 
													JOIN Certification c ON cs.CertificationID = c.CertificationID
													JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													JOIN Unit u ON ulg.UnitID = u.UnitID 
													JOIN Building b ON u.BuildingID = b.BuildingID
													JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
												WHERE cs.AccountID = @accountID 
													AND cs.DateCreated < #pad.EndDate 
													AND cs.[Status] = 'PendingVerification' 
													AND cs.DateCreated = (SELECT TOP 1 DateCreated FROM CertificationStatus WHERE CertificationID = cs.CertificationID and cs.DateCreated < #pad.EndDate ORDER BY DateCreated DESC))
		
	UPDATE #result SET PendingApproval = (SELECT COUNT(*) 
											FROM CertificationStatus cs 
												JOIN Certification c ON cs.CertificationID = c.CertificationID 
												JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
												JOIN Unit u ON ulg.UnitID = u.UnitID 
												JOIN Building b ON u.BuildingID = b.BuildingID
												JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
											WHERE cs.AccountID = @accountID 
												AND cs.DateCreated < #pad.EndDate 
												AND cs.[Status] = 'PendingApproval' 
												AND cs.DateCreated = (SELECT TOP 1 DateCreated FROM CertificationStatus WHERE CertificationID = cs.CertificationID and cs.DateCreated < #pad.EndDate ORDER BY DateCreated DESC))
		
	UPDATE #result SET Approved = (SELECT COUNT(*) 
									FROM CertificationStatus cs 
										JOIN Certification c ON cs.CertificationID = c.CertificationID 
										JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										JOIN Unit u ON ulg.UnitID = u.UnitID 
										JOIN Building b ON u.BuildingID = b.BuildingID
										JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
									WHERE cs.AccountID = @accountID 
										AND cs.DateCreated < #pad.EndDate 
										AND cs.[Status] = 'Approved' 
										AND cs.DateCreated = (SELECT TOP 1 DateCreated FROM CertificationStatus WHERE CertificationID = cs.CertificationID and cs.DateCreated < #pad.EndDate ORDER BY DateCreated DESC))
		
	UPDATE #result SET Denied = (SELECT COUNT(*)
									FROM CertificationStatus cs 
										JOIN Certification c ON cs.CertificationID = c.CertificationID 
										JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										JOIN Unit u ON ulg.UnitID = u.UnitID 
										JOIN Building b ON u.BuildingID = b.BuildingID
										JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
									WHERE cs.AccountID = @accountID 
										AND cs.DateCreated < #pad.EndDate 
										AND cs.[Status] = 'Denied' 
										AND cs.DateCreated = (SELECT TOP 1 DateCreated FROM CertificationStatus WHERE CertificationID = cs.CertificationID and cs.DateCreated < #pad.EndDate ORDER BY DateCreated DESC))

	UPDATE #result SET CorrectionsNeeded = (SELECT COUNT(*) 
												FROM CertificationStatus cs 
													JOIN Certification c ON cs.CertificationID = c.CertificationID 
													JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													JOIN Unit u ON ulg.UnitID = u.UnitID 
													JOIN Building b ON u.BuildingID = b.BuildingID
													JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
												WHERE cs.AccountID = @accountID 
													AND cs.DateCreated < #pad.EndDate 
													AND cs.[Status] = 'CorrectionsNeeded' 
													AND cs.DateCreated = (SELECT TOP 1 DateCreated FROM CertificationStatus WHERE CertificationID = cs.CertificationID and cs.DateCreated < #pad.EndDate ORDER BY DateCreated DESC))

	UPDATE #result SET PreApprovedWithCorrections = (SELECT COUNT(*) 
														FROM CertificationStatus cs 
															JOIN Certification c ON cs.CertificationID = c.CertificationID 
															JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
															JOIN Unit u ON ulg.UnitID = u.UnitID 
															JOIN Building b ON u.BuildingID = b.BuildingID
															JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
														WHERE cs.AccountID = @accountID 
															AND cs.DateCreated < #pad.EndDate 
															AND cs.[Status] = 'PreApprovedWithCorrections' 
															AND cs.DateCreated = (SELECT TOP 1 DateCreated FROM CertificationStatus WHERE CertificationID = cs.CertificationID and cs.DateCreated < #pad.EndDate ORDER BY DateCreated DESC))
		
	UPDATE #result SET CompletedUnreported = (SELECT COUNT(*) 
												FROM Certification c 
													JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
													JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID 
													JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID 
													LEFT JOIN AffordableSubmissionItem asi ON capa.CertificationAffordableProgramAllocationID = asi.ObjectID 
													JOIN #PropertiesAndDates #pad ON ap.PropertyID = #pad.PropertyID
												WHERE c.AccountID = @accountID 
													AND c.EffectiveDate < #pad.EndDate 
													AND asi.[Status] IS NULL 
													AND ap.IsHUD = 1 
													AND  (SELECT TOP 1 [Status] FROM CertificationStatus where CertificationID = c.CertificationID AND DateCreated < #pad.EndDate ORDER BY DateCreated DESC) = 'Completed')

	SELECT * FROM #result

END
GO
