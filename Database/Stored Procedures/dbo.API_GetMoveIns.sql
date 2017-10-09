SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: October 25, 2013
-- Description:	Gets move-ins
-- =============================================
CREATE PROCEDURE [dbo].[API_GetMoveIns] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
	@integrationPartnerID int,
	@statuses StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #Statuses (Value nvarchar(20) not null)
	CREATE TABLE #LeaseStatuses (Value nvarchar(20) not null)

	INSERT INTO #Statuses SELECT Value FROM @statuses
	INSERT INTO #LeaseStatuses SELECT Value FROM @statuses

	IF (EXISTS(SELECT Value FROM #Statuses WHERE Value = 'Approved'))
	BEGIN
		INSERT INTO #LeaseStatuses VALUES ('Pending')
	END

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier not null)

	IF ((SELECT COUNT(*) FROM @propertyIDs) <> 0)
	BEGIN
		INSERT INTO #PropertyIDs 
			SELECT * FROM @propertyIDs
	END
	ELSE
	BEGIN
		INSERT INTO #PropertyIDs
			SELECT DISTINCT PropertyID
				FROM IntegrationPartnerItemProperty ipip
				INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID
				WHERE ipip.AccountID = @accountID
				AND ipi.IntegrationPartnerID = @integrationPartnerID
	END

	SELECT	DISTINCT
		pr.PersonID,
		p.PropertyID AS 'PropertyID',
		l.LeaseID,
		l.UnitLeaseGroupID,
		--p.Name AS 'PropertyName',
		pr.FirstName,
		pr.LastName,
		pr.PreferredName + ' ' + pr.LastName AS 'ResidentName',
		fa.StreetAddress AS 'FromStreetAddress',
		fa.City AS 'FromCity',
		fa.[State] AS 'FromState',
		fa.Zip AS 'FromZip',
		u.Number AS 'UnitNumber',
		a.StreetAddress AS 'ToStreetAddress',
		a.City AS 'ToCity',
		a.[State] AS 'ToState',
		a.Zip AS 'ToZip',
		a.StreetAddress AS 'StreetAddress',
		a.City AS 'City',
		a.[State] AS 'State',
		a.Zip AS 'Zip',
		pr.Email AS 'Email',
		pl.MoveInDate AS 'MoveInDate',
		pl.MoveOutDate AS 'MoveOutDate',
		pr.Birthdate,
		COALESCE(pr.IsMale, CAST(1 AS BIT)) AS 'IsMale',
		u.SquareFootage AS 'UnitSquareFeet',
		--ps.Name AS 'ProspectSource',
		l.LeaseStartDate,
		l.LeaseEndDate,
		pl.ResidencyStatus AS 'Status'
	FROM UnitLeaseGroup ulg
		INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON ulg.UnitID = u.UnitID
		INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		INNER JOIN Property p ON ut.PropertyID = p.PropertyID
		LEFT JOIN UnitLeaseGroup pulg ON ulg.PreviousUnitLeaseGroupID = pulg.UnitLeaseGroupID
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.MainContact = 1
		INNER JOIN Person pr ON pr.PersonID = pl.PersonID
		INNER JOIN [Address] a ON u.AddressID = a.AddressID
		LEFT JOIN [Address] fa ON pr.PersonID = fa.ObjectID AND fa.AddressType = 'Prospect'
		INNER JOIN #PropertyIDs pid ON p.PropertyID = pid.PropertyID
		--LEFT JOIN Prospect pros ON pr.PersonID = pros.PersonID
		--LEFT JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pros.PropertyProspectSourceID
		--LEFT JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
	WHERE
		(SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN (SELECT Value FROM #Statuses) AND PersonLease.LeaseID = l.LeaseID) >= @startDate
		AND (SELECT MIN(MoveInDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN (SELECT Value FROM #Statuses) AND PersonLease.LeaseID = l.LeaseID) <= @endDate
		AND l.LeaseStatus IN (SELECT Value FROM #LeaseStatuses)
		AND pl.ResidencyStatus IN (SELECT Value FROM #Statuses)
		AND pl.MoveInDate >= @startDate 
		AND pl.MoveInDate <= @endDate
		-- Make sure lease isn't transferred
		AND pulg.UnitLeaseGroupID IS NULL
		-- Only get the first lease associated with the UnitLeaseGroup
		AND l.LeaseID = (SELECT TOP 1 LeaseID 
						FROM Lease
						WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								AND LeaseStatus IN (SELECT Value FROM #LeaseStatuses)
						ORDER BY LeaseStartDate)
		AND ulg.AccountID = @accountID
	END



GO
