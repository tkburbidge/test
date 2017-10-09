SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: November 7, 2013
-- Description:	Gets on notices
-- =============================================
CREATE PROCEDURE [dbo].[API_GetOnNotices] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier,
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

	SELECT	DISTINCT
		--p.PropertyID AS 'PropertyID',
		--p.Name AS 'PropertyName',
		pr.FirstName,
		pr.LastName,
		pr.PreferredName + ' ' + pr.LastName AS 'ResidentName',
		a.StreetAddress AS 'StreetAddress',
		u.Number AS 'UnitNumber',
		a.City AS 'City',
		a.[State] AS 'State',
		a.Zip AS 'Zip',
		pr.Email AS 'Email',
		pl.MoveInDate AS 'MoveInDate',
		pl.MoveOutDate AS 'MoveOutDate',
		pl.NoticeGivenDate AS 'NoticeGivenDate',
		pl.ResidencyStatus AS 'Status'
	FROM UnitLeaseGroup ulg
		INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON ulg.UnitID = u.UnitID
		INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		INNER JOIN Property p ON ut.PropertyID = p.PropertyID
		LEFT JOIN UnitLeaseGroup nulg ON nulg.PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID
		--LEFT JOIN Unit ou ON pulg.UnitID = ou.UnitID
		LEFT JOIN PersonLease plng ON plng.LeaseID = l.LeaseID AND plng.NoticeGivenDate IS NULL
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.MainContact = 1
		INNER JOIN Person pr ON pr.PersonID = pl.PersonID
		INNER JOIN [Address] a ON u.AddressID = a.AddressID
	WHERE 
		(SELECT MAX(NoticeGivenDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN (SELECT Value FROM #Statuses) AND PersonLease.LeaseID = l.LeaseID) >= @startDate
		AND (SELECT MAX(NoticeGivenDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN (SELECT Value FROM #Statuses) AND PersonLease.LeaseID = l.LeaseID) <= @endDate
		-- Ensure there are not residents on the lease
		-- without a move out date
		AND plng.PersonLeaseID IS NULL
		AND l.LeaseStatus IN (SELECT Value FROM #LeaseStatuses)
		AND pl.ResidencyStatus IN (SELECT Value FROM #Statuses)
		AND p.PropertyID = @propertyID
		AND pl.NoticeGivenDate >= @startDate 
		AND pl.NoticeGivenDate <= @endDate	 
		AND (nulg.UnitLeaseGroupID IS NULL OR 
			-- Or the transferred lease was cancelled
			((SELECT Count(*) FROM Lease WHERE UnitLeaseGroupID = nulg.UnitLeaseGroupID AND LeaseStatus = 'Cancelled') > 0)
			-- AND there is not a non-cancelled lease that was transferred
			-- (Scenario: Transfers to a new unit and that lease cancels and transfers again
			--			  to a different unit.  In this scenario the above case will have a count
			--			  greater than zero but it will not take into account the second transfer.
			AND (SELECT COUNT(*) 
					FROM UnitLeaseGroup 
					INNER JOIN Lease ON Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
					WHERE PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID
					AND LeaseStatus <> 'Cancelled') = 0)
		-- Get the last lease associated with the 
		-- UnitLeaseGroup		
		AND l.LeaseID = (SELECT TOP 1 LeaseID 
						FROM Lease
						WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								AND LeaseStatus IN (SELECT Value FROM #LeaseStatuses)
						ORDER BY LeaseEndDate DESC)
END
GO
