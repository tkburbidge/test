SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 27, 2016
-- Description:	Rentlytics Integration Marketing Query
-- =============================================
CREATE PROCEDURE [dbo].[TSK_RENTLYTICS_GetMarketingProspects]
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS

DECLARE @firstDayLastMonth date

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Prospects (
		property_code nvarchar(50) null,
		unit_code nvarchar(50) null,
		prospect_code uniqueidentifier null,
		resident_code uniqueidentifier null,
		name nvarchar(100) null,
		[address] nvarchar(100) null,
		email nvarchar(100) null,
		work_phone nvarchar(20) null,
		home_phone nvarchar(20) null,
		primary_source nvarchar(50) null,
		primary_agent nvarchar(50) null,
		first_contacted date null,
		first_shown date null)

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier null)

	INSERT #PropertyIDs
		SELECT Value FROM @propertyIDs

	SET @firstDayLastMonth = (SELECT dbo.GetFirstDayOfLastMonth(@date))

	INSERT #Prospects
		SELECT	DISTINCT
				prop.Abbreviation,
				null,
				pros.ProspectID,
				pros.PersonID,
				null,
				null,
				null,
				null, 
				null, 
				null, 
				null,
				null,
				null
			FROM PersonNote pn
				INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID
				INNER JOIN #PropertyIDs #pIDs ON pn.PropertyID = #pIDs.PropertyID
				INNER JOIN PersonType pt ON pros.PersonID = pt.PersonID
				INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID
				INNER JOIN Property prop ON ptp.PropertyID = prop.PropertyID
			WHERE pn.PersonType = 'Prospect'
			  AND pn.[Date] >= @firstDayLastMonth
			  AND pn.[Date] <= @date
	
	UPDATE #Prospects SET unit_code = (SELECT u.Number
										   FROM Unit u
											   INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
											   INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
											   INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
										   WHERE l.LeaseID = (SELECT TOP 1 LeaseID
																  FROM Lease
																  WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																    --AND LeaseStatus NOT IN ('Cancelled', 'Denied')
																  ORDER BY LeaseStartDate)
										     AND pl.PersonID = #Prospects.resident_code)

	UPDATE #Prospects SET primary_source = (SELECT ps.Name
											   FROM Prospect pros
												   INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
												   INNER JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
											   WHERE pros.ProspectID = #Prospects.prospect_code)

	UPDATE #Prospects SET primary_agent = (SELECT per.FirstName + ' ' + per.LastName
											   FROM Prospect pros
												   INNER JOIN PersonTypeProperty ptp ON pros.ResponsiblePersonTypePropertyID = ptp.PersonTypePropertyID
												   INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
												   INNER JOIN Person per ON pt.PersonID = per.PersonID
											   WHERE pros.ProspectID = #Prospects.prospect_code)

	UPDATE #Prospects SET first_shown = (SELECT TOP 1 pn.[Date]
											 FROM PersonNote pn
												 INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID
											 WHERE pn.InteractionType = 'Unit Shown'
											   AND pros.ProspectID = #Prospects.prospect_code
											 ORDER BY pn.[Date])

	UPDATE #pros SET name = per.PreferredName + ' ' + per.LastName,
					 email = per.Email,
					 work_phone = CASE WHEN (per.Phone1Type = 'Work') THEN per.Phone1
									   WHEN (per.Phone2Type = 'Work') THEN per.Phone2
									   WHEN (per.Phone2Type = 'Work') THEN per.Phone3
									   END,
					 home_phone = CASE WHEN (per.Phone1Type = 'Mobile') THEN per.Phone1
									   WHEN (per.Phone2Type = 'Mobile') THEN per.Phone2
									   WHEN (per.Phone2Type = 'Mobile') THEN per.Phone3
									   END

		FROM #Prospects #pros
			INNER JOIN Person per ON #pros.resident_code = per.PersonID

	SELECT	DISTINCT	
			property_code,
			unit_code,
			prospect_code,
			resident_code,
			primary_source,
			primary_agent,
			CONVERT(varchar(10), first_shown, 120) AS 'first_shown',
			name,
			work_phone
			home_phone,
			email
		FROM #Prospects



END
GO
