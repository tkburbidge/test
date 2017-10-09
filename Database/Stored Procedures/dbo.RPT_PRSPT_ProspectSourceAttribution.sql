SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Joshua Grigg
-- Create date: December 2, 2015
-- Description:	Gets data related to Prospect Source Attribution report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_ProspectSourceAttribution]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date,
	@endDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate date null,
		EndDate date null)
	
	
	INSERT #PropertiesAndDates 
		SELECT	pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID


	CREATE TABLE #ResidentActivity (
		PropertyID uniqueidentifier,
		PropertyName nvarchar(50),
		PaddedUnitNumber nvarchar(50),
		UnitNumber nvarchar(50),	
		FirstName nvarchar(30),
		LastName nvarchar(50),
		Email nvarchar(150),
		Phone nvarchar(35),
		MoveInDate date,
		LeadSource nvarchar(100),
		LeaseID uniqueidentifier
	)

	INSERT INTO #ResidentActivity
		SELECT DISTINCT 					
				p.PropertyID,
				p.Name,	
				u.PaddedNumber AS 'PaddedUnitNumber',
				u.Number AS 'UnitNumber',		
				'' AS 'FirstName',
				'' AS 'LastName',
				'' AS 'Email',
				'' AS 'Phone',
				pl.MoveInDate,
				null AS 'LeadSource',
				pl.LeaseID		
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON p.PropertyID = b.PropertyID		
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID																		
				INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
			WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
									  FROM PersonLease pl2
									  WHERE pl2.LeaseID = l.LeaseID
										AND pl2.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
									  ORDER BY pl2.MoveInDate, pl2.OrderBy, pl2.PersonID)		
			  AND pl.MoveInDate >= #pad.StartDate
			  AND pl.MoveInDate <= #pad.EndDate
			  AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
			  AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
			  AND l.LeaseID = (SELECT TOP 1 LeaseID 
							   FROM Lease
							   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
									 AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
							   ORDER BY LeaseStartDate, DateCreated)	

	UPDATE #ResidentActivity 
		SET	
			FirstName = p.PreferredName, 
			LastName = p.LastName, 
			Phone = p.Phone1,
			Email = p.Email
		FROM Person p
			INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID
		WHERE pl.LeaseID = #ResidentActivity.LeaseID																   		   
			AND pl.MainContact = 1

	-- Update prospect id for main prospects
	UPDATE #ResidentActivity SET LeadSource = (SELECT TOP 1 ps.Name
												FROM Prospect pr													  
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #ResidentActivity.LeaseID AND pr.PersonID = pl.PersonID
													INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
												WHERE pps.PropertyID = #ResidentActivity.PropertyID);													   	
	
	WITH prospectSourceAttribution AS(
		SELECT
			PropertyID,
			PropertyName,
			PaddedUnitNumber,
			UnitNumber,	
			FirstName,
			LastName,
			Email,
			Phone,
			MoveInDate,
			LeadSource,
			ROW_NUMBER() OVER(PARTITION BY #ra.LeaseID
								  ORDER BY #ra.MoveInDate asc, #ra.LastName asc, #ra.FirstName asc) as rk
		FROM #ResidentActivity #ra
	)
	SELECT 
		PropertyID,
		PropertyName,
		PaddedUnitNumber,
		UnitNumber,	
		FirstName,
		LastName,
		Email,
		Phone,
		MoveInDate,
		LeadSource
	FROM prospectSourceAttribution
	WHERE rk = 1
	
END
GO
