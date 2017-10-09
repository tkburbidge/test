SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Tony Morgan
-- Create date: 11/15/2016
-- Description:	Pulls the student warehouse data for leasing analytics
-- =============================================
CREATE PROCEDURE [dbo].[GetStudentWarehouseData]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@date date,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #propertyIDs ( Value uniqueidentifier not null )
	INSERT #propertyIDs SELECT Value FROM @propertyIDs

	CREATE TABLE #TrendData
	(
		WeekNumber int not null,
		[Year] int not null,
		ActualCount int null,
		GoalCount int null,
		PrevYrCount int null,
		ActualPercentage decimal null,
		GoalPercentage decimal null,
		PrevYrPercentage decimal null
	)

	CREATE TABLE #UnitTypeData
	(
		UnitTypeID uniqueidentifier not null,
		UnitTypeName nvarchar(250) not null,
		PropertyID uniqueidentifier not null,
		UnitCount int not null,
		OccupancyPercentage decimal not null,
		PreleasePercentage decimal null,
		UnitsRemaining int null,
		NewLeads int null,
		NewSignedLeases int null,
		Renewals int null,
		RenewalPercentage decimal null,
		PreviousYearRenewalVariance decimal null,
		AverageEffectiveRent money null,
		AverageNewRent money null,
		RentChange money null,
		AverageRenewalRent money null
	)

	CREATE TABLE #LeasingAgentData
	(
		PersonID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		LeasingAgentName nvarchar(250) not null,
		Today int null,
		[Week] int null,
		[Month] int null,
		CloseRate decimal null,
		FollowUpRate decimal null
	)

	CREATE TABLE #PropertyData
	(
		PropertyID  uniqueidentifier not null,
        PropertyName nvarchar(50) not null,
		UnitCount int null,
        LeasesToday int null,
        LeasesWeek  int null,
        LeasesMonth int null,
        CloseRate decimal null,
        FollowUpRate decimal null,
        AverageEffectiveRent money null,
        PrevWkAverageEffectiveRent money null,
        NewEffectiveRent money null,
        PrevWkNewEffectiveRent money null,
        RenewalEffectiveRent money null,
        PrevWkRenewalEffectiveRent money null,
        PreleasePercentage decimal null,
        PreleaseGoal decimal null,
        PrevYrPreleasePercentage decimal null,
        RenewalPercentage decimal null,
        RenewalGoal decimal null,
        PrevYrRenewalPercentage decimal null,
        LeadCount int null,
        LeadGoal int null,
        PrevYrLeadCount int null,
        ApplicantCount int null,
        ApplicantGoal int null, 
        PrevYrApplicantCount int null, 
        LeaseCount int null, 
        LeaseGoal int null, 
        PrevYrLeaseCount int null 
	)
	
	CREATE TABLE #PropertyCampaigns
	(
		PropertyCampaignID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null
	)

	CREATE TABLE #UnitCountWeek
	(
		WeekNumber int not null,
		UnitCount int not null,
	)

	CREATE TABLE #PropertyWarehouseData
	(
		STUDWarehousePropertyID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		[Date] date not null,
		WeekNumber int not null,
		UnitCount int NOT NULL,
		OccupiedCount int NOT NULL,
		RenewalsTotal int NOT NULL,
		Leads int NOT NULL,
		Applicants int NOT NULL,
		SignedLeases int NOT NULL,
		AverageEffectiveRent money NOT NULL
	)

	CREATE TABLE #PreviousPropertyWarehouseData
	(
		STUDWarehousePropertyID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		[Date] date not null,
		WeekNumber int not null,
		UnitCount int NOT NULL,
		OccupiedCount int NOT NULL,
		RenewalsTotal int NOT NULL,
		Leads int NOT NULL,
		Applicants int NOT NULL,
		SignedLeases int NOT NULL,
		AverageEffectiveRent money NOT NULL
	)

	CREATE TABLE #UnitTypeWarehouseData
	(
		STUDWarehouseUnitTypeID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		[Date] date not null,
		WeekNumber int not null,
		UnitCount int not null,
		OccupiedCount int not null,
		Leads int not null,
		SignedLeases int not null,
		RenewalsTotal int not null,
		AverageEffectiveRent money not null,
		AverageNewRent money not null,
		RentChange money not null,
		AverageRenewalRent money not null
	)

	CREATE TABLE #PreviousUnitTypeWarehouseData
	(
		STUDWarehouseUnitTypeID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		[Date] date not null,
		WeekNumber int not null,
		UnitCount int not null,
		OccupiedCount int not null,
		Leads int not null,
		SignedLeases int not null,
		RenewalsTotal int not null,
		AverageEffectiveRent money not null,
		AverageNewRent money not null,
		RentChange money not null,
		AverageRenewalRent money not null
	)

	CREATE TABLE #LeasingAgentWarehouseData
	(
		STUDWarehouseLeasingAgentID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		[Date] date not null,
		WeekNumber int not null,
		SignedLeaseCount int not null,
		ProspectCount int not null,
		FollowUpCount int not null
	)

	INSERT #PropertyCampaigns 
		SELECT pc.PropertyCampaignID, pc.PropertyID, pc.StartDate, pc.EndDate 
			FROM PropertyCampaign pc 
			WHERE pc.PropertyID IN (SELECT Value FROM #propertyIDs) 
				AND pc.IsActive = 1

	INSERT #PropertyWarehouseData SELECT wp.* 
									  FROM #PropertyCampaigns #pc
										   INNER JOIN STUDWarehouseProperty wp on wp.PropertyID = #pc.PropertyID 
												AND wp.[Date] >= #pc.StartDate AND wp.[Date] <= #pc.EndDate

	INSERT #PreviousPropertyWarehouseData SELECT wpp.*
											  FROM STUDWarehouseProperty wpp
											  WHERE EXISTS(SELECT * FROM #PropertyWarehouseData #pw 
																WHERE #pw.WeekNumber = wpp.WeekNumber 
																	AND DATEPART(yyyy, #pw.[Date]) = DATEPART(yyyy, wpp.[Date]) + 1
																	AND wpp.PropertyID = #pw.PropertyID)

	INSERT #UnitTypeWarehouseData SELECT wut.* 
									  FROM #PropertyCampaigns #pc
										   INNER JOIN UnitType ut on ut.PropertyID = #pc.PropertyID
										   INNER JOIN STUDWarehouseUnitType wut on wut.UnitTypeID = ut.UnitTypeID 
												AND wut.[Date] >= #pc.StartDate AND wut.[Date] <= #pc.EndDate

	INSERT #PreviousUnitTypeWarehouseData SELECT wput.*
											  FROM STUDWarehouseUnitType wput
											  WHERE EXISTS(SELECT * FROM #UnitTypeWarehouseData #wut 
																WHERE #wut.WeekNumber = wput.WeekNumber 
																	AND DATEPART(yyyy, #wut.[Date]) = DATEPART(yyyy, wput.[Date]) + 1
																	AND wput.UnitTypeID = #wut.UnitTypeID)

	INSERT #LeasingAgentWarehouseData SELECT law.*
								FROM STUDWarehouseLeasingAgent law
										INNER JOIN #PropertyCampaigns #pc on law.PropertyID = #pc.PropertyID
											AND law.[Date] >= #pc.StartDate AND law.[Date] <= #pc.EndDate

	INSERT #UnitTypeData SELECT ut.UnitTypeID, ut.Name, ut.PropertyID, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
							FROM UnitType ut
							WHERE ut.UnitTypeID IN (SELECT #utwd.UnitTypeID FROM #UnitTypeWarehouseData #utwd)

	DECLARE @WeekNumber int = DATEPART(ww, @date)

	UPDATE #UnitTypeData
	SET
		UnitCount = today.UnitCount,
		OccupancyPercentage = today.OccPercent,
		RenewalPercentage = today.RenewalsPercent,
		AverageEffectiveRent = today.AverageEffectiveRent,
		AverageNewRent = today.AverageNewRent,
		RentChange = today.RentChange,
		AverageRenewalRent = today.AverageRenewalRent,
		Renewals = today.RenewalsTotal
	FROM
		(SELECT
			UnitTypeID,
			UnitCount,
			(CAST(OccupiedCount as float) / UnitCount) * 100 as OccPercent,
			(CAST(RenewalsTotal as float) / OccupiedCount) * 100 RenewalsPercent,
			AverageEffectiveRent,
			AverageNewRent,
			RentChange,
			AverageRenewalRent,
			RenewalsTotal
		FROM
			#UnitTypeWarehouseData #utwd
		WHERE
			#utwd.[Date] = @date
		) today
	WHERE
		#UnitTypeData.UnitTypeID = today.UnitTypeID

	UPDATE #UnitTypeData
	SET
		NewLeads = ag.Leads,
		NewSignedLeases = ag.NewLeases
	FROM 
		(SELECT 
			#utwd.UnitTypeID,
			SUM(#utwd.Leads) Leads,
			SUM(#utwd.SignedLeases) NewLeases
		FROM #UnitTypeWarehouseData #utwd
		WHERE #utwd.WeekNumber = @WeekNumber
		GROUP BY #utwd.UnitTypeID) ag
	WHERE ag.UnitTypeID = #UnitTypeData.UnitTypeID

	UPDATE #UnitTypeData 
	SET 
		PreleasePercentage = ag.PreleasePercent,
		UnitsRemaining = ag.UnitsRemaining
	FROM 
		(SELECT 
			#utwd.UnitTypeID,
			(CAST(SUM(#utwd.SignedLeases) + MAX(#today.RenewalsTotal) as float) / MAX(#today.UnitCount)) * 100 PreleasePercent,
			MAX(#today.UnitCount) - (SUM(#utwd.SignedLeases) + MAX(#today.RenewalsTotal)) UnitsRemaining,
			SUM(#utwd.Leads) Leads,
			SUM(#utwd.SignedLeases) NewLeases
		FROM #UnitTypeWarehouseData #utwd
			INNER JOIN #UnitTypeWarehouseData #today ON #today.[Date] = @date
				AND #today.UnitTypeID = #utwd.UnitTypeID
			GROUP BY #utwd.UnitTypeID) ag
		WHERE ag.UnitTypeID = #UnitTypeData.UnitTypeID

	UPDATE #UnitTypeData SET PreviousYearRenewalVariance = RenewalPercentage - ISNULL((SELECT RenewalPercentage 
																				FROM #PreviousUnitTypeWarehouseData #putwd 
																				WHERE #putwd.WeekNumber = @WeekNumber AND #putwd.UnitTypeID = #UnitTypeData.UnitTypeID), 0)


	INSERT #LeasingAgentData SELECT DISTINCT #lawd.PersonID, #lawd.PropertyID, pr.Name, p.FirstName + ' ' + p.LastName, 0, 0, 0, 0, 0
								FROM #LeasingAgentWarehouseData #lawd
									INNER JOIN Person p on p.PersonID = #lawd.PersonID
									INNER JOIN Property pr on pr.PropertyID = #lawd.PropertyID

	UPDATE #LeasingAgentData SET Today = ISNULL((SELECT #lawd.SignedLeaseCount FROM #LeasingAgentWarehouseData #lawd
											WHERE #lawd.[Date] = @date 
												AND #lawd.PersonID = #LeasingAgentData.PersonID
												AND #lawd.PropertyID = #LeasingAgentData.PropertyID), 0)

	UPDATE #LeasingAgentData SET [Week] = ISNULL((SELECT SUM(#lawd.SignedLeaseCount) FROM #LeasingAgentWarehouseData #lawd
												WHERE #lawd.WeekNumber = @WeekNumber
													AND #lawd.PersonID = #LeasingAgentData.PersonID
													AND #lawd.PropertyID = #LeasingAgentData.PropertyID), 0)

	UPDATE #LeasingAgentData SET [Month] = ISNULL((SELECT SUM(#lawd.SignedLeaseCount) FROM #LeasingAgentWarehouseData #lawd
												WHERE DATEPART(mm, #lawd.[Date]) = DATEPART(mm, @date)
													AND #lawd.PersonID = #LeasingAgentData.PersonID
													AND #lawd.PropertyID = #LeasingAgentData.PropertyID), 0)

								
	UPDATE #LeasingAgentData 
		SET 
			CloseRate = ag.CloseRate,
			FollowUpRate = ag.FollowUpRate
	FROM 
		(SELECT
			PropertyID,
			PersonID,
			CASE WHEN SUM(#lawd.ProspectCount) = 0 THEN 0 ELSE SUM(CAST(#lawd.SignedLeaseCount as float)) / SUM(#lawd.ProspectCount) END CloseRate,
			CASE WHEN SUM(#lawd.ProspectCount) = 0 THEN 0 ELSE SUM(CAST(#lawd.FollowUpCount as float)) / SUM(#lawd.ProspectCount) END FollowUpRate
		 FROM #LeasingAgentWarehouseData #lawd
		 GROUP BY PersonID, PropertyID) ag
	WHERE ag.PersonID = #LeasingAgentData.PersonID
		AND ag.PropertyID = #LeasingAgentData.PropertyID
		
	INSERT #PropertyData SELECT PropertyID, Name, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
								0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
							FROM Property WHERE PropertyID IN (SELECT Value FROM #propertyIDs)

	UPDATE #PropertyData SET LeasesToday = ISNULL((SELECT #lawd.SignedLeaseCount FROM #LeasingAgentWarehouseData #lawd
											WHERE #lawd.[Date] = @date 
												AND #lawd.PropertyID = #PropertyData.PropertyID), 0)

	UPDATE #PropertyData SET LeasesWeek = ISNULL((SELECT SUM(#lawd.SignedLeaseCount) FROM #LeasingAgentWarehouseData #lawd
												WHERE #lawd.WeekNumber = @WeekNumber
													AND #lawd.PropertyID = #PropertyData.PropertyID), 0)

	UPDATE #PropertyData SET LeasesMonth = ISNULL((SELECT SUM(#lawd.SignedLeaseCount) FROM #LeasingAgentWarehouseData #lawd
												WHERE DATEPART(mm, #lawd.[Date]) = DATEPART(mm, @date)
													AND #lawd.PropertyID = #PropertyData.PropertyID), 0)
							
	UPDATE #PropertyData
	SET
		CloseRate = ag.CloseRate,
		FollowUpRate = ag.FollowUp
	FROM
		(SELECT
			PropertyID,
			CASE WHEN SUM(#lawd.ProspectCount) = 0 THEN 0 ELSE SUM(#lawd.SignedLeaseCount) / SUM(#lawd.ProspectCount) END CloseRate,
			CASE WHEN SUM(#lawd.ProspectCount) = 0 THEN 0 ELSE SUM(#lawd.FollowUpCount) / SUM(#lawd.ProspectCount) END FollowUp
		FROM
			#LeasingAgentWarehouseData #lawd
		GROUP BY #lawd.PropertyID) ag
	WHERE
		ag.PropertyID = #PropertyData.PropertyID
		
	UPDATE #PropertyData 
	SET 
		UnitCount = UnitSum,
		AverageEffectiveRent = AvgRent,
		NewEffectiveRent = AvgNewRent,
		RenewalEffectiveRent = AvgRenewalRent,
		PreleasePercentage = PreleasePercent,
		RenewalPercentage = RenewalPercent,
		LeadCount = NewLeads,
		LeaseCount = NewSignedLeases
	FROM (SELECT PropertyID, 
			SUM(#utd.UnitCount) UnitSum,
			SUM(#utd.AverageEffectiveRent * #utd.UnitCount) / SUM(#utd.UnitCount) AvgRent,
			SUM(#utd.AverageNewRent * #utd.UnitCount) / SUM(#utd.UnitCount) AvgNewRent,
			SUM(#utd.AverageRenewalRent * #utd.UnitCount) / SUM(#utd.UnitCount) AvgRenewalRent,
			SUM(#utd.PreleasePercentage * #utd.UnitCount) / SUM(#utd.UnitCount) PreleasePercent,
			SUM(#utd.RenewalPercentage * #utd.UnitCount) / SUM(#utd.UnitCount) RenewalPercent,
			SUM(#utd.NewLeads) NewLeads,
			SUM(#utd.NewSignedLeases) NewSignedLeases
		  FROM #UnitTypeData #utd
		  GROUP BY #utd.PropertyID) AS utda
	WHERE utda.PropertyID = #PropertyData.PropertyID

	UPDATE #PropertyData SET ApplicantCount = ISNULL((SELECT SUM(#pwd.Applicants) FROM #PropertyWarehouseData #pwd
												WHERE #pwd.PropertyID = #PropertyData.PropertyID
													  AND #pwd.WeekNumber = @WeekNumber), 0)

	UPDATE #PropertyData 
	SET 
		PrevYrPreleasePercentage = ag.PreleasePercentage
	FROM (SELECT
			PropertyID,
			SUM(#putwd.SignedLeases) / SUM(#putwd.UnitCount) PreleasePercentage
		  FROM
			#PreviousUnitTypeWarehouseData #putwd
		  GROUP BY #putwd.PropertyID) ag
	WHERE ag.PropertyID = #PropertyData.PropertyID

	UPDATE #PropertyData 
	SET 
		PrevWkAverageEffectiveRent = ag.AvgEffRent,
		PrevWkNewEffectiveRent = ag.AvgNewRent,
		PrevWkRenewalEffectiveRent = ag.AvgRenewalRent
	FROM (SELECT
			PropertyID,
			CASE WHEN SUM(#utwd.UnitCount) = 0 THEN 0 ELSE SUM(#utwd.AverageEffectiveRent * #utwd.UnitCount) / SUM(#utwd.UnitCount) END AvgEffRent,
			CASE WHEN SUM(#utwd.UnitCount) = 0 THEN 0 ELSE SUM(#utwd.AverageNewRent * #utwd.UnitCount) / SUM(#utwd.UnitCount) END AvgNewRent,
			CASE WHEN SUM(#utwd.UnitCount) = 0 THEN 0 ELSE SUM(#utwd.AverageRenewalRent * #utwd.UnitCount) / SUM(#utwd.UnitCount) END AvgRenewalRent
		  FROM
			#UnitTypeWarehouseData #utwd
		  WHERE #utwd.WeekNumber = @WeekNumber - 1
		  GROUP BY #utwd.PropertyID) ag
	WHERE ag.PropertyID = #PropertyData.PropertyID

	UPDATE #PropertyData SET PrevYrRenewalPercentage = ISNULL((SELECT #ppwd.RenewalsTotal / #ppwd.UnitCount 
														FROM #PreviousPropertyWarehouseData #ppwd 
														WHERE #ppwd.PropertyID = #PropertyData.PropertyID AND #ppwd.WeekNumber = @WeekNumber), 0)

	UPDATE #PropertyData
	SET
		PrevYrLeadCount = ag.Leads,
		PrevYrApplicantCount = ag.Applicants,
		PrevYrLeaseCount = ag.SignedLeases
	FROM (SELECT
			PropertyID,
			SUM(#ppwd.Leads) Leads,
			SUM(#ppwd.Applicants) Applicants,
			SUM(#ppwd.SignedLeases) SignedLeases
		  FROM #PreviousPropertyWarehouseData #ppwd
		  WHERE #ppwd.WeekNumber = @WeekNumber
		  GROUP BY #ppwd.PropertyID) ag
	WHERE ag.PropertyID = #PropertyData.PropertyID

	UPDATE #PropertyData
	SET
		PreleaseGoal = pcw.PreleasePercentageGoal,
		RenewalGoal = pcw.RenewalPercentageGoal,
		LeadGoal = pcw.TrafficGoal,
		ApplicantGoal = pcw.NewApplicantGoal,
		LeaseGoal = pcw.NewLeaseGoal
	FROM
		#PropertyCampaigns #pc
			INNER JOIN PropertyCampaignWeek pcw on pcw.PropertyCampaignID = #pc.PropertyCampaignID
		WHERE CalendarWeekNumber = @WeekNumber AND #pc.PropertyID = #PropertyData.PropertyID

	INSERT #UnitCountWeek 
		SELECT
			#pwd.WeekNumber, 
			SUM(#pwd.UnitCount)
		FROM #PropertyWarehouseData #pwd
			INNER JOIN (SELECT 
							#pwdr.WeekNumber, #pwdr.PropertyID, MAX(#pwdr.[Date]) [Date] 
						FROM #PropertyWarehouseData #pwdr 
						GROUP BY #pwdr.WeekNumber, #pwdr.PropertyID) c 
				ON 
					c.WeekNumber = #pwd.WeekNumber 
					AND #pwd.PropertyID = c.PropertyID
					AND #pwd.[Date] = c.[Date]
		GROUP BY #pwd.WeekNumber

	INSERT #TrendData SELECT WeekNumber, MAX(DATEPART(yyyy, [Date])), 0, 0, 0, 0, 0, 0
						FROM #PropertyWarehouseData
						GROUP BY WeekNumber

	UPDATE #TrendData SET ActualCount = ISNULL((SELECT SUM(#pwd.SignedLeases) FROM #PropertyWarehouseData #pwd
											WHERE #pwd.WeekNumber = #TrendData.WeekNumber), 0)

	UPDATE #TrendData SET GoalCount = ISNULL((SELECT SUM(pcw.NewLeaseGoal) FROM PropertyCampaignWeek pcw
											WHERE pcw.CalendarWeekNumber = #TrendData.WeekNumber), 0)

	UPDATE #TrendData SET PrevYrCount = ISNULL((SELECT SUM(#ppwd.SignedLeases) FROM #PreviousPropertyWarehouseData #ppwd
											WHERE #ppwd.WeekNumber = #TrendData.WeekNumber), 0)

	UPDATE #TrendData 
	SET 
		ActualPercentage = ISNULL(CAST(ag.ActualSum as float) * 100 / ag.UnitCount, 0)
	FROM 
		(SELECT
			#td.WeekNumber,
			SUM(#tdsum.ActualCount) ActualSum, 
			MAX(#ucw.UnitCount) UnitCount
		FROM #TrendData #td
			INNER JOIN #TrendData #tdsum on #tdsum.WeekNumber <= #td.WeekNumber OR #tdsum.[Year] < #td.[Year]
			INNER JOIN #UnitCountWeek #ucw on #ucw.WeekNumber = #td.WeekNumber
		GROUP BY #td.WeekNumber) ag
	WHERE ag.WeekNumber = #TrendData.WeekNumber

	UPDATE #TrendData SET PrevYrPercentage = ISNULL((SELECT CAST(PrevYrCount as float) / SUM(#putwd.UnitCount) FROM #PreviousUnitTypeWarehouseData #putwd
												WHERE #putwd.WeekNumber = #TrendData.WeekNumber), 0)

	UPDATE #TrendData
	SET
		GoalCount = cg.NewLeaseGoal,
		GoalPercentage = cg.PreleasePercentageGoal
	FROM
		(SELECT
			pcw.CalendarWeekNumber,
			SUM(pcw.NewLeaseGoal) NewLeaseGoal,
			AVG(pcw.PreleasePercentageGoal) PreleasePercentageGoal
		FROM
			#PropertyCampaigns #pc
			INNER JOIN PropertyCampaignWeek pcw on #pc.PropertyCampaignID = pcw.PropertyCampaignID
			GROUP BY pcw.CalendarWeekNumber) cg
	WHERE cg.CalendarWeekNumber = #TrendData.WeekNumber

	SELECT * FROM #TrendData

	SELECT * FROM #UnitTypeData

	SELECT * FROM #LeasingAgentData

	SELECT * FROM #PropertyData
END
GO
