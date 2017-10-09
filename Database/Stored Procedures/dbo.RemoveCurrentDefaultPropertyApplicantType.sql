SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 12/3/13
-- Description:	Removes the current default applicant type for a property
-- =============================================
CREATE PROCEDURE [dbo].[RemoveCurrentDefaultPropertyApplicantType] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@propertyID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    UPDATE ApplicantType SET IsDefault = 0
		WHERE AccountID = @accountID AND PropertyID = @propertyID
END
GO
