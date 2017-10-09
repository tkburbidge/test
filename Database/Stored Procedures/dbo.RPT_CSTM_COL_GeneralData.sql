SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Josh Grigg
-- Create date: October 17, 2016
-- Description:	Does some important sproc type work highlighting the ponytail
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_COL_GeneralData] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		EXEC [RPT_COL_OutstandingCollectionAccounts] @propertyIDs

		EXEC [RPT_CSTM_PRTY_BuildingInfo] @propertyIDs, @date

		EXEC [RPT_CSTM_PRTY_PropertyInfo] @propertyIDs, @date

		EXEC [RPT_CSTM_PRTY_Unit] @propertyIDs, @date, 1

		EXEC [RPT_CSTM_PRTY_UnitType] @propertyIDs, @date

END
GO
