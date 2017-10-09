SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 3, 2013
-- Description:	Gets the data for the ChargeDistribution index page.
-- =============================================
CREATE PROCEDURE [dbo].[GetListChargeDistribution]
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null, 
	@startDate date = null,
	@endDate date = null,
	@sortBy nvarchar(50) = null,
	@page int = 0,
	@pageSize int = 0,
	@sortOrderIsAsc bit = 1,
	@totalCount int OUTPUT
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ChargeDistributions (
		ChargeDistributionID uniqueidentifier NULL,
		PostingDate date NULL,
		Name varchar(1000) NULL,
		ExcludeVacantUnits BIT NULL,
		BilledAmount money NULL,
		DistributedAmount money NULL,
		ChargedAmount money NULL,
		IsPosted bit NULL)
		
	CREATE TABLE #ChargeDistributions2 (
		Sequence int identity,
		ChargeDistributionID uniqueidentifier NULL,
		PostingDate date NULL,
		Name varchar(1000) NULL,
		ExcludeVacantUnits BIT NULL,
		BilledAmount money NULL,
		DistributedAmount money NULL,
		ChargedAmount money NULL,
		IsPosted bit NULL)		
	
	INSERT #ChargeDistributions
		SELECT DISTINCT cd.ChargeDistributionID,
				cd.PostingDate,
				cd.Name,
				cd.ExcludeVacantUnits,
				(SELECT SUM(BilledAmount)
					FROM ChargeDistributionDetail
					WHERE ChargeDistributionID = cd.ChargeDistributionID
					GROUP BY ChargeDistributionID),
				(SELECT SUM(Amount)
					FROM ChargeDistributionDetail
					WHERE ChargeDistributionID = cd.ChargeDistributionID
					GROUP BY ChargeDistributionID),
				(SELECT SUM(t.Amount)
					FROM [Transaction] t 
						INNER JOIN ChargeDistributionDetail cdd ON t.PostingBatchID = cdd.PostingBatchID AND cdd.ChargeDistributionID = cd.ChargeDistributionID
					WHERE t.PostingBatchID = cdd.PostingBatchID),
				cd.IsPosted
			FROM ChargeDistribution cd
				--INNER JOIN ChargeDistributionDetail cdd ON cd.ChargeDistributionID = cdd.ChargeDistributionID
			WHERE cd.PropertyID = @propertyID
			  AND cd.PostingDate >= @startDate
			  AND cd.PostingDate <= @endDate
			
	INSERT INTO #ChargeDistributions2
		SELECT *
			FROM #ChargeDistributions
			ORDER BY
				CASE WHEN @sortBy = 'Name' AND @sortOrderIsAsc = 1 THEN [Name] END ASC,
				CASE WHEN @sortBy = 'Name' AND @sortOrderIsAsc = 0 THEN [Name] END DESC,
				CASE WHEN @sortBy = 'ExcludeVacantUnits' AND @sortOrderIsAsc = 1 THEN [ExcludeVacantUnits] END ASC,
				CASE WHEN @sortBy = 'ExcludeVacantUnits' AND @sortOrderIsAsc = 0 THEN [ExcludeVacantUnits] END DESC,
				CASE WHEN @sortBy = 'BilledAmount' AND @sortOrderIsAsc = 1 THEN [BilledAmount] END ASC,
				CASE WHEN @sortBy = 'BilledAmount' AND @sortOrderIsAsc = 0 THEN [BilledAmount] END DESC,
				CASE WHEN @sortBy = 'DistributedAmount' AND @sortOrderIsAsc = 1 THEN [DistributedAmount] END ASC,
				CASE WHEN @sortBy = 'DistributedAmount' AND @sortOrderIsAsc = 0 THEN [DistributedAmount] END DESC,
				CASE WHEN @sortBy = 'ChargedAmount' AND @sortOrderIsAsc = 1 THEN [ChargedAmount] END ASC,
				CASE WHEN @sortBy = 'ChargedAmount' AND @sortOrderIsAsc = 0 THEN [ChargedAmount] END DESC,
				CASE WHEN @sortBy = 'Posted' AND @sortOrderIsAsc = 1 THEN [IsPosted] END ASC,
				CASE WHEN @sortBy = 'Posted' AND @sortOrderIsAsc = 0 THEN [IsPosted] END DESC,												
				CASE WHEN (@sortBy = 'Date' OR @sortBy is NULL OR @sortBy = '') and @sortOrderIsAsc = 1  THEN [PostingDate] END ASC,
				CASE WHEN (@sortBy = 'Date' OR @sortBy is NULL OR @sortBy = '') and @sortOrderIsAsc = 0  THEN [PostingDate] END DESC	
				
	SET @totalCount = (SELECT COUNT(*) FROM #ChargeDistributions2)
	
	SELECT TOP (@pageSize) * 
		FROM
			(SELECT *, ROW_NUMBER() OVER (ORDER BY Sequence) AS [rownumber]
				FROM #ChargeDistributions2) AS PagedChargeDistributions
		WHERE PagedChargeDistributions.rownumber > (((@page - 1) * @pageSize))
		
	
END
GO
