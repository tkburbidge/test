SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: August 8, 2012
-- Description:	Updates the propertyID of each document tied to an object.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateDocumentsPropertyForObject] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@objectID uniqueidentifier = null,
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	UPDATE Document SET PropertyID = @propertyID WHERE ObjectID = @objectID AND AccountID = @accountID
END
GO
