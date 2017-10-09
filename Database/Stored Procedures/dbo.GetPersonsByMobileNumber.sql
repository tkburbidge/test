SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Jordan Betteridge
-- Create date: September 23, 2014
-- UpdatedBy:	Sam Bryan
-- Update date: September 3, 2015
-- Description:	Gets all people associated with the mobile number
-- =============================================
CREATE PROCEDURE [dbo].[GetPersonsByMobileNumber] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@toNumber nvarchar(15),
	@mobileNumber nvarchar(15) 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #People (
		PropertyID			 uniqueidentifier		not null,
		PersonID			 uniqueidentifier		not null,
		PersonType			 nvarchar(50)			not null,
		Name				 nvarchar(50)			null,
		TimeZoneID			 nvarchar(50)			not null,
		PropertyAbbreviation nvarchar(50)			not null,
		UnitNumber			 nvarchar(50)			null)

	INSERT INTO #People
		SELECT
			p.PropertyID,
			per.PersonID,
			pt.[Type] AS 'PersonType',
			per.PreferredName + ' ' + per.LastName AS 'Name',
			p.TimeZoneID AS 'PropertyTimeZone',
			p.Abbreviation AS 'PropertyAbbreviation',
			null
		FROM Person per
			INNER JOIN PersonType pt on pt.PersonID = per.PersonID
			INNER JOIN PersonTypeProperty ptp on ptp.PersonTypeID = pt.PersonTypeID
			INNER JOIN Property p on p.PropertyID = ptp.PropertyID
			INNER JOIN PropertyPhoneNumber ppn ON ppn.PropertyID = p.PropertyID AND ppn.PhoneNumber = @toNumber
		WHERE per.AccountID = @accountID
		  --AND pt.[Type] IN ('Resident')
		  AND (RIGHT(dbo.[RemoveNonNumericCharacters](per.Phone1),10) = @mobileNumber
			OR RIGHT(dbo.[RemoveNonNumericCharacters](per.Phone2),10) = @mobileNumber
			OR RIGHT(dbo.[RemoveNonNumericCharacters](per.Phone3),10) = @mobileNumber)

	UPDATE #People SET UnitNumber = (
		SELECT u.Number
		FROM PersonLease pl
			INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
			INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u on ulg.UnitID = u.UnitID
			INNER JOIN Building b on u.BuildingID = b.BuildingID
		WHERE pl.PersonID = #People.PersonID
			AND b.PropertyID = #People.PropertyID
			AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
				FROM Lease l2
					INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l2.LeaseStatus
				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
				ORDER BY o.OrderBy))

		SELECT * FROM #People

END
GO
