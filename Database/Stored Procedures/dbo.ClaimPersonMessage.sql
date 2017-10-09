SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 2, 2014
-- Description:	Claims a PersonMessage
-- =============================================
CREATE PROCEDURE [dbo].[ClaimPersonMessage] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@nonUserPersonID uniqueidentifier = null,
	@nonUserAddress nvarchar(400) = null,
	@claimedByPersonID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @alreadyClaimed bit = CASE WHEN ((SELECT COUNT(*) 
												FROM PersonMessage
												WHERE AccountID = @accountID
												  AND PropertyID = @propertyID
												  AND ((@nonUserPersonID IS NOT NULL AND NonUserPersonID = @nonUserPersonID)
													OR (NonUserAddress = @nonUserAddress))
												  AND ClaimedByPersonID IS NULL
												  AND IsHidden = 0) = 0)
										THEN 1
										ELSE 0
									END
								

	UPDATE PersonMessage
		SET ClaimedByPersonID = @claimedByPersonID,
			ClaimedByDatetime = GETUTCDATE()
		WHERE AccountID = @accountID
		  AND PropertyID = @propertyID
		  AND ((@nonUserPersonID IS NOT NULL AND NonUserPersonID = @nonUserPersonID)
			OR (NonUserAddress = @nonUserAddress))
		  AND ClaimedByPersonID IS NULL
		  AND IsHidden = 0
		  
	SELECT TOP 1 @alreadyClaimed AS 'AlreadyClaimed',
				 per.PreferredName AS 'FirstName',
				 per.LastName AS 'LastName',
				 pm.ClaimedByDatetime AS 'ClaimedByDateTime'
		FROM PersonMessage pm
			INNER JOIN Person per ON pm.ClaimedByPersonID = per.PersonID
		WHERE pm.AccountID = @accountID
		  AND PropertyID = @propertyID
		  AND ((@nonUserPersonID IS NOT NULL AND NonUserPersonID = @nonUserPersonID)
			OR (NonUserAddress = @nonUserAddress))
		  AND pm.ClaimedByPersonID IS NOT NULL
		  AND pm.IsHidden = 0
		ORDER BY pm.DateCreated desc
	
END
GO
