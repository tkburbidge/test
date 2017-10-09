SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Joshua Grigg
-- Create date: June 16, 2015
-- Description:	Gets the needed information for resident invoice header for pending or pending transfer residents
-- =============================================
CREATE PROCEDURE [dbo].[GetResidentInvoiceHeadersForPending]
	@accountID bigint,
	@unitLeaseGroupIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
	SELECT 
		u.Number AS 'UnitNumber', 
		u.PaddedNumber,
		COALESCE(da.StreetAddress, ua.StreetAddress) AS 'UnitStreetAddress',
		COALESCE(da.City, ua.City) AS 'UnitCity',
		COALESCE(da.[State], ua.[State]) AS 'UnitState',
		COALESCE(da.Zip, ua.Zip) AS 'UnitZip',
		(CASE WHEN da.AddressID IS NOT NULL THEN CAST(1 AS BIT)
			  ELSE u.AddressIncludesUnitNumber
		 END) AS 'AddressIncludesUnitNumber',
		STUFF((SELECT ', ' + (FirstName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
		l.LeaseStartDate,
		l.LeaseEndDate,
		l.UnitLeaseGroupID,
		l.LeaseID,
		p.Name AS 'PropertyName',
		pa.StreetAddress AS 'PropertyStreetAddress',
		pa.City AS 'PropertyCity',
		pa.[State] AS 'PropertyState',
		pa.Zip AS 'PropertyZip',
		p.PhoneNumber AS 'PropertyPhone',
		p.Email AS 'PropertyEmail'	
	FROM Lease l
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
		INNER JOIN Property p ON p.PropertyID = b.PropertyID
		LEFT JOIN [Address] pa ON pa.AddressID = p.AddressID
		LEFT JOIN [Address] ua ON ua.AddressID = u.AddressID 
		LEFT JOIN [Address] da ON da.ObjectID = (SELECT TOP 1 PersonID FROM PersonLease WHERE LeaseID = l.LeaseID ORDER BY OrderBy) AND da.IsDefaultMailingAddress = 1
	WHERE l.AccountID = @accountID
		AND l.UnitLeaseGroupID IN (SELECT Value FROM @unitLeaseGroupIDs)
		AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Pending Transfer', 'Pending')
	ORDER BY u.PaddedNumber		
	
END
GO
