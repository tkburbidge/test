SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Nick Olsen
-- Create date: June 22, 2012
-- Description:	Approves all purchase orders or invoices matching the ids
--				passed in if they have not been approved already
-- =============================================
CREATE PROCEDURE [dbo].[AddApprovedPOInvoiceNote]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@personID uniqueidentifier,	
	@date date,
	@objectIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	INSERT INTO POInvoiceNote (POInvoiceNoteID, AccountID, ObjectID, PersonID, AltObjectID, AltObjectType, [Date], [Status], Notes, [Timestamp])
		SELECT NEWID(), @accountID, ids.Value, @personID, null, null, @date, 'Approved', null, GETUTCDATE()
		FROM @objectIDs ids
		WHERE (SELECT TOP 1 [Status]
				FROM POInvoiceNote
				WHERE AccountID = @accountID 
					AND ObjectID = ids.Value
				ORDER BY [Timestamp] DESC) = 'Pending Approval'    
	
END
GO
