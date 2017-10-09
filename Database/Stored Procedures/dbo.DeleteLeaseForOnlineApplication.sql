SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Tony Morgan
-- Create date: 04/26/16
-- Description:	Deletes an applicant's application when they don't pay in time
-- =============================================
CREATE PROCEDURE [dbo].[DeleteLeaseForOnlineApplication]
	-- Add the parameters for the stored procedure here
	@accountID BIGINT, 
	@applicationInformationID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @leaseID uniqueidentifier
	DECLARE @unitLeaseGroupID uniqueidentifier

	SET @leaseID = (SELECT LeaseID FROM ApplicantInformation WHERE ApplicantInformationID = @applicationInformationID AND AccountID = @accountID)
	SET @unitLeaseGroupID = (SELECT ulg.UnitLeaseGroupID 
							 FROM UnitLeaseGroup ulg
								INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseID = @leaseID AND l.AccountID = @accountID)

	CREATE TABLE #PersonIDs
	(
		PersonID uniqueidentifier
	)

	INSERT #PersonIDs SELECT p.PersonID 
					  FROM Person p
						INNER JOIN PersonLease pl on p.PersonID = pl.PersonID AND pl.LeaseID = @leaseID
						

    DELETE ptp
	FROM PersonTypeProperty ptp
		INNER JOIN PersonType pt on ptp.PersonTypeID = pt.PersonTypeID AND pt.[Type] = 'Resident'
		INNER JOIN Person p on p.PersonID = pt.PersonID
		INNER JOIN PersonLease pl on p.PersonID = pl.PersonID
	WHERE
		pl.LeaseID = @leaseID AND pl.AccountID = @accountID

	DELETE pt
	FROM PersonType pt
		INNER JOIN Person p on p.PersonID = pt.PersonID AND pt.[Type] = 'Resident'
		INNER JOIN PersonLease pl on p.PersonID = pl.PersonID
	WHERE
		pl.LeaseID = @leaseID AND pl.AccountID = @accountID

	DELETE lli
	FROM LeaseLedgerItem lli
	WHERE lli.LeaseID = @leaseID AND lli.AccountID = @accountID

	DELETE ApplicantInformationPerson
	WHERE ApplicantInformationID = @applicationInformationID AND AccountID = @accountID

	DELETE ApplicantInformation
	WHERE ApplicantInformationID = @applicationInformationID AND AccountID = @accountID

	DELETE PersonLease
	WHERE LeaseID = @leaseID AND AccountID = @accountID

	DELETE Lease
	WHERE LeaseID = @leaseID AND AccountID = @accountID

	DELETE UnitLeaseGroup
	WHERE UnitLeaseGroupID = @unitLeaseGroupID AND AccountID = @accountID

	SELECT PersonID FROM #PersonIDs
END
GO
