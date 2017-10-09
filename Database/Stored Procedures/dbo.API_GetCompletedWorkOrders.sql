SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Craig Perkins
-- Create date: October 25, 2013
-- Description:	Gets completed work orders within a date range
-- =============================================
CREATE PROCEDURE [dbo].[API_GetCompletedWorkOrders] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT DISTINCT
		pr.PersonID,
		p.PropertyID AS 'PropertyID',
		wo.WorkOrderID,
		--wo.PropertyID,
		--p.Name AS 'PropertyName',
		pr.FirstName,
		pr.LastName,
		a.StreetAddress,
		u.Number AS 'UnitNumber',
		a.City,
		a.[State],
		a.Zip,
		pr.Email,
		wo.Number AS 'WorkOrderNumber',
		wo.CompletedDate AS 'CompletionDate',
		pr.Birthdate,
		COALESCE(pr.IsMale, CAST(1 AS BIT)) AS 'IsMale',
		--ut.SquareFootage AS 'UnitSquareFeet',
		u.SquareFootage AS 'UnitSquareFeet',
		--ps.Name AS 'ProspectSource',
		l.LeaseStartDate,
		l.LeaseEndDate
	FROM WorkOrder wo
		INNER JOIN Property p ON wo.PropertyID = p.PropertyID
		INNER JOIN Unit u ON u.UnitID = wo.ObjectID
		INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		INNER JOIN [Address] a ON u.AddressID = a.AddressID
		INNER JOIN Person pr on wo.ReportedPersonID = pr.PersonID
		INNER JOIN PersonLease pl ON pl.PersonID = pr.PersonID
		INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
	WHERE 
		wo.AccountID = @accountID
		AND wo.PropertyID IN (SELECT Value FROM @propertyIDs)
		AND wo.Status = 'Completed'
		AND wo.CompletedDate >= @startDate
		AND wo.CompletedDate <= @endDate
		AND wo.ObjectType = 'Unit'
		AND ulg.UnitID = wo.ObjectID
		-- Only get the last lease associated with the UnitLeaseGroup
		AND l.LeaseID = (SELECT TOP 1 LeaseID 
						FROM Lease
						WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
						ORDER BY DateCreated DESC)
	END


GO
