SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Trevor Burbidge
-- Create date: January 22, 2014
-- Description:	Stored procedure wrapper for GetObjectBalance for many objects
-- =============================================
CREATE PROCEDURE [dbo].[GetObjectBalances] 
	-- Add the parameters for the stored procedure here
	@startDate datetime, 
	@endDate datetime,
	@objectIDs GuidCollection READONLY,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    SELECT b.Balance, b.ObjectID
		FROM @objectIDs AS o
		CROSS APPLY GetObjectBalance(@startDate, @endDate, o.Value, 0, @propertyIDs) AS b
		
END

GO
