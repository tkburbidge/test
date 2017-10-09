SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 5, 2012
-- Description:	Scheduled Task to be run each night to go through all of the Lease Contracts and change the status from Pending Renewal to Current if they have started.
-- =============================================
CREATE PROCEDURE [dbo].[TSK_ConvertRenewedLeaseToCurrentLease] 
	-- Add the parameters for the stored procedure here
	@date date = null,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )

	IF ((SELECT COUNT(*) FROM @propertyIDs) = 0)
	BEGIN
		INSERT INTO #PropertyIDs SELECT PropertyID FROM Property
	END
	ELSE
	BEGIN
		INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs
	END

	CREATE TABLE #LeasesToRenew (
		LeaseID uniqueidentifier not null,
		OldLeaseID uniqueidentifier not null,
		AccountID bigint not null,
		PropertyID uniqueidentifier not null,
		UnitNumber nvarchar(50) not null
		)
		
	INSERT INTO #LeasesToRenew
		SELECT DISTINCT l.LeaseID AS 'LeaseID', lcur.LeaseID AS 'OldLeaseID', l.AccountID AS 'AccountID', ut.PropertyID AS 'PropertyID', u.Number AS 'UnitNumber'
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Lease lcur ON ulg.UnitLeaseGroupID = lcur.UnitLeaseGroupID AND lcur.LeaseStatus IN ('Current', 'Under Eviction')
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertyIDs #p ON #p.PropertyID = ut.PropertyID
				-- Make sure the lease is signed
				LEFT JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.LeaseSignedDate IS NOT NULL AND pl.ResidencyStatus NOT IN ('Cancelled')
			WHERE l.LeaseStatus = 'Pending Renewal'
			  AND l.LeaseStartDate <= @date
			  -- Make sure the lease is signed
			  AND pl.PersonLeaseID IS NOT NULL
		  
	INSERT INTO ActivityLog
		SELECT NEWID(), AccountID, 'BeginLeaseContract', null, 'Lease', LeaseID, PropertyID, 'Pending Renewal Lease for Unit ' + UnitNumber + ' converted to Current', 
				GETDATE(), null, 0, null, null, null
			FROM #LeasesToRenew 
		
	UPDATE l SET LeaseStatus = 'Current'
		FROM Lease l
			INNER JOIN #LeasesToRenew ltr ON l.LeaseID = ltr.LeaseID
		WHERE l.LeaseID = ltr.LeaseID	
		
	UPDATE pl SET ResidencyStatus = 'Current'
		FROM PersonLease pl
			INNER JOIN #LeasesToRenew ltr ON pl.LeaseID = ltr.LeaseID
		WHERE pl.LeaseID = ltr.LeaseID
		  AND pl.ResidencyStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer', 'Approved')
		  
	UPDATE l SET LeaseStatus = 'Renewed'
		FROM Lease l
			INNER JOIN #LeasesToRenew ltr ON l.LeaseID = ltr.OldLeaseID
		WHERE l.LeaseID = ltr.OldLeaseID
		
	UPDATE pl SET ResidencyStatus = 'Renewed'
		FROM PersonLease pl
			INNER JOIN #LeasesToRenew ltr ON pl.LeaseID = ltr.OldLeaseID
		WHERE pl.LeaseID = ltr.OldLeaseID
		  AND pl.ResidencyStatus IN ('Current')
		  
END
GO
