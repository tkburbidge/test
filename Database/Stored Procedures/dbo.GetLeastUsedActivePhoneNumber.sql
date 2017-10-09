SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 9, 2014
-- Description:	Selects the most least used phone number
-- =============================================
CREATE PROCEDURE [dbo].[GetLeastUsedActivePhoneNumber]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT TOP 1 PhoneNumber
		FROM
			(SELECT ppn.PhoneNumber, COUNT(pSMStpp.PersonID) AS 'MyCounter'
				FROM PropertyPhoneNumber ppn
					INNER JOIN PersonSMSTextPhoneProperty pSMStpp ON ppn.PhoneNumber = pSMStpp.ReceivesTextsFromPhoneNumber
					INNER JOIN Person per ON pSMStpp.PersonID = per.PersonID
					INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID AND pl.ResidencyStatus IN ('Current', 'Under Eviction')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
				WHERE ppn.IsActive = 1
				  AND ppn.PropertyID = @propertyID
				GROUP BY ppn.PhoneNumber) AS [FoneNumbers]
		ORDER BY MyCounter
	
END
GO
