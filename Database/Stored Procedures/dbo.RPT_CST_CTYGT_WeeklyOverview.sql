SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Mar. 15, 2017
-- Description:	Gets the data for the City Gate Custom Box Score
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_CTYGT_WeeklyOverview] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection  READONLY, 
	@date date = null
AS

DECLARE @i int = -4				-- The negative of the number of weeks we need to return, less one, since we want to end on ZERO!
DECLARE @accountID bigint = 0
DECLARE @accountingPeriodID uniqueidentifier = null

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #WeeksToGrowAPonytail (
		[Sequence] int identity,
		WeekEndDate date null
		)

	CREATE TABLE #PropertiesAndDates (
		[Sequence] int null,
		PropertyID uniqueidentifier null,
		StartDate date null,
		EndDate date null
		)

	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		PendingApplicationDate date null,
		PendingMoveInDate date null)

	CREATE TABLE #WeaklyOverviewReport (
		PropertyID uniqueidentifier not null,
		TotalUnits int null,
		WeekEndDate date not null,
		Billed money null,
		ActualCollected money null,
		Budget money null,
		Delinquency money null,
		OccupancyPercent decimal(8, 4) null,
		TrendPercent decimal(8, 4) null,					-- Total of Vacant, not leased, and NTV, not leased
		MoveIns int null,
		MoveOuts int null,
		Vacants int null,
		Ready int null					-- Appears to be Ready, but vacant
		)

	WHILE (@i <= 0)
	BEGIN
		INSERT #WeeksToGrowAPonytail VALUES (DATEADD(WEEK, @i, (DATEADD(DAY, -1, @date))))
		
		SET @i = @i + 1
	END

	INSERT #PropertiesAndDates
		SELECT	#w2gaPT.[Sequence], pIDs.Value, DATEADD(DAY, -6, #w2gaPT.WeekEndDate), #w2gaPT.WeekEndDate
			FROM @propertyIDs pIDs
				INNER JOIN #WeeksToGrowAPonytail #w2gaPT ON 1 = 1

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertiesAndDates))

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs	

	INSERT #WeaklyOverviewReport
		SELECT	#pad.PropertyID,
				null,
				#pad.EndDate,
				pwd.BilledCharges,
				pwd.ActualCollected,
				pwd.Budget,
				pwd.Deliquency,
				null,
				null,
				null,
				null,
				null,
				null
			FROM #PropertiesAndDates #pad
				LEFT JOIN PropertyWarehouseData pwd ON #pad.PropertyID = pwd.PropertyID AND #pad.EndDate = pwd.[Date]

	UPDATE #WeaklyOverviewReport SET TotalUnits = (SELECT COUNT(DISTINCT #lau.UnitID)
													   FROM #LeasesAndUnits #lau
													   WHERE #lau.PropertyID = #WeaklyOverviewReport.PropertyID)

	UPDATE #WeaklyOverviewReport SET OccupancyPercent = (SELECT COUNT(DISTINCT #lau.UnitID)
															  FROM #LeasesAndUnits #lau
																  INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
															  WHERE #lau.PropertyID = #WeaklyOverviewReport.PropertyID
																AND #pad.EndDate = #WeaklyOverviewReport.WeekEndDate
																AND #lau.OccupiedUnitLeaseGroupID IS NOT NULL
																AND #lau.OccupiedMoveInDate <= #pad.EndDate
																AND ((#lau.OccupiedMoveOutDate IS NULL) OR (#lau.OccupiedMoveOutDate > #pad.EndDate)))

	UPDATE #WeaklyOverviewReport SET TrendPercent = (SELECT COUNT(DISTINCT #lau.UnitID)
														  FROM #LeasesAndUnits #lau
															  INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
														  WHERE #lau.PropertyID = #WeaklyOverviewReport.PropertyID
															AND #pad.EndDate = #WeaklyOverviewReport.WeekEndDate
															AND ((#lau.PendingUnitLeaseGroupID IS NULL)
															  AND ((#lau.OccupiedUnitLeaseGroupID IS NULL) OR (#lau.OccupiedNTVDate <= #pad.EndDate))))

	UPDATE #WeaklyOverviewReport SET OccupancyPercent = CAST(OccupancyPercent AS decimal(8, 4)) / CAST(TotalUnits AS decimal(8, 4))

	UPDATE #WeaklyOverviewReport SET TrendPercent = CAST(TrendPercent AS decimal(8, 4)) / CAST(TotalUnits AS decimal(8, 4))

	UPDATE #WeaklyOverviewReport SET MoveIns = (SELECT COUNT(DISTINCT #lau.UnitID)
													 FROM #LeasesAndUnits #lau
													     INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
													 WHERE #lau.PropertyID = #WeaklyOverviewReport.PropertyID
													   AND #pad.EndDate = #WeaklyOverviewReport.WeekEndDate
													   AND #lau.OccupiedMoveInDate >= #pad.StartDate
													   AND #lau.OccupiedMoveInDate <= #pad.EndDate)

	UPDATE #WeaklyOverviewReport SET MoveOuts = (SELECT COUNT(DISTINCT #lau.UnitID)
													 FROM #LeasesAndUnits #lau
													     INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
													 WHERE #lau.PropertyID = #WeaklyOverviewReport.PropertyID
													   AND #pad.EndDate = #WeaklyOverviewReport.WeekEndDate
													   AND #lau.OccupiedMoveOutDate >= #pad.StartDate
													   AND #lau.OccupiedMoveOutDate <= #pad.EndDate)

	UPDATE #WeaklyOverviewReport SET Vacants = (SELECT COUNT(DISTINCT #lau.UnitID)
													 FROM #LeasesAndUnits #lau
													     INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
													 WHERE #lau.PropertyID = #WeaklyOverviewReport.PropertyID
													   AND #pad.EndDate = #WeaklyOverviewReport.WeekEndDate
													   AND ((#lau.OccupiedUnitLeaseGroupID IS NULL) OR (#lau.OccupiedMoveInDate >= #pad.EndDate)))

	UPDATE #WeaklyOverviewReport SET Ready = (SELECT COUNT(DISTINCT #lau.UnitID)
												  FROM #LeasesAndUnits #lau
													  INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
													  CROSS APPLY dbo.GetUnitStatusByUnitID(#lau.UnitID, #pad.EndDate) [UStat]
												  WHERE [UStat].[Status] = 'Ready'
												    AND ((#lau.OccupiedUnitLeaseGroupID IS NULL) OR (#lau.OccupiedMoveOutDate < #pad.StartDate))
													AND #lau.PropertyID = #WeaklyOverviewReport.PropertyID
													AND #pad.EndDate = #WeaklyOverviewReport.WeekEndDate)


	SELECT	#weak.PropertyID,
			p.Name AS 'PropertyName',
			p.LegalName AS 'PropertyLegalName',
			#weak.TotalUnits,
			#weak.WeekEndDate,
			ISNULL(#weak.Billed, 0) AS 'Billed',
			ISNULL(#weak.ActualCollected, 0) AS 'ActualCollected',
			ISNULL(#weak.Budget, 0) AS 'Budget',
			ISNULL(#weak.Delinquency, 0) AS 'Delinquency',
			ISNULL(#weak.OccupancyPercent, 0) AS 'OccupancyPercent',
			ISNULL(#weak.TrendPercent, 0) AS 'TrendPercent',
			ISNULL(#weak.MoveIns, 0) AS 'MoveIns',
			ISNULL(#weak.MoveOuts, 0) AS 'MoveOuts',
			ISNULL(#weak.Vacants, 0) AS 'Vacants',
			ISNULL(#weak.Ready, 0) AS 'Ready'
		FROM #WeaklyOverviewReport #weak
			INNER JOIN Property p ON #weak.PropertyID = p.PropertyID
		ORDER BY PropertyID, WeekEndDate DESC

END
GO
