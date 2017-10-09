SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 18, 2012
-- Description:	Generates the OutstandingCollectionAccount Report
-- =============================================

CREATE PROCEDURE [dbo].[RPT_COL_OutstandingCollectionAccounts] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT * FROM 
	
	(SELECT DISTINCT
			l.LeaseID,
			cd.ObjectID AS 'ObjectID',
			CASE
				WHEN (ca.CollectionAgreementID IS NULL) THEN 'Pending'
				ELSE ca.CollectionType 
				END AS 'Type',
			'Lease' AS 'ObjectType',
			p.PropertyID AS 'PropertyID',
			p.Name AS 'PropertyName',
			u.UnitID AS 'UnitID',
			u.Number AS 'UnitNumber',
			u.PaddedNumber AS 'PaddedUnitNumber',
			ip.Name AS 'CollectionAgencyName',
			sp.Name AS 'ServiceProviderName',
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '') AS 'Names',			
			(SELECT Max(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID) AS 'MoveOutDate',
			(SELECT SUM(Amount) FROM CollectionDetail WHERE ObjectID = ulg.UnitLeaseGroupID) AS 'CollectionsTotal',
			ca.Amount AS 'AgreementAmount',
			((SELECT SUM(Amount) FROM CollectionDetail WHERE ObjectID = ulg.UnitLeaseGroupID) - 
			(SELECT ISNULL(SUM(t.Amount), 0) 
				FROM [Transaction] t
					LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				WHERE tr.TransactionID IS NULL
				  AND t.AppliesToTransactionID IN (SELECT TransactionID 
													FROM [Transaction] 
													WHERE [TransactionID] IN (SELECT TransactionID
																				  FROM CollectionDetailTransaction
																				  WHERE CollectionDetailID IN (SELECT CollectionDetailID
																													FROM CollectionDetail
																													WHERE ObjectID = ulg.UnitLeaseGroupID)))))
			 AS 'TotalUnpaid',
			 (SELECT TOP 1 TransactionDate FROM [Transaction] WHERE TransactionID IN 
					(SELECT TransactionID FROM CollectionDetail cd1 
							INNER JOIN CollectionDetailTransaction cdt1 ON cd1.CollectionDetailID = cdt1.CollectionDetailID
						WHERE cd1.ObjectID = cd.ObjectID)
					ORDER BY TransactionDate DESC) AS 'LastBilling',
			ca.NoticeSent AS 'NoticeSent'
		FROM CollectionDetail cd
			INNER JOIN UnitLeaseGroup ulg ON cd.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Property p ON ut.PropertyID = p.PropertyID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID 
			LEFT JOIN CollectionAgreement ca ON cd.ObjectID = ca.ObjectID AND (ca.CollectionAgreementID = (SELECT TOP 1 CollectionAgreementID 
																											  FROM CollectionAgreement
																											  WHERE ObjectID = cd.ObjectID
																											  ORDER BY DateCreated DESC))
			LEFT JOIN IntegrationPartnerItem ipi ON ca.IntegrationPartnerItemID = ipi.IntegrationPartnerItemID
			LEFT JOIN IntegrationPartner ip ON ipi.IntegrationPartnerID = ip.IntegrationPartnerID
			LEFT JOIN ServiceProvider sp ON ca.ServiceProviderID = sp.ServiceProviderID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)		
			AND (ca.CollectionAgreementID IS NULL OR ca.IsClosed = 0)
			AND l.LeaseID = (SELECT TOP 1 l2.LeaseID	
							 FROM Lease l2
							 INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l2.LeaseStatus
							 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								AND l2.LeaseStatus NOT IN ('Current', 'Renewed', 'Under Eviction')
							 ORDER BY o.OrderBy) 
	UNION
    
	SELECT DISTINCT
			null,
			cd.ObjectID AS 'ObjectID',
			CASE
				WHEN (ca.CollectionAgreementID IS NULL) THEN 'Pending'
				ELSE ca.CollectionType 
				END AS 'Type',
			'Lease' AS 'ObjectType',
			p.PropertyID AS 'PropertyID',
			p.Name AS 'PropertyName',
			null AS 'UnitID',
			null AS 'UnitNumber',
			null AS 'PaddedUnitNumber',
			ip.Name AS 'CollectionAgencyName',
			sp.Name AS 'ServiceProviderName',
			per.PreferredName + ' ' + per.LastName AS 'Names',			
			null AS 'MoveOutDate',			
			(SELECT SUM(Amount) FROM CollectionDetail WHERE ObjectID = per.PersonID) AS 'CollectionsTotal',
			ca.Amount AS 'AgreementAmount',
						((SELECT SUM(Amount) FROM CollectionDetail WHERE ObjectID = per.PersonID) - 
			(SELECT SUM(t.Amount) 
				FROM [Transaction] t 
					LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				WHERE tr.TransactionID IS NULL
				  AND t.AppliesToTransactionID IN (SELECT TransactionID 
													FROM [Transaction] 
													WHERE [TransactionID] IN (SELECT TransactionID
																				  FROM CollectionDetailTransaction
																				  WHERE CollectionDetailID IN (SELECT CollectionDetailID
																													FROM CollectionDetail
																													WHERE ObjectID = per.PersonID))))) AS 'TotalUnpaid',
			 (SELECT TOP 1 TransactionDate FROM [Transaction] WHERE TransactionID IN 
					(SELECT TransactionID FROM CollectionDetail cd1 
							INNER JOIN CollectionDetailTransaction cdt1 ON cd1.CollectionDetailID = cdt1.CollectionDetailID
						WHERE cd1.ObjectID = cd.ObjectID)
					ORDER BY TransactionDate DESC) AS 'LastBilling',																												
			ca.NoticeSent AS 'NoticeSent'
		FROM CollectionDetail cd
			LEFT JOIN CollectionAgreement ca ON cd.ObjectID = ca.ObjectID AND (ca.CollectionAgreementID = (SELECT TOP 1 CollectionAgreementID 
																											  FROM CollectionAgreement
																											  WHERE CollectionAgreementID = cd.ObjectID
																											  ORDER BY DateCreated DESC))
			INNER JOIN Person per ON cd.ObjectID = per.PersonID
			INNER JOIN PersonType pt ON per.PersonID = pt.PersonID
			INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID
			INNER JOIN Property p ON ptp.PropertyID = p.PropertyID
			LEFT JOIN IntegrationPartnerItem ipi ON ca.IntegrationPartnerItemID = ipi.IntegrationPartnerItemID
			LEFT JOIN IntegrationPartner ip ON ipi.IntegrationPartnerID = ip.IntegrationPartnerID
			LEFT JOIN ServiceProvider sp ON ca.ServiceProviderID = sp.ServiceProviderID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND (ca.CollectionAgreementID IS NULL OR ca.IsClosed = 0)) Accounts
		
	WHERE TotalUnpaid > 0
	ORDER BY PaddedUnitNumber, Names	   
    
END
GO
