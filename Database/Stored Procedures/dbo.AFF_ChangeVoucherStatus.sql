SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_ChangeVoucherStatus] 
	@accountID bigint,
	@affordableSubmissionID uniqueidentifier
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE AffordableSubmission SET [Status] = 'Pending'
	WHERE AffordableSubmissionID = @affordableSubmissionID
		  AND AccountID = @accountID
      
	DELETE ca
	FROM CertificationAdjustment ca
		JOIN AffordableSubmissionItem asi ON ca.CertificationAdjustmentID = asi.ObjectID
	WHERE asi.AffordableSubmissionID = @affordableSubmissionID
		AND ca.AccountID = @accountID

	DELETE 
	FROM AffordableSubmissionItem
	WHERE AffordableSubmissionID = @affordableSubmissionID
		AND AccountID = @accountID
      
END

GO
