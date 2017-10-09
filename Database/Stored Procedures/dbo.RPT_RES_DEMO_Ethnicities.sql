SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Joshua Grigg
-- Create date: May 6, 2015
-- Description:	Gets the data for the Resident Demographic Ethnicity subreport
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_DEMO_Ethnicities] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @accountID bigint = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID in (SELECT Value FROM @propertyIDs))

	CREATE TABLE #OccupantsForEthnicities
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null
	)
	
	CREATE TABLE #EthnicityAndPeeps 
	(
		PropertyID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		Ethnicity nvarchar(100) null 
	)
	
	CREATE TABLE #EthnicityCounts 
	(
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		Ethnicity nvarchar(100) null,
		[Count] int not null
	)
	
	CREATE TABLE #EthnicityAndProperty 
	(
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		Ethnicity nvarchar(100) null,
	)

	INSERT INTO #EthnicityAndProperty
		SELECT DISTINCT
			p.PropertyID,
			p.Name,
			cfo.Value
		FROM CustomField cf
			 INNER JOIN Property p on cf.AccountID = p.AccountID
			 INNER JOIN CustomFieldOption cfo on cf.CustomFieldID = cfo.CustomFieldID
		WHERE cf.Name = 'Ethnicity'
		  AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND cf.IsArchived = 0
	
	INSERT INTO #OccupantsForEthnicities
		EXEC GetOccupantsByDate @accountID, @date, @propertyIDs
	
	
	INSERT INTO #EthnicityAndPeeps
		SELECT	DISTINCT
				prop.PropertyID,
				per.PersonID,
				cfv.Value as 'Ethnicity'
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIds.Value = prop.PropertyID
				INNER JOIN #OccupantsForEthnicities #ofe ON pIDs.Value = #ofe.PropertyID
				INNER JOIN Lease l ON #ofe.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
				INNER JOIN Person per ON pl.PersonID = per.PersonID
				LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND  pli.AccountID = @accountID 
				INNER JOIN CustomField eth ON eth.AccountID = prop.AccountID AND eth.Name = 'Ethnicity'
				LEFT JOIN CustomFieldProperty cfp ON prop.PropertyID = cfp.PropertyID
				LEFT JOIN CustomFieldValue cfv ON per.PersonID = cfv.ObjectID AND eth.CustomFieldID = cfv.CustomFieldID AND cfp.CustomFieldID = cfv.CustomFieldID
				-- Either they are a current resident or their move out date is in the future
			WHERE (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
			  -- They moved in before the date
			  AND pl.MoveInDate <= @date
			  AND eth.IsArchived = 0	
			  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
			  
	INSERT INTO #EthnicityCounts		  
		SELECT	DISTINCT 
				#eap.PropertyID, 
				prop.Name, 
				#eap.Ethnicity, 
				COUNT(*) AS 'Count'
			FROM #EthnicityAndPeeps #eap
				INNER JOIN Property prop ON #eap.PropertyID = prop.PropertyID
			GROUP BY #eap.PropertyID, prop.Name, #eap.Ethnicity 	 
	
	
	INSERT INTO #EthnicityCounts
		SELECT	DISTINCT
				#eap.PropertyID,
				#eap.PropertyName,
				#eap.Ethnicity,
				0
		FROM #EthnicityAndProperty #eap
			LEFT JOIN #EthnicityCounts #ec ON (#eap.Ethnicity = #ec.Ethnicity AND #eap.PropertyID = #ec.PropertyID)
		WHERE #ec.Ethnicity IS NULL

	SELECT * FROM #EthnicityCounts
END
GO
