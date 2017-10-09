SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Craig Perkins
-- Create date: July 14, 2014
-- Description:	Gets applicants and current residents
-- =============================================
CREATE PROCEDURE [dbo].[API_GetCreditReportingResidentEnrollment] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@integrationPartnerID int,
	@propertyID uniqueidentifier = null,	
	@modifiedSince datetime = null,
	@personID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT DISTINCT
		l.LeaseID,
		p.PersonID,
		l.LeaseStatus AS 'Status',
		pl.ResidencyStatus AS 'ResidencyStatus',
		p.LastModified,
		b.PropertyID,
		ulg.UnitLeaseGroupID,
		p.FirstName,
		p.MiddleName,
		p.LastName,
		u.Number AS 'Unit',
		b.Name AS 'Building',
		a.StreetAddress,
		a.City,
		a.State,
		a.Zip,
		p.Email,
		CASE WHEN (p.Phone1Type = 'Mobile') THEN p.Phone1
			 WHEN (p.Phone2Type = 'Mobile') THEN p.Phone2
			 WHEN (p.Phone3Type = 'Mobile') THEN p.Phone3
			 ELSE null END AS 'MobilePhone',
		CASE WHEN (p.Phone1Type = 'Home') THEN p.Phone1
			 WHEN (p.Phone2Type = 'Home') THEN p.Phone2
			 WHEN (p.Phone3Type = 'Home') THEN p.Phone3
			 ELSE null END AS 'HomePhone',
		CASE WHEN (p.Phone1Type = 'Work') THEN p.Phone1
			 WHEN (p.Phone2Type = 'Work') THEN p.Phone2
			 WHEN (p.Phone3Type = 'Work') THEN p.Phone3
			 ELSE null END AS 'WorkPhone',
		l.LeaseStartDate,
		l.LeaseEndDate,	
		pl.MoveInDate,
		pl.MoveOutDate,
		pl.MainContact,		
		p.BirthDate,
		p.SSN,
		cripi.Value3 AS 'Membership',
		ISNULL(cr.IsActive, 0) AS 'IsActive',
		cr.CreditBureau 'Bureau'
	FROM Person p
		INNER JOIN PersonLease pl ON pl.PersonID = p.PersonID
		INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
		INNER JOIN IntegrationPartnerItemProperty ipip ON ipip.AccountID = u.AccountID AND ipip.PropertyID = b.PropertyID
		INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = ipip.IntegrationPartnerItemID AND ipi.IntegrationPartnerID = @integrationPartnerID
		LEFT JOIN CreditReportingPerson cr ON cr.PersonID = p.PersonID 
		LEFT JOIN IntegrationPartnerItem cripi ON cripi.IntegrationPartnerItemID = cr.IntegrationPartnerItemID
		INNER JOIN [Address] a ON a.AddressID = u.AddressID		
	WHERE 
		p.AccountID = @accountID
		AND (@propertyID IS NULL OR b.PropertyID = @propertyID)
		AND (@personID IS NULL OR p.PersonID = @personID)
		AND (@personID IS NOT NULL OR @modifiedSince IS NULL OR p.LastModified >= @modifiedSince)
		AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
						 FROM Lease l2
							INNER JOIN Ordering o ON o.Value = l2.LeaseStatus
						 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						 ORDER BY o.OrderBy)
		AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Pending', 'Pending Renewal', 'Approved', 'Pending Transfer')
		AND (pl.MoveOutDate IS NULL OR DATEADD(MONTH, 3, pl.MoveOutDate) > GETDATE())
		AND (cr.CreditReportingPersonID IS NULL OR 
			 cr.CreditReportingPersonID = (SELECT TOP 1 cr2.CreditReportingPersonID
									 FROM CreditReportingPerson cr2
										INNER JOIN IntegrationPartnerItem ipi ON ipi.IntegrationPartnerItemID = cr2.IntegrationPartnerItemID AND ipi.IntegrationPartnerID = @integrationPartnerID
									 WHERE cr2.PersonID = p.PersonID))
	END
GO
