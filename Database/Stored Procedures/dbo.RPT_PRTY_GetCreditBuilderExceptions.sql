SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
















CREATE PROCEDURE [dbo].[RPT_PRTY_GetCreditBuilderExceptions] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@includeCancelledSubscriptions bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #CreditCancelledPeeps (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(100) null,
		LeaseID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		[Name] nvarchar(500) null,
		PhoneNumber nvarchar(50) null,
		Email nvarchar(250) null,
		StartDate date null,
		DateCancelled date null,
		DateEligibleToReEnroll date null,
		NumberOnTimePayments int null,
		SubscriptionMethod nvarchar(250) null,
		CancellationMethod nvarchar(250) null)

	CREATE TABLE #CreditBuilderNotSubscribedPeeps (
		PersonID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(100) null,
		LeaseID uniqueidentifier not null,
		[Name] nvarchar(500) null,
		PhoneNumber nvarchar(50) null,
		Email nvarchar(250) null,
		NumberOnTimePayments int null,
		LastContactDate date null,
		LastContactNote nvarchar(max) null,
		LastBulkMessageDate date null,
		Declined bit null)


	CREATE TABLE #MyProperties (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(500) null,
		MinimumApplicantAge int null,
		MinBirthdate date null)

	INSERT #MyProperties
		SELECT	pIDs.Value,
				prop.Name,
				prop.MinimumApplicantAge,
				DATEADD(YEAR, -prop.MinimumApplicantAge, GETDATE())
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIDs.Value = prop.PropertyID

	INSERT #CreditCancelledPeeps
		SELECT	#myProp.PropertyID,
				#myProp.PropertyName,
				u.Number AS 'Unit',
				u.PaddedNumber,
				l.LeaseID,
				per.PersonID,
				per.PreferredName + ' ' + per.LastName AS 'Name',
				per.Phone1 AS 'PhoneNumber',
				per.Email,
				crp.StartDate,
				crp.EndDate AS 'DateCancelled',
				CASE 
					WHEN (renewedL.LeaseID IS NOT NULL) THEN renewedL.LeaseStartDate
					ELSE l.LeaseEndDate END AS 'DateEligibleToReEnroll',
				(SELECT DATEDIFF(MONTH, firstL.LeaseStartDate, GETDATE()) + 1
				 -
				 (SELECT COUNT(DISTINCT ULGAPInformationID)
					FROM ULGAPInformation
					WHERE ObjectID = ulg.UnitLeaseGroupID
					  AND Late = 1)) AS 'NumberOnTimePayments',
				crp.SubscriptionSource,
				null AS 'CancellationMethod' --crp.CancellationSource AS 'CancellationMethod' when implemented
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID 
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #MyProperties #myProp ON ut.PropertyID = #myProp.PropertyID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
				INNER JOIN Lease firstL ON ulg.UnitLeaseGroupID = firstL.UnitLeaseGroupID AND firstL.LeaseID = (SELECT TOP 1 LeaseID
																													FROM Lease 
																													WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																													ORDER BY LeaseStartDate)
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ResidencyStatus IN ('Current', 'Under Eviction')
				INNER JOIN Person per ON pl.PersonID = per.PersonID AND per.Birthdate <= #myProp.MinBirthdate
				INNER JOIN CreditReportingPerson crp ON per.PersonID = crp.PersonID
				LEFT JOIN Lease renewedL ON ulg.UnitLeaseGroupID = renewedL.UnitLeaseGroupID AND renewedL.LeaseStatus IN ('Pending Renewal')
			WHERE crp.EndDate IS NOT NULL

	INSERT #CreditBuilderNotSubscribedPeeps
		SELECT	per.PersonID,
				#myProp.PropertyID,
				#myProp.PropertyName,
				u.Number AS 'Unit',
				u.PaddedNumber,
				l.LeaseID,
				per.PreferredName + ' ' + per.LastName AS 'Name',
				per.Phone1 AS 'PhoneNumber',
				per.Email,
				(SELECT DATEDIFF(MONTH, firstL.LeaseStartDate, GETDATE()) + 1
				 -
				 (SELECT COUNT(DISTINCT ULGAPInformationID)
					FROM ULGAPInformation
					WHERE ObjectID = ulg.UnitLeaseGroupID
					  AND Late = 1)) AS 'NumberOnTimePayments',
				null AS 'LastContactDate',
				null AS 'LastContactNote',
				null AS 'LastBulkMessageDate',
				CASE 
					WHEN (crp.IntegrationPartnerItemID = 248) THEN CAST(1 AS bit)
					ELSE CAST(0 AS bit) END AS 'Declined'
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID 
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #MyProperties #myProp ON ut.PropertyID = #myProp.PropertyID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
				INNER JOIN Lease firstL ON ulg.UnitLeaseGroupID = firstL.UnitLeaseGroupID AND firstL.LeaseID = (SELECT TOP 1 LeaseID
																													FROM Lease 
																													WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																													ORDER BY LeaseStartDate)
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ResidencyStatus IN ('Current', 'Under Eviction')
				INNER JOIN Person per ON pl.PersonID = per.PersonID AND per.Birthdate <= #myProp.MinBirthdate
				LEFT JOIN CreditReportingPerson crp ON per.PersonID = crp.PersonID AND crp.IntegrationPartnerItemID IN (247, 248)
			WHERE crp.CreditReportingPersonID IS NULL	--No Credit Reporting Record
			   OR crp.IntegrationPartnerItemID = 248	--Has Declined

	UPDATE #cbnsp SET LastContactDate = pn.[Date], LastContactNote = pn.[Description]
		FROM  #CreditBuilderNotSubscribedPeeps #cbnsp
			LEFT JOIN PersonNote pn ON pn.PersonNoteID = (SELECT TOP 1 pn.PersonNoteID
															FROM PersonNote pn
															WHERE pn.InteractionType IN ('Credit Builder')
																AND pn.PersonID = #cbnsp.PersonID
															ORDER BY pn.[Date] DESC, pn.DateCreated DESC)

	UPDATE #cbnsp SET LastBulkMessageDate = er.DateSent
		FROM #CreditBuilderNotSubscribedPeeps #cbnsp
			LEFT JOIN EmailRecipient er ON er.EmailRecipientID = (SELECT TOP 1 er.EmailRecipientID
															FROM EmailRecipient er
																INNER JOIN EmailJob ej ON er.EmailJobID = ej.EmailJobID
																INNER JOIN EmailTemplate et on ej.EmailTemplateID = et.EmailTemplateID
															WHERE er.PersonID = #cbnsp.PersonID
																AND et.NotificationID = 37
																AND er.DateSent IS NOT NULL
															ORDER BY er.DateSent DESC, er.DateCreated DESC)

	SELECT *
		FROM #CreditCancelledPeeps
		ORDER BY PropertyName, PaddedUnit, Name

	SELECT *
		FROM #CreditBuilderNotSubscribedPeeps
		ORDER BY PropertyName, PaddedUnit, Name

END

GO
