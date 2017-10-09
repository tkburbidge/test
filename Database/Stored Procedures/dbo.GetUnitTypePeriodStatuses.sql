SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 6/24/2014
-- Description:	For each accounting period that ends between the startDate and the endDate this will return the number of units of each status for each unit type.
-- =============================================
CREATE PROCEDURE [dbo].[GetUnitTypePeriodStatuses] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@propertyID uniqueidentifier,
	@startDate date,
	@endDate date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    CREATE TABLE #unitPeriod (
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		PeriodEndDate date not null,
		--UnitTypeDescription nvarchar(4000) not null,
		--UnitTypeName nvarchar(250) not null
    )
    
    INSERT #unitPeriod
		SELECT u.UnitID, ut.UnitTypeID, pap.EndDate--, ut.[Description], ut.Name
			FROM Unit u
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				INNER JOIN AccountingPeriod ap ON ap.AccountID = u.AccountID
				INNER JOIN PropertyAccountingPeriod pap ON ap.AccountingPeriodID = pap.AccountingPeriodID AND p.PropertyID = pap.PropertyID
			WHERE u.AccountID = @accountID
			  AND p.PropertyID = @propertyID
			  AND @startDate <= pap.EndDate
			  AND pap.EndDate <= @endDate
		  
	SELECT #up.PeriodEndDate AS 'PeriodEndDate', 
		   us.[Status] AS 'Status', 
		   #up.UnitTypeID AS 'UnitTypeID', 
		   COUNT(#up.UnitID) AS 'Count'
		   --#up.UnitTypeDescription AS 'UnitTypeDescription',
		   --#up.UnitTypeName AS 'UnitTypeName'
		FROM #unitPeriod #up
			CROSS APPLY GetUnitStatusByUnitID(#up.UnitID, #up.PeriodEndDate) us
		GROUP BY #up.PeriodEndDate, us.[Status], #up.UnitTypeID
	
END



GO
