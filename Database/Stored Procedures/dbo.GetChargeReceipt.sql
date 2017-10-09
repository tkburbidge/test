SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Scott Blanch
-- Create date: 5/14/2015
-- Description:	Gets information for a receipt of a charge
-- =============================================
CREATE PROCEDURE [dbo].[GetChargeReceipt] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@transactionID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT DISTINCT t.TransactionID, 
					prop.Name as 'PropertyName', 
					STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1				   
						 FOR XML PATH ('')), 1, 2, '') AS 'Account',
					t.TransactionDate as 'Date', 
					t.Amount, 
					lit.Name as 'Category',
					t.Note  as 'Notes',
					t.[Description],
					prop.PropertyID,
					ulg.UnitID,
					d.Uri AS 'LogoUrl',
					prop.PortalCssUrl AS 'CssUrl',
					a.StreetAddress AS 'PropertyStreetAddress',
					a.City AS 'PropertyCity',
					a.[State] AS 'PropertyState',
					a.Zip AS 'PropertyZip',
					prop.PhoneNumber AS 'PropertyPhone'
	FROM [Transaction] t
		INNER JOIN [Property] prop on t.PropertyID = prop.PropertyID
		INNER JOIN [UnitLeaseGroup] ulg on t.ObjectID = ulg.UnitLeaseGroupID
		INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		INNER JOIN [TransactionType] tt on t.TransactionTypeID = tt.TransactionTypeID
		INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
		LEFT JOIN [Document] d ON prop.PropertyID = d.ObjectID AND d.[Type] = 'PropertyLogo'
		LEFT JOIN [Address] a ON prop.PropertyID = a.ObjectID AND a.AddressType = 'Property'
	WHERE t.AccountID = @accountID AND t.TransactionID = @transactionID
		AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
						 FROM Lease l2
							INNER JOIN Ordering o ON o.Value = l2.LeaseStatus AND o.[Type] = 'Lease'
						 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						 ORDER BY o.OrderBy)
						 
END
GO
