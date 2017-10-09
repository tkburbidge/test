SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: March 27, 2012
-- Description:	Stored procedure wrapper for GetObjectBalance
-- =============================================
CREATE PROCEDURE [dbo].[SP_GetObjectBalance] 
	-- Add the parameters for the stored procedure here
	@startDate datetime, 
	@endDate datetime,
	@objectID uniqueidentifier,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT * FROM GetObjectBalance(@startDate, @endDate, @objectID, 0, @propertyIDs)
END
GO
