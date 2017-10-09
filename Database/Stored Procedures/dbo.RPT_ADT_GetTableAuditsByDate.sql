SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 14, 2014
-- Description:	Dumps stuff from the AuditTable table.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ADT_GetTableAuditsByDate] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@startDate date = null, 
	@endDate date = null,
	@includeAdmin bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @endDate = DATEADD(DAY, 1, @endDate) 

	SELECT	ta.TableAuditID,
			(SELECT PreferredName + ' ' + LastName FROM Person WHERE PersonID = ta.PersonID) AS 'OriginalPerson',
			(SELECT PreferredName + ' ' + LastName FROM Person WHERE PersonID = ta.ChangedPersonID) AS 'ModifiedPerson',
			ta.TableName,
			ta.ColumnName,
			ta.OldValue,
			ta.NewValue, 
			ta.[Action] AS 'Action',
			ta.[DateTime] AS 'Date',
			ta.IPAddress
		FROM TableAudit ta
			INNER JOIN [User] u ON ta.PersonID = u.PersonID
		WHERE ta.[DateTime] >= @startDate
		  AND ta.[DateTime] < @endDate
		  AND ta.AccountID = @accountID
		  AND (@includeAdmin = 1 OR u.Username <> 'Admin' OR ta.[DateTime] < '2015-02-20')
		ORDER BY ta.TableName, ta.ColumnName, ta.[DateTime]
	
END
GO
