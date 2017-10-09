SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetPreviousCertification] 
	-- Add the parameters for the stored procedure here
	@accountID BIGINT = 0,
	@date DATETIME = null,
	@certificationID UNIQUEIDENTIFIER = NULL,
	@types StringCollection READONLY,
	@completedOnly BIT = 0,
	@hasSubmissionItem BIT = 0,
	@certificationGroupID UNIQUEIDENTIFIER
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT  dbo.GetPreviousCertificationID(@accountID, @date, @certificationID, @types, @completedOnly, @hasSubmissionItem, @certificationGroupID)

END
GO
