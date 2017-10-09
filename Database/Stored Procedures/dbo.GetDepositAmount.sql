SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 30, 2016
-- Description:	A sproc that wraps the GetDepositFunction so we can call it from C-hashtag codes
-- =============================================
CREATE PROCEDURE [dbo].[GetDepositAmount] 
	-- Add the parameters for the stored procedure here
	@unitIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Units (
		UnitID uniqueidentifier not null)

	INSERT #Units
		SELECT Value
			FROM @unitIDs

	SELECT	#u.UnitID,
			[Deposit].Deposit AS 'Deposit'
		FROM #Units #u 
			CROSS APPLY [dbo].GetRequiredDepositAmount(#u.UnitID, @date) [Deposit]
END

GO
