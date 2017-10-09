SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick B
-- Create date: Jan 9, 2014
-- Description:	Calls a Function!
-- =============================================
CREATE PROCEDURE [dbo].[CalculateDepositInterestSproc]
	@propertyID uniqueidentifier,
	@objectIDs GuidCollection READONLY,
	@date date = null,
	@balance money = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT * FROM CalculateDepositInterest(@propertyID, @objectIDs, @date, @balance)

	
END






SET ANSI_NULLS ON
GO
