SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Craig Perkins
-- Create date: July 21, 2014
-- Description:	Lies on top of same table valued
--				function
-- =============================================
CREATE PROCEDURE [dbo].[GetMarketRentByDateSP]
	@accountID bigint,
	@unitID uniqueidentifier,
	@date date,
	@includeAmenities bit
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT Amount FROM GetMarketRentByDate(@unitID, @date, @includeAmenities)
END

GO
