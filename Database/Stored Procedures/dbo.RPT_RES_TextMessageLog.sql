SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- ============================================================================
-- Author:		Sam Bryan
-- Create date: May. 24, 2016
-- Description:	Gets text messaging log 
-- ============================================================================
CREATE PROCEDURE [dbo].[RPT_RES_TextMessageLog]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@leaseID uniqueidentifier null,		
	@propertyID uniqueidentifier  null,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	

	-- DateCreated
	-- Sender (if IsOutbound == 0 then Resident's firstname and lastname so join person table on NonUserPersonID.. if IsOutbound == 1 then users firstname and lastname so join on person table UserPersonID
	-- SenderNumber ( same as above pretty much)
	-- Receiver (same as above pretty much)
	-- ReceiverNumber (same as above pretty much)
	-- Message

	CREATE TABLE #TextMessagingInfo (
		PropertyID uniqueidentifier NULL,
		PersonID uniqueidentifier NULL,
		DateCreated datetime NULL,
		Sender nvarchar(100) NULL,
		SenderNumber nvarchar(100) NULL,
		Receiver nvarchar(100) NULL,
		ReceiverNumber nvarchar(100) NULL,
		[Message] nvarchar(4000) NULL)
		
	CREATE TABLE #PersonInfo(
		PersonID uniqueidentifier null,
		FirstName nvarchar(30) null,
		LastName nvarchar(50) null)

	INSERT #PersonInfo
		SELECT DISTINCT
			p.PersonID AS 'PersonID',
			p.FirstName AS 'FirstName',
			p.LastName AS 'LastName'
		FROM PersonLease pl
			INNER JOIN Person p ON pl.PersonID = p.PersonID
			INNER JOIN Lease l ON pl.LeaseID = @leaseID

	INSERT #TextMessagingInfo
		SELECT DISTINCT 
			@propertyID AS 'PropertyID',
			(CASE WHEN pm.IsOutBound = 0 THEN p2.PersonID
				  ELSE p1.PersonID
			 END) AS 'PersonID',
			pm.DateCreated as 'DateCreated',

			(CASE WHEN pm.IsOutBound = 0 THEN p2.FirstName + ' ' + p2.LastName
				  ELSE p1.FirstName + ' ' + p1.LastName
			 END) AS 'Sender',
			(CASE WHEN pm.IsOutBound = 0 THEN pm.NonUserAddress
				  ELSE pm.UserAddress
			 END) AS 'SenderNumber',
			(CASE WHEN pm.IsOutBound = 0 THEN p1.FirstName + ' ' + p1.LastName
				  ELSE p2.FirstName + ' ' + p2.LastName
			 END) AS 'Receiver',
			(CASE WHEN pm.IsOutBound = 0 THEN pm.UserAddress
				  ELSE pm.NonUserAddress
			 END) AS 'ReceiverNumber',
			 pm.Body AS 'Message' 
			FROM PersonMessage pm
				LEFT JOIN Person p1 on pm.UserPersonID = p1.PersonID
				LEFT JOIN #PersonInfo P2 on pm.NonUserPersonID = p2.PersonID
				LEFT JOIN PropertyAccountingPeriod pap ON @propertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE pm.AccountID = @accountID
			  AND pm.PropertyID = @propertyID
			  AND (pm.UserPersonID IN (SELECT PersonID FROM #PersonInfo) OR pm.NonUserPersonID IN (SELECT PersonID FROM #PersonInfo)) 
			  AND (((@accountingPeriodID IS NULL) AND (CAST(pm.DateCreated AS Date) >= @startDate) AND (CAST(pm.DateCreated AS Date) <=  @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (CAST(pm.DateCreated AS Date) >= pap.StartDate) AND (CAST(pm.DateCreated AS Date) <= pap.EndDate)))
	
	
	SELECT * FROM #TextMessagingInfo tmi ORDER BY tmi.DateCreated DESC	
	
END
GO
