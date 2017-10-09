SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Josh Grigg
-- Create date: October 20, 2016
-- Description:	Does some important sproc type work highlighting the ponytail
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_TRNS_GeneralData] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
	@accountingPeriodID uniqueidentifier = null,
	@transactionCategories StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @date date = @endDate

	if(@date IS NULL)
	BEGIN
		SELECT @date = MAX(pap.EndDate)
						FROM @propertyIDs pIDs
							LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	END

	EXEC [RPT_TNS_TransactionLists] @startDate, @endDate, @propertyIDs, @transactionCategories, @accountingPeriodID

		EXEC [RPT_CSTM_PRTY_BuildingInfo] @propertyIDs, @date

		EXEC [RPT_CSTM_PRTY_PropertyInfo] @propertyIDs, @date

		EXEC [RPT_CSTM_PRTY_Unit] @propertyIDs, @date, 1

		EXEC [RPT_CSTM_PRTY_UnitType] @propertyIDs, @date

END
GO
