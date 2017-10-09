SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Craig Perkins
-- Create date: October 25, 2013
-- Description:	Gets expired leases within a date range
-- =============================================
CREATE PROCEDURE [dbo].[API_GetLeaseExpirations] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
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

    SELECT DISTINCT
		pr.PersonID,
		p.PropertyID AS 'PropertyID',
		l.LeaseID,
		--p.Name AS 'PropertyName',
		pr.FirstName,
		pr.LastName,
		a.StreetAddress AS 'StreetAddress',
		u.Number AS 'UnitNumber',
		a.City AS 'City',
		a.[State] AS 'State',
		a.Zip AS 'Zip',
		pr.Email AS 'Email',
		l.LeaseStartDate AS 'LeaseStartDate',
		l.LeaseEndDate AS 'LeaseEndDate',
		pr.Birthdate,
		COALESCE(pr.IsMale, CAST(1 AS BIT)) AS 'IsMale',
		u.SquareFootage AS 'UnitSquareFeet',
		pl.ResidencyStatus AS 'Status'
		--ps.Name AS 'ProspectSource'
	FROM Lease l
		INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		INNER JOIN Unit u on ulg.UnitID = u.UnitID
		INNER JOIN UnitType ut on u.UnitTypeID = ut.UnitTypeID
		INNER JOIN Property p on ut.PropertyID = p.PropertyID
		INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID AND pl.ResidencyStatus IN (SELECT Value FROM #Statuses) AND pl.MainContact = 1
		INNER JOIN Person pr on pl.PersonID = pr.PersonID
		INNER JOIN [Address] a on u.AddressID = a.AddressID
		--LEFT JOIN Prospect pros ON pr.PersonID = pros.PersonID
		--LEFT JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pros.PropertyProspectSourceID
		--LEFT JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
		-- Get the pending renewal lease if they have one
		LEFT JOIN [Lease] rl ON rl.UnitLeaseGroupID = l.UnitLeaseGroupID AND rl.LeaseID <> l.LeaseID AND rl.LeaseStatus = 'Pending Renewal'
	WHERE  l.AccountID = @accountID
		AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
		AND l.LeaseEndDate >= @startDate
		AND l.LeaseEndDate <= @endDate
		AND l.LeaseStatus IN (SELECT Value FROM #LeaseStatuses)
		AND pl.ResidencyStatus IN (SELECT Value FROM #Statuses)
		-- Make sure this lease is not renewing
		AND rl.LeaseID IS NULL		
	END
GO
