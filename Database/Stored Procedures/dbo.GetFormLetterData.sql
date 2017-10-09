SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[GetFormLetterData]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@fieldNames StringCollection readonly,
	@objectIDs GuidCollection readonly,
	@personID uniqueIdentifier = null,
	@propertyID uniqueIdentifier = null,
	@templateType varchar(35) = '',
	@forText bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #FormLetterData
	(
		LeaseID uniqueidentifier, -- while this says leaseid, it is really a field that links the data back to a specific person or object in the case we are sending in a large amount of leaseid's in a mass mail merge
		FieldName nvarchar(500),
		Value nvarchar(max)
	)

	CREATE TABLE #TempLastPaymentData
	(
		LeaseID uniqueidentifier,
		PaymentID uniqueidentifier,
		ReferenceNumber nvarchar(max),
		[Date] nvarchar(max),
		ReceivedFromPaidTo nvarchar(max),
		Amount nvarchar(max)
	)

	CREATE TABLE #TempForwardingAddressData
	(
		LeaseID uniqueidentifier,
		ForwardingStreetAddress nvarchar(max),
		ForwardingCity nvarchar(max),
		ForwardingState nvarchar(max),
		ForwardingZipCode nvarchar(max)
	)

-- notes: 
	-- input:
		-- case templatetypes of Applicant/Resident, '' or Lease, @objectIDs will be a list of LeaseIDs, if personid is not null, it's a oneoff email
		-- case alternate contacts, there should be only one leaseid in the objectid's and when getting property data, 
			-- use the propertyid as we can't join to a person as they aren't on the lease
		-- case Workordercompleted or workorder assigned, the objectid is a workorder id 
			-- in the case of a workorderassigned, personid is the person the work order is assigned to
			-- in the case of a workorder completed, personid is the personid of the resident who reported the problem/requested the work.
		-- case PackageReceived the objectid is a packageLogID
		-- case template types of application received, the object type will be a leasid and we will treat is just as we would an applican/resident
		-- case template types of onlinepayment, objectid's is a single processorPaymentFormID, 
			-- ie: the id of the ProcessorPaymentForm record that contains the text of the html form that will be posted when the user clicks an onlinepayment link in an email
		-- case template type of InvoiceApprovalRequired, objectid will be a invoice id, and we won't get property related data
		-- case template type of POApprovalRequired, objectid will be a purchase order id, and we won't get property related data
		-- else @objectIDs will be personIDs 
		
	-- return:
		-- the returned field LeaseID will contain:
			-- case templatetype of '', applicant/resident or lease or alternate contacts => leasid
			-- case POApprovalRequired, the purchase order id
			-- case InvoiceApprovalRequired, the invoice id
			-- all other cases => personid

declare @objectID uniqueidentifier

	--Monday: 10:00 AM - 5:00 PM
	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyOfficeHours'))
	BEGIN
		INSERT INTO #FormLetterData
			SELECT lids.Value, 'PropertyOfficeHours', 
				REPLACE((STUFF((SELECT '[NL]' +
					(SELECT CASE 
						WHEN ([Day] = 0) THEN 'Sunday' 
						WHEN ([Day] = 1) THEN 'Monday'
						WHEN ([Day] = 2) THEN 'Tuesday'
						WHEN ([Day] = 3) THEN 'Wednesday'
						WHEN ([Day] = 4) THEN 'Thursday'
						WHEN ([Day] = 5) THEN 'Friday'
						WHEN ([Day] = 6) THEN 'Saturday'
						END
						) + ': ' + oh.Start + ' - ' + oh.[End]
						FROM OfficeHour oh
						WHERE oh.AccountID = @accountID
							AND oh.PropertyID = @propertyID
						ORDER BY oh.[Day] ASC, oh.Start						
						FOR XML PATH ('')), 1, 4, '')) , '[NL]', CHAR(13) + CHAR(10))
			FROM @objectIDs lids
	END

	-- if we have a template type of 'Applicant/Resident' or lease, the objectid is a lease and we can do this
	IF (@templateType = 'ApplicantResident' or @templateType = 'Lease' or @templateType = 'AppResAltContact' or @templatetype = 'ApplicationReceived' or @templateType = 'ReportBatchLink' 
		OR @templateType = 'GuarantorInvitation')
	BEGIN
		-- **** Lease Data **** --
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LeaseEndDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'LeaseEndDate', CONVERT(nvarchar(50), l.LeaseEndDate, 101)
				FROM Lease l			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LeaseStartDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'LeaseStartDate', CONVERT(nvarchar(50), l.LeaseStartDate, 101)
				FROM Lease l			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastPaymentReference' OR Value = 'LastPaymentDate' OR Value = 'LastPaymentPayer' OR Value = 'LastPaymentAmount'))
		BEGIN
			INSERT INTO #TempLastPaymentData
				SELECT l.LeaseID, p.PaymentID, CONVERT(nvarchar(50), p.ReferenceNumber, 101), CONVERT(nvarchar(50), p.[Date], 101), CONVERT(nvarchar(50), p.ReceivedFromPaidTo, 101), CONVERT(nvarchar(50), p.Amount, 101)
				FROM Lease l
					JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					JOIN Payment p ON p.ObjectID = ulg.UnitLeaseGroupID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
					AND p.PaymentID = (SELECT TOP 1 p1.PaymentID
									   FROM Payment p1
										JOIN PaymentTransaction pt ON pt.PaymentID = p1.PaymentID
										JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
										JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
									   WHERE p1.ObjectID = ulg.UnitLeaseGroupID
										AND tt.Name = 'Payment'
										AND tt.[Group] = 'Lease'
									   ORDER BY [Date] DESC)

			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastPaymentReference'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT LeaseID, 'LastPaymentReference', ReferenceNumber
					FROM #TempLastPaymentData
			END

			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastPaymentDate'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT LeaseID, 'LastPaymentDate', [Date]
					FROM #TempLastPaymentData
			END
    
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastPaymentPayer'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT LeaseID, 'LastPaymentPayer', ReceivedFromPaidTo
					FROM #TempLastPaymentData
			END
    
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastPaymentAmount'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT LeaseID, 'LastPaymentAmount', Amount
					FROM #TempLastPaymentData
			END
		END    
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RenewalLeaseStartDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'RenewalLeaseStartDate', CONVERT(nvarchar(50), DATEADD(DAY, 1, l.LeaseEndDate), 101)
				FROM Lease l			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ForwardingStreetAddress' OR Value = 'ForwardingCity' OR Value = 'ForwardingState' OR Value = 'ForwardingZipCode'))
		BEGIN
			INSERT INTO #TempForwardingAddressData
				SELECT l.LeaseID, CONVERT(nvarchar(50), a.StreetAddress, 101), CONVERT(nvarchar(50), a.City, 101), CONVERT(nvarchar(50), a.State, 101), CONVERT(nvarchar(50), a.Zip, 101)
				FROM Lease l
					JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
					JOIN [Address] a ON a.ObjectID = pl.PersonID AND a.AddressType = 'Forwarding'
				WHERE (@personID IS NULL OR @personID = pl.PersonID)
					AND l.LeaseID IN (SELECT Value FROM @objectIDs)
					AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID AND (@personID IS NULL OR @personID = PersonLease.PersonID) ORDER BY pl.OrderBy)

			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ForwardingStreetAddress'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT LeaseID, 'ForwardingStreetAddress', ForwardingStreetAddress
					FROM #TempForwardingAddressData
			END

			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ForwardingCity'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT LeaseID, 'ForwardingCity', ForwardingCity
					FROM #TempForwardingAddressData
			END

			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ForwardingState'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT LeaseID, 'ForwardingState', ForwardingState
					FROM #TempForwardingAddressData
			END

			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ForwardingZipCode'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT LeaseID, 'ForwardingZipCode', ForwardingZipCode
					FROM #TempForwardingAddressData
			END
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MoveInDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'MoveInDate', CONVERT(nvarchar(50), MIN(pl.MoveInDate), 101)
				FROM Lease l			
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs) 
					AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
				GROUP BY l.LeaseID				
		END
	
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastDayOfMoveInMonth'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'LastDayOfMoveInMonth', CONVERT(nvarchar(50), DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,MIN(pl.MoveInDate))+1,0)), 101)
				FROM Lease l			
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs) 
					AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
				GROUP BY l.LeaseID				
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'FirstFullMonth'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'FirstFullMonth', DATENAME(month, DATEADD(mm, DATEDIFF(m,0,MIN(pl.MoveInDate))+1,0)) + ' ' + DATENAME(year, DATEADD(mm, DATEDIFF(m,0,MIN(pl.MoveInDate))+1,0))
				FROM Lease l			
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs) 
					AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
				GROUP BY l.LeaseID							
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MoveOutDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT Data.LeaseID, Data.Field, CASE WHEN plmo.PersonLeaseID IS NOT NULL THEN '' ELSE Data.Value END
				FROM (SELECT l.LeaseID, 'MoveOutDate' AS Field, ISNULL(CONVERT(nvarchar(50), MAX(pl.MoveOutDate), 101), '') AS Value
						FROM Lease l			
						INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID			
						WHERE l.LeaseID IN (SELECT Value FROM @objectIDs) 
							AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
						GROUP BY l.LeaseID) Data
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = Data.LeaseID AND plmo.MoveOutDate IS NULL		
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PendingRenewalLeaseStartDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PendingRenewalLeaseStartDate', CONVERT(nvarchar(50), prl.LeaseStartDate, 101)
				FROM Lease l			
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Lease prl ON prl.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs) 
					AND prl.LeaseStatus = 'Pending Renewal'
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PendingRenewalLeaseEndDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PendingRenewalLeaseEndDate', CONVERT(nvarchar(50), prl.LeaseEndDate, 101)
				FROM Lease l			
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Lease prl ON prl.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs) 
					AND prl.LeaseStatus = 'Pending Renewal'
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RentRecurringCharge'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'RentRecurringCharge', 
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(lli.Amount), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND lit.IsRent = 1
								AND lli.StartDate <= l.LeaseEndDate)
				FROM @objectIDs lids
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MainContactNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'MainContactNames', 
					(STUFF((SELECT ', ' + (FirstName + ' ' + LastName)
							FROM Person p
							INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID AND pl.MainContact = 1
							INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
							WHERE l.LeaseID = lids.Value
								AND (l.LeaseStatus IN ('Cancelled', 'Denied', 'Former', 'Evicted') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Former', 'Evicted'))
							ORDER BY pl.OrderBy, p.FirstName
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
		END

		CREATE TABLE #Residents (
			ID			INT,
			[Name]		NVARCHAR(500) null,
			Email		NVARCHAR(500) null,
			LeaseID		uniqueIdentifier,			
			MobilePhone NVARCHAR(500) null,
			HomePhone	NVARCHAR(500) null,
			WorkPhone	NVARCHAR(500) null,
			MainContact BIT,
			OrderBy		INT	
		)
		

		INSERT INTO #Residents (ID, Name, Email, LeaseID, MobilePhone, HomePhone, WorkPhone, MainContact, OrderBy)
			SELECT ROW_NUMBER() OVER(PARTITION BY l.LeaseID ORDER BY l.LeaseID, pl.OrderBy, pl.MainContact DESC,  p.LastName, p.FirstName), p.FirstName + ' ' + p.LastName, p.Email, l.LeaseID,
			CASE WHEN (p.Phone1Type = 'Mobile') THEN p.Phone1
				WHEN (p.Phone2Type = 'Mobile') THEN p.Phone2
				WHEN (p.Phone3Type = 'Mobile') THEN p.Phone3
				ELSE '' END AS 'MobilePhone',
			CASE WHEN (p.Phone1Type = 'Home') THEN p.Phone1
				 WHEN (p.Phone2Type = 'Home') THEN p.Phone2
				 WHEN (p.Phone3Type = 'Home') THEN p.Phone3
				 ELSE '' END AS 'HomePhone',
			CASE WHEN (p.Phone1Type = 'Work') THEN p.Phone1
				 WHEN (p.Phone2Type = 'Work') THEN p.Phone2
				 WHEN (p.Phone3Type = 'Work') THEN p.Phone3
				 ELSE '' END AS 'WorkPhone',
			pl.MainContact,
			pl.OrderBy
				FROM Person p
					INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
					INNER JOIN Lease l ON l.LeaseID = pl.LeaseID	
				WHERE l.LeaseID in (SELECT Value FROM @objectIDs)
					AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
					AND (pl.HouseholdStatus != 'Guarantor')
				ORDER BY l.LeaseID, pl.OrderBy, pl.MainContact DESC, p.LastName, p.FirstName
    

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MainContact1'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'MainContact1', 
				(SELECT Name FROM #Residents r WHERE r.ID = 1 AND r.MainContact = 1 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids		
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MainContact2'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'MainContact2', 
				(SELECT Name FROM #Residents r WHERE r.ID = 2 AND r.MainContact = 1 AND r.LeaseID = lids.Value) 				
			FROM @objectIDs lids	
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MainContact3'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'MainContact3', 
				(SELECT Name FROM #Residents r WHERE r.ID = 3 AND r.MainContact = 1 AND r.LeaseID = lids.Value) 		
			FROM @objectIDs lids	
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MainContact4'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'MainContact4', 
				(SELECT Name FROM #Residents r WHERE r.ID = 4 AND r.MainContact = 1 AND r.LeaseID = lids.Value) 				
			FROM @objectIDs lids	
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'AllContactNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'AllContactNames', 
					(STUFF((SELECT ', ' + (FirstName + ' ' + LastName)
							FROM Person p
							INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
							INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
							WHERE l.LeaseID = lids.Value
									AND (l.LeaseStatus IN ('Cancelled', 'Denied', 'Former', 'Evicted') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Former', 'Evicted'))
									AND (pl.HouseholdStatus != 'Guarantor')
							ORDER BY pl.OrderBy, pl.MainContact DESC, p.LastName, p.FirstName
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'LastNames', 
					(STUFF(	(SELECT ', ' + T.LastName 
							 FROM (SELECT DISTINCT LastName
									FROM Person p
									INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
									INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
									WHERE l.LeaseID = lids.Value
										AND (l.LeaseStatus IN ('Cancelled', 'Denied', 'Former', 'Evicted') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Former', 'Evicted'))
										AND (pl.HouseholdStatus != 'Guarantor')) T	
							ORDER BY T.LastName
							FOR XML PATH (''))
						
							, 1, 2, ''))
				FROM @objectIDs lids
		END    
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'FirstNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'FirstNames', 
					(STUFF(	(SELECT ', ' + T.FirstName 
							 FROM (SELECT DISTINCT FirstName
									FROM Person p
									INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
									INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
									WHERE l.LeaseID = lids.Value
										AND (l.LeaseStatus IN ('Cancelled', 'Denied', 'Former', 'Evicted') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Former', 'Evicted'))
										AND (@personID IS NULL OR p.PersonID = @personID)
										AND (pl.HouseholdStatus != 'Guarantor')) T	
							ORDER BY T.FirstName
							FOR XML PATH (''))
							, 1, 2, ''))
				FROM @objectIDs lids
		END    


        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident1Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident1Name', 
				(SELECT Name FROM #Residents r WHERE r.ID = 1 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident1Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident1Email', 
				(SELECT Email FROM #Residents r WHERE r.ID = 1 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		 IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident1HomePhone'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident1HomePhone', 
				(SELECT HomePhone FROM #Residents r WHERE r.ID = 1 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		 IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident1WorkPhone'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident1WorkPhone', 
				(SELECT WorkPhone FROM #Residents r WHERE r.ID = 1 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		 IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident1MobilePhone'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident1MobilePhone', 
				(SELECT MobilePhone FROM #Residents r WHERE r.ID = 1 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident2Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident2Name', 
				(SELECT Name FROM #Residents r WHERE r.ID = 2 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident2Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident2Email', 
				(SELECT Email FROM #Residents r WHERE r.ID = 2 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END
        
        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident3Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident3Name', 
				(SELECT Name FROM #Residents r WHERE r.ID = 3 AND r.LeaseID = lids.Value) 



			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident3Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident3Email', 
				(SELECT Email FROM #Residents r WHERE r.ID = 3 AND r.LeaseID = lids.Value) 



			FROM @objectIDs lids							
		END
        
        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident4Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident4Name', 
				(SELECT Name FROM #Residents r WHERE r.ID = 4 AND r.LeaseID = lids.Value) 





			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident4Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident4Email', 
				(SELECT Email FROM #Residents r WHERE r.ID = 4 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident5Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident5Name', 
				(SELECT Name FROM #Residents r WHERE r.ID = 5 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident5Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident5Email', 
				(SELECT Email FROM #Residents r WHERE r.ID = 5 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

  
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident6Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident6Name', 
				(SELECT Name FROM #Residents r WHERE r.ID = 6 AND r.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Resident6Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Resident6Email', 
				(SELECT Email FROM #Residents r WHERE r.ID = 6 AND r.LeaseID = lids.Value) 

			FROM @objectIDs lids							
		END


		CREATE TABLE #LeaseGuarantors (
			ID				INT,
			[Name]			NVARCHAR(500) null,
			Email			NVARCHAR(500) null,
			LeaseID			uniqueIdentifier,			
			MobilePhone		NVARCHAR(500) null,
			HomePhone		NVARCHAR(500) null,
			WorkPhone		NVARCHAR(500) null,
			StreetAddress	NVARCHAR(500) null,
			CityStateZip	NVARCHAR(500) null,
			OrderBy			INT	
		)

		INSERT INTO #LeaseGuarantors (ID, Name, Email, LeaseID, MobilePhone, HomePhone, WorkPhone, StreetAddress, CityStateZip, OrderBy)
			SELECT ROW_NUMBER() OVER(PARTITION BY l.LeaseID ORDER BY l.LeaseID, pl.OrderBy, pl.MainContact DESC,  p.LastName, p.FirstName), p.FirstName + ' ' + p.LastName, p.Email, l.LeaseID,
			CASE WHEN (p.Phone1Type = 'Mobile') THEN p.Phone1
				WHEN (p.Phone2Type = 'Mobile') THEN p.Phone2
				WHEN (p.Phone3Type = 'Mobile') THEN p.Phone3
				ELSE null END AS 'MobilePhone',
			CASE WHEN (p.Phone1Type = 'Home') THEN p.Phone1
				 WHEN (p.Phone2Type = 'Home') THEN p.Phone2
				 WHEN (p.Phone3Type = 'Home') THEN p.Phone3
				 ELSE null END AS 'HomePhone',
			CASE WHEN (p.Phone1Type = 'Work') THEN p.Phone1
				 WHEN (p.Phone2Type = 'Work') THEN p.Phone2
				 WHEN (p.Phone3Type = 'Work') THEN p.Phone3
				 ELSE null END AS 'WorkPhone',
			a.StreetAddress,
			coalesce(a.City, '') + ', ' + coalesce(a.[State], '') + ' ' + coalesce(a.Zip, '') AS 'CityStateZip',
			pl.OrderBy
				FROM Person p
					INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
					INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
					LEFT JOIN [Address] a ON a.ObjectID = pl.PersonID
				WHERE l.LeaseID in (SELECT Value FROM @objectIDs)
					AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
					AND (pl.HouseholdStatus = 'Guarantor')
				ORDER BY l.LeaseID, pl.OrderBy, p.LastName, p.FirstName


		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor1Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor1Name', 
				(SELECT Name FROM #LeaseGuarantors g WHERE g.ID = 1 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor1Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor1Email', 
				(SELECT Email FROM #LeaseGuarantors g WHERE g.ID = 1 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor1Phone'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor1Phone', 
				(SELECT coalesce(MobilePhone, HomePhone, WorkPhone, '') FROM #LeaseGuarantors g WHERE g.ID = 1 AND g.LeaseID = lids.Value)
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor1StreetAddress'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor1StreetAddress', 
				(SELECT StreetAddress FROM #LeaseGuarantors g WHERE g.ID = 1 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor1CityStateZip'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor1CityStateZip', 
				(SELECT CityStateZip FROM #LeaseGuarantors g WHERE g.ID = 1 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor2Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor2Name', 
				(SELECT Name FROM #LeaseGuarantors g WHERE g.ID = 2 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor2Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor2Email', 
				(SELECT Email FROM #LeaseGuarantors g WHERE g.ID = 2 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor2Phone'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor2Phone', 
				(SELECT coalesce(MobilePhone, HomePhone, WorkPhone, '') FROM #LeaseGuarantors g WHERE g.ID = 2 AND g.LeaseID = lids.Value)
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor2StreetAddress'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor2StreetAddress', 
				(SELECT StreetAddress FROM #LeaseGuarantors g WHERE g.ID = 2 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor2CityStateZip'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor2CityStateZip', 
				(SELECT CityStateZip FROM #LeaseGuarantors g WHERE g.ID = 2 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END



		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor3Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor3Name', 
				(SELECT Name FROM #LeaseGuarantors g WHERE g.ID = 3 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor3Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor3Email', 
				(SELECT Email FROM #LeaseGuarantors g WHERE g.ID = 3 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor3Phone'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor3Phone', 
				(SELECT coalesce(MobilePhone, HomePhone, WorkPhone, '') FROM #LeaseGuarantors g WHERE g.ID = 3 AND g.LeaseID = lids.Value)
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor3StreetAddress'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor3StreetAddress', 
				(SELECT StreetAddress FROM #LeaseGuarantors g WHERE g.ID = 3 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor3CityStateZip'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor3CityStateZip', 
				(SELECT CityStateZip FROM #LeaseGuarantors g WHERE g.ID = 3 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END



		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor4Name'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor4Name', 
				(SELECT Name FROM #LeaseGuarantors g WHERE g.ID = 4 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor4Email'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor4Email', 
				(SELECT Email FROM #LeaseGuarantors g WHERE g.ID = 4 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor4Phone'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor4Phone', 
				(SELECT coalesce(MobilePhone, HomePhone, WorkPhone, '') FROM #LeaseGuarantors g WHERE g.ID = 4 AND g.LeaseID = lids.Value)
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor4StreetAddress'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor4StreetAddress', 
				(SELECT StreetAddress FROM #LeaseGuarantors g WHERE g.ID = 4 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Guarantor4CityStateZip'))
		BEGIN		
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'Guarantor4CityStateZip', 
				(SELECT CityStateZip FROM #LeaseGuarantors g WHERE g.ID = 4 AND g.LeaseID = lids.Value) 
			FROM @objectIDs lids							
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PetNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'PetNames', 
					ISNULL((STUFF((SELECT ', ' + Name
							FROM Person p
							INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
							INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
							INNER JOIN Pet pet ON pet.PersonID = p.PersonID
							WHERE l.LeaseID = lids.Value
								AND (l.LeaseStatus IN ('Cancelled', 'Denied', 'Former', 'Evicted') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Former', 'Evicted'))
							ORDER BY pl.OrderBy, p.FirstName
							FOR XML PATH ('')), 1, 2, '')), '')
				FROM @objectIDs lids	
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value like 'Pet%')) 
		BEGIN
			CREATE TABLE #Pets
			(
				ID			INT ,
				Name		NVARCHAR(50) null,
				Breed		NVARCHAR(50) null,
				[Type]		NVARCHAR(20) null,
				Color		NVARCHAR(50) null,
				Notes		NVARCHAR(4000) null,
				[Weight]	NVARCHAR(10) null,
				Age			NVARCHAR(10) null,
				RegistrationNumber NVARCHAR(1000) null,
				OwnersName	NVARCHAR(300) null,
				LeaseID     UNIQUEIDENTIFIER null
			)
			
			INSERT INTO #Pets (ID, Name, Breed, [Type], Color, Notes, [Weight], Age, RegistrationNumber, OwnersName, LeaseID)
				
				SELECT ROW_NUMBER() OVER(PARTITION BY l.LeaseID ORDER BY l.LeaseID, pet.Name), pet.Name, pet.Breed, pet.[Type], pet.Color, pet.Notes, pet.[Weight], pet.Age, pet.RegistrationNumber, p.FirstName + ' ' + p.LastName, l.LeaseID
				FROM Person p
								INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
								INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
								INNER JOIN Pet pet ON pet.PersonID = p.PersonID
								WHERE l.LeaseID in (SELECT Value FROM @objectIDs)
									AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
								ORDER BY pet.Name
			-- names
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1Name'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1Name', 
					(SELECT Name FROM #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids			
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2Name'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2Name', 
					(SELECT Name FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3Name'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3Name', 
					(select Name FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- breeds
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1Breed'))
			Begin
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1Breed', 
					(SELECT Breed FROM #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids			
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2Breed'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2Breed', 
					(SELECT Breed FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3Breed'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3Breed', 
					(SELECT Breed FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- type
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1Type'))
			Begin
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1Type', 
					(SELECT [Type] FROM #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids			
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2Type'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2Type', 
					(SELECT [Type] FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3Type'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3Type', 
					(SELECT [Type] FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- color
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1Color'))
			Begin
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1Color', 
					(SELECT Color from #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids			
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2Color'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2Color', 
					(SELECT Color FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3Color'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3Color', 
					(SELECT Color FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- notes
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1Notes'))
			Begin
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1Notes', 
					(SELECT Notes FROM #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids			
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2Notes'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2Notes', 
					(SELECT Notes FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3Notes'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3Notes', 
					(SELECT Notes FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- Weight
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1Weight'))
			Begin
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1Weight', 
					(SELECT [Weight] FROM #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids			
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2Weight'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2Weight', 
					(SELECT [Weight] FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3Weight'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3Weight', 
					(SELECT [Weight] FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END			
			-- Age
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1Age'))
			Begin
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1Age', 
					(SELECT Age FROM #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids			
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2Age'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2Age', 
					(SELECT Age FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3Age'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3Age', 
					(SELECT Age FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- RegistrationNumber
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1RegistrationNumber'))
			Begin
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1RegistrationNumber', 
					(SELECT RegistrationNumber FROM #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids			
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2RegistrationNumber'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2RegistrationNumber', 
					(SELECT RegistrationNumber FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3RegistrationNumber'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3RegistrationNumber', 
					(SELECT RegistrationNumber FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- Owners Name
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet1OwnersName'))
			Begin
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet1OwnersName', 
					(SELECT OwnersName FROM #Pets pet WHERE pet.ID = 1 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids							
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet2OwnersName'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet2OwnersName', 
					(SELECT OwnersName FROM #Pets pet WHERE pet.ID = 2 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Pet3OwnersName'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Pet3OwnersName', 
					(SELECT OwnersName FROM #Pets pet WHERE pet.ID = 3 AND pet.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
		END   
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'EmployerNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'EmployerNames', 
					ISNULL((STUFF((SELECT ', ' + Employer
							FROM Person p
							INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
							INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
							INNER JOIN Employment e ON e.PersonID = p.PersonID
							WHERE l.LeaseID = lids.Value
								AND (l.LeaseStatus IN ('Cancelled', 'Denied', 'Former', 'Evicted') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Former', 'Evicted'))
								AND e.[Type] = 'Employment'
							ORDER BY Employer
							FOR XML PATH ('')), 1, 2, '')), '')
				FROM @objectIDs lids		
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value like 'Employment%')) 
		BEGIN -- employmentdata
			CREATE TABLE #Employers
			(
				ID			    INT,
				Employer	    NVARCHAR(100) null,
				Industry	    NVARCHAR(100) null,
				Title		    NVARCHAR(50) null,
				ContactName	    NVARCHAR(50) null,
				Salary		    MONEY null,
				SalaryType	    NVARCHAR(10) null,
				PhoneNumber	    NVARCHAR(25) null,
                StreetAddress   NVARCHAR(500) null,
                City            NVARCHAR(50) null,
                [State]         NVARCHAR(50) null,
                Zip             NVARCHAR(20) null,
				LeaseID			uniqueidentifier

			)
			INSERT INTO #Employers (ID, Employer, Industry, Title, ContactName, Salary, SalaryType, PhoneNumber, StreetAddress, City, [State], Zip, LeaseID)
				
			SELECT ROW_NUMBER() OVER(PARTITION BY l.LeaseID ORDER BY l.LeaseID, e.Employer), e.Employer, e.Industry, e.Title, e.ContactName, sal.Amount, sal.SalaryPeriod, e.CompanyPhone, a.StreetAddress, a.City, a.[State], a.Zip, l.LeaseID
			FROM Person p
			INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
			INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
			INNER JOIN Employment e ON e.PersonID = p.PersonID
			INNER JOIN Salary sal ON e.EmploymentID = sal.EmploymentID
							AND sal.SalaryID = (SELECT TOP 1 SalaryID
													FROM Salary
													WHERE EmploymentID = e.EmploymentID
													  AND Amount IS NOT NULL
													ORDER BY EffectiveDate DESC, Amount DESC)
            LEFT JOIN [Address] a ON e.AddressID = a.AddressID
			WHERE l.LeaseID in (SELECT Value FROM @objectIDs)
				AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
			ORDER BY e.Employer

			-- industry
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1Industry'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1Industry', 
					(SELECT Industry FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2Industry'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2Industry', 
					(SELECT Industry FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3Industry'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3Industry', 
					(SELECT Industry FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- Employer
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1Employer'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1Employer', 
					(SELECT Employer FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2Employer'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2Employer', 
					(SELECT Employer FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3Employer'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3Employer', 
					(SELECT Employer FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- Title
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1Title'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1Title', 
					(SELECT Title FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2Title'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2Title', 
					(SELECT Title FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3Title'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3Title', 
					(SELECT Title FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- ContactName
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1ContactName'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1ContactName', 
					(SELECT ContactName FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2ContactName'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2ContactName', 
					(SELECT ContactName FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3ContactName'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3ContactName', 
					(SELECT ContactName FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END			
			-- Salary
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1Salary'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1Salary', 
					(SELECT Salary FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2Salary'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2Salary', 
					(SELECT Salary FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3Salary'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3Salary', 
					(SELECT Salary FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			--SalaryType
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1SalaryType'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1SalaryType', 
					(SELECT SalaryType FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2SalaryType'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2SalaryType', 
					(SELECT SalaryType FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3SalaryType'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3SalaryType', 
					(SELECT SalaryType FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- PhoneNumber
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1PhoneNumber'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1PhoneNumber', 
					(SELECT PhoneNumber FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2PhoneNumber'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2PhoneNumber', 
					(SELECT PhoneNumber FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3PhoneNumber'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3PhoneNumber', 
					(SELECT PhoneNumber FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids				
			END
			-- Street Address
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1StreetAddress'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1StreetAddress', 
					(SELECT StreetAddress FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2StreetAddress'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2StreetAddress', 
					(SELECT StreetAddress FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3StreetAddress'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3StreetAddress', 
					(SELECT StreetAddress FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			-- CityStateZip
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment1CityStateZip'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment1CityStateZip', 
					(SELECT City + ', ' + [State] + ' ' Zip FROM #Employers e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment2CityStateZip'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment2CityStateZip', 
					(SELECT City + ', ' + [State] + ' ' Zip FROM #Employers e WHERE e.ID = 2 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Employment3CityStateZip'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'Employment3CityStateZip', 
					(SELECT City + ', ' + [State] + ' ' Zip FROM #Employers e WHERE e.ID = 3 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
		END -- employment data  
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MarketRent'))-- OR EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MarketRentAndMonthToMonthFee'))
		BEGIN
			CREATE TABLE #UnitAmenities (
				Number nvarchar(20) not null,
				UnitID uniqueidentifier not null,
				UnitTypeID uniqueidentifier not null,
				UnitStatus nvarchar(200) not null,
				UnitStatusLedgerItemTypeID uniqueidentifier not null,
				RentLedgerItemTypeID uniqueidentifier not null,
				MarketRent decimal null,
				Amenities nvarchar(MAX) null)
			
			CREATE TABLE #Properties (
				Sequence int identity not null,
				PropertyID uniqueidentifier not null)
			
			INSERT #Properties SELECT DISTINCT ut.PropertyID FROM UnitType ut
																INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
																INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
																INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
															  WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
														  
			DECLARE @date date, @propertyIDa uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection
			SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
			SET @date = GETDATE()
			WHILE (@ctr <= @maxCtr)
			BEGIN
				SELECT @propertyIDa = PropertyID FROM #Properties WHERE Sequence = @ctr
				INSERT @unitIDs 
					SELECT u.UnitID 
						FROM Unit u
							INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyIDa
							INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
							INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
						WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
				INSERT #UnitAmenities 
					EXEC GetRecurringChargeUnitInfo @propertyIDa, @unitIDs, @date
												
				SET @ctr = @ctr + 1
			END
		
			--IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MarketRent'))
			--BEGIN
			--INSERT INTO #FormLetterData
			--	SELECT l.LeaseID, 'MarketRent', CONVERT(nvarchar(20), CAST(#ua.MarketRent AS MONEY), 1)
			--	FROM Lease l

			--		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			--		INNER JOIN Unit u on u.UnitID = ulg.UnitID
			--		INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID		
			--	WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)				
			--END
		
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MarketRent'))--AndMonthToMonthFee'))
			BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'MarketRent'/*AndMonthToMonthFee'*/, CONVERT(varchar(20), CAST((#ua.MarketRent /*+ p.MonthToMonthFee*/) AS MONEY), 1)
				FROM Lease l
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
					INNER JOIN Unit u on u.UnitID = ulg.UnitID
					INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
					INNER JOIN Property p ON p.PropertyID = ut.PropertyID
					INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID		
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)				
			END
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'NonMainContactNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'NonMainContactNames', 
					(STUFF((SELECT ', ' + (FirstName + ' ' + LastName)
							FROM Person p
							INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID AND pl.MainContact = 0
							INNER JOIN Lease l ON l.LeaseID = pl.LeaseID										
							WHERE l.LeaseID = lids.Value
									AND (l.LeaseStatus IN ('Cancelled', 'Denied', 'Former', 'Evicted') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Former', 'Evicted'))
							ORDER BY pl.OrderBy, p.FirstName
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RecurringCharges'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'RecurringCharges', 
					REPLACE((STUFF((SELECT '[NL]' + lli.[Description] + ' - ' + CONVERT(nvarchar(20), CAST(lli.Amount AS MONEY), 1)--+
								--CASE WHEN lip.LedgerItemPoolID IS NOT NULL THEN ' (' + lip.Name + ' ' + li.[Description] + ')'
								--	 ELSE ''
								--END
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID			
								--LEFT JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
							WHERE lli.LeaseID = lids.Value
								AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
							ORDER BY lit.IsRent DESC, lit.IsCharge DESC, lit.IsCredit DESC
							FOR XML PATH ('')), 1, 4, '')), '[NL]', CHAR(13) + CHAR(10))
				FROM @objectIDs lids
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'RecurringCharges:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT 
					lids.Value, 
					fieldName.Value,
					REPLACE((STUFF((SELECT '[NL]' + lli.[Description] + ' - ' + CONVERT(nvarchar(20), CAST(lli.Amount AS MONEY), 1)--+
								--CASE WHEN lip.LedgerItemPoolID IS NOT NULL THEN ' (' + lip.Name + ' ' + li.[Description] + ')'
								--	 ELSE ''
								--END
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID			
								--LEFT JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
							WHERE lli.LeaseID = lids.Value
								AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
								AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value)))
							ORDER BY lit.IsRent DESC, lit.IsCharge DESC, lit.IsCredit DESC
							FOR XML PATH ('')), 1, 4, '')), '[NL]', CHAR(13) + CHAR(10))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'RecurringCharges:%'
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CurrentRecurringCharges'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'CurrentRecurringCharges', 
					REPLACE((STUFF((SELECT '[NL]' + lli.[Description] + ' - ' + CONVERT(nvarchar(20), CAST(lli.Amount AS MONEY), 1)--+
								--CASE WHEN lip.LedgerItemPoolID IS NOT NULL THEN ' (' + lip.Name + ' ' + li.[Description] + ')'
								--	 ELSE ''
								--END
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID			
								--LEFT JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
							WHERE lli.LeaseID = lids.Value
								AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
								AND lli.StartDate <= GETDATE()
								AND lli.EndDate >= GETDATE()
							ORDER BY lit.IsRent DESC, lit.IsCharge DESC, lit.IsCredit DESC
							FOR XML PATH ('')), 1, 4, '')), '[NL]', CHAR(13) + CHAR(10))
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'CurrentRecurringCharges:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT 
					lids.Value,
					fieldName.Value,
					REPLACE((STUFF((SELECT '[NL]' + lli.[Description] + ' - ' + CONVERT(nvarchar(20), CAST(lli.Amount AS MONEY), 1)
									FROM LeaseLedgerItem lli
										INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
										INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID			
									WHERE lli.LeaseID = lids.Value
										AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
										AND lli.StartDate <= GETDATE()
										AND lli.EndDate >= GETDATE()
										AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value)))
									ORDER BY lit.IsRent DESC, lit.IsCharge DESC, lit.IsCredit DESC
									FOR XML PATH ('')), 1, 4, '')), '[NL]', CHAR(13) + CHAR(10))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'CurrentRecurringCharges:%'
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RentConcessionTotal'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'RentConcessionTotal', 
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(lli.Amount), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND lit.IsCredit = 1
								AND lit.IsRecurringMonthlyRentConcession = 1)
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CurrentRentConcessionTotal'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'CurrentRentConcessionTotal', 
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(lli.Amount), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND lit.IsCredit = 1
								AND lit.IsRecurringMonthlyRentConcession = 1
								AND lli.StartDate <= GETDATE()
								AND lli.EndDate >= GETDATE())
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'CurrentRentConcessionTotal:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT 
					lids.Value,
					fieldName.Value,
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(lli.Amount), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND lit.IsCredit = 1
								AND lit.IsRecurringMonthlyRentConcession = 1
								AND lli.StartDate <= GETDATE()
								AND lli.EndDate >= GETDATE()
								AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value))))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'CurrentRentConcessionTotal:%'
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CurrentNonRentRecurringChargesTotal'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'CurrentNonRentRecurringChargesTotal', 
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(lli.Amount), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND lit.IsCharge = 1
								AND lit.IsRent = 0
								AND lli.StartDate <= GETDATE()
								AND lli.EndDate >= GETDATE())
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'CurrentNonRentRecurringChargesTotal:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT 
					lids.Value,
					fieldName.Value,
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(lli.Amount), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND lit.IsCharge = 1
								AND lit.IsRent = 0
								AND lli.StartDate <= GETDATE()
								AND lli.EndDate >= GETDATE()
								AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value))))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'CurrentNonRentRecurringChargesTotal:%'
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RecurringChargesTotal'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'RecurringChargesTotal', 
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(CASE WHEN lit.IsCredit = 1 THEN -lli.Amount ELSE lli.Amount END), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
								AND lli.StartDate <= l.LeaseStartDate
								AND lli.EndDate >= l.LeaseStartDate)
				FROM @objectIDs lids
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'RecurringChargesTotal:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT 
					lids.Value,
					fieldName.Value,
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(CASE WHEN lit.IsCredit = 1 THEN -lli.Amount ELSE lli.Amount END), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
								AND lli.StartDate <= l.LeaseStartDate
								AND lli.EndDate >= l.LeaseStartDate
								AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value))))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'RecurringChargesTotal:%'
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CurrentRecurringChargesTotal'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'CurrentRecurringChargesTotal', 
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(CASE WHEN lit.IsCredit = 1 THEN -lli.Amount ELSE lli.Amount END), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
								AND lli.StartDate <= GETDATE()
								AND lli.EndDate >= GETDATE())
				FROM @objectIDs lids
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'CurrentRecurringChargesTotal:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT
					lids.Value,
					fieldName.Value,
					(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(CASE WHEN lit.IsCredit = 1 THEN -lli.Amount ELSE lli.Amount END), 0) AS MONEY), 1)
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
								INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
							WHERE lli.LeaseID = lids.Value
								AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
								AND lli.StartDate <= GETDATE()
								AND lli.EndDate >= GETDATE()
								AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value))))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'CurrentRecurringChargesTotal:%'
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'OccupancyCount'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'OccupancyCount', 
					(SELECT ISNULL(COUNT(*), 0)
							FROM PersonLease pl													
								INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
							WHERE pl.LeaseID = lids.Value
							-- Don't include former, cancelled, or denied residents unless the lease is cancelled, former, or denied
							AND (ResidencyStatus NOT IN ('Cancelled', 'Former', 'Denied', 'Evicted') OR ResidencyStatus = LeaseStatus))
				FROM @objectIDs lids
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LeaseRequiredDeposits'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'LeaseRequiredDeposits', 
					REPLACE((STUFF((SELECT '[NL]' + lli.[Description] + ' - ' +  CONVERT(nvarchar(20), CAST(lli.Amount AS MONEY), 1)
							FROM UnitLeaseGroup ulg 
							INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID
							INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
							INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
						WHERE ulg.UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value)
						  AND lit.IsDeposit = 1
						ORDER BY lli.[Description] DESC
						FOR XML PATH ('')), 1, 4, '')), '[NL]', CHAR(13) + CHAR(10))
				FROM @objectIDs lids
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'LeaseRequiredDeposits:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT
					lids.Value,
					fieldName.Value,
					REPLACE((STUFF((SELECT '[NL]' + lli.[Description] + ' - ' +  CONVERT(nvarchar(20), CAST(lli.Amount AS MONEY), 1)
							FROM UnitLeaseGroup ulg 
							INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID
							INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
							INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
						WHERE ulg.UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value)
						  AND lit.IsDeposit = 1
						  AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value)))
						ORDER BY lli.[Description] DESC
						FOR XML PATH ('')), 1, 4, '')), '[NL]', CHAR(13) + CHAR(10))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'LeaseRequiredDeposits:%'
		END
    
    	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'DepositsPaidInTotal'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'DepositsPaidInTotal', 
					(SELECT ISNULL(SUM(t.Amount), 0)
						FROM [Transaction] t 
							INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID 
						WHERE t.ObjectID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value)
							AND tt.Name IN ('Deposit', 'Balance Transfer Deposit'))
				FROM @objectIDs lids
		END    	
		
    	IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'DepositsPaidInTotal:%'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT
					lids.Value,
					fieldName.Value,
					(SELECT ISNULL(SUM(t.Amount), 0)
						FROM [Transaction] t 
							INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
							INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
						WHERE t.ObjectID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value)
							AND tt.Name IN ('Deposit', 'Balance Transfer Deposit')
							AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value))))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'DepositsPaidInTotal:%'
		END    	
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LeaseRequiredDepositsTotal'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'LeaseRequiredDepositsTotal', 
					(SELECT ISNULL(SUM(lli.Amount), 0)
						FROM UnitLeaseGroup ulg 
							INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID
							INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
							INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
						WHERE ulg.UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value)
						  AND lit.IsDeposit = 1)
				FROM @objectIDs lids
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'LeaseRequiredDepositsTotal:%'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT
					lids.Value,
					fieldName.Value,
					(SELECT ISNULL(SUM(lli.Amount), 0)
						FROM UnitLeaseGroup ulg 
							INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID
							INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
							INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
						WHERE ulg.UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value)
						  AND lit.IsDeposit = 1
						  AND lit.Abbreviation = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value))))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'LeaseRequiredDepositsTotal:%'
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ApplicantChargesTotal'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'ApplicantChargesTotal', 
					(SELECT ISNULL(SUM(t.Amount), 0)
						FROM UnitLeaseGroup ulg 
							INNER JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID
							INNER JOIN ApplicantTypeApplicationFee ataf ON ataf.LedgerItemTypeID = T.LedgerItemTypeID
							INNER JOIN ApplicantInformation ai ON ataf.ApplicantTypeID = ai.ApplicantTypeID AND ai.FutureUnitLeaseGroupID = ulg.UnitLeaseGroupID
						WHERE ulg.UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value))                        
				FROM @objectIDs lids                
		END
        
        
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ApplicantChargesPaidTotal'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'ApplicantChargesPaidTotal', 
					(SELECT ISNULL(SUM(ta.Amount), 0)
						FROM UnitLeaseGroup ulg 
							INNER JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID
							INNER JOIN ApplicantTypeApplicationFee ataf ON ataf.LedgerItemTypeID = T.LedgerItemTypeID
							INNER JOIN ApplicantInformation ai ON ataf.ApplicantTypeID = ai.ApplicantTypeID AND ai.FutureUnitLeaseGroupID = ulg.UnitLeaseGroupID
							LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
							INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
							LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
						WHERE ulg.UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value)
							AND tr.TransactionID IS NULL
							AND t.ReversesTransactionID IS NULL
							AND tar.TransactionID IS NULL
							AND ta.ReversesTransactionID IS NULL
						)                        
				FROM @objectIDs lids    
		END   	    		
    	
	 
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PetCount'))
		BEGIN
			INSERT INTO #FormLetterData
    		SELECT lids.Value, 'PetCount', 
					(SELECT ISNULL(COUNT(*), 0)
							FROM PersonLease pl													
								INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
								INNER JOIN Pet p ON p.PersonID = pl.PersonID
							WHERE pl.LeaseID = lids.Value
							-- Don't include former or cancelled residents unless the lease is cancelled or former
							AND (ResidencyStatus NOT IN ('Cancelled', 'Former', 'Denied', 'Evicted') OR ResidencyStatus = LeaseStatus))
				FROM @objectIDs lids
		END			


		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'InsurancePolicyNumber'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'InsurancePolicyNumber', 
					(SELECT TOP 1 ri.PolicyNumber
						FROM RentersInsurance ri 
							INNER JOIN UnitLeaseGroup ulg on ulg.UnitLeaseGroupID = ri.UnitLeaseGroupID
						WHERE ulg.UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID FROM Lease WHERE LeaseID = lids.Value)
						  AND ri.PolicyNumber IS NOT NULL
					)
				FROM @objectIDs lids
		END 
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LeaseTerm'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'LeaseTerm', 
					(SELECT
						CASE 
    						WHEN DATEPART(DAY, l.LeaseStartDate) > DATEPART(DAY, l.LeaseEndDate)
    						THEN DATEDIFF(MONTH, l.LeaseStartDate, l.LeaseEndDate) - 1
    						ELSE DATEDIFF(MONTH, l.LeaseStartDate, l.LeaseEndDate)
						END
						FROM Lease l
						WHERE l.LeaseID = lids.Value
					)
				FROM @objectIDs lids
		END 
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LeaseTermPartialDays'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'LeaseTermPartialDays', 
					(SELECT 
						CASE 
    						WHEN DATEPART(DAY, l.LeaseStartDate) > DATEPART(DAY, l.LeaseEndDate)
    							THEN DATEPART(DAY, l.LeaseEndDate) --last day of lease
									 + DATEPART(DAY, DATEADD(MONTH, DATEDIFF(MONTH, -1, l.LeaseEndDate) - 1, -1)) --last day of last full month before end of lease
									 - DATEPART(DAY, l.LeaseStartDate) --start day of lease
							WHEN DATEPART(DAY, l.LeaseStartDate) < DATEPART(DAY, l.LeaseEndDate)
								THEN DATEPART(DAY, l.LeaseEndDate) - DATEPART(DAY, l.LeaseStartDate)
    						ELSE 0
						END
						FROM Lease l
						WHERE l.LeaseID = lids.Value
					)
				FROM @objectIDs lids
		END    	
			
		-- **** Unit Information ****
	
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Unit'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'Unit', u.Number
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitTypeMarketingName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'UnitTypeMarketingName', ut.MarketingName
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitStreetAddress'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'UnitStreetAddress', ISNULL(a.StreetAddress, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				LEFT JOIN [Address] a ON a.AddressID = u.AddressID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitState'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'UnitState', ISNULL(a.[State], '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				LEFT JOIN [Address] a ON a.AddressID = u.AddressID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitCity'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'UnitCity', ISNULL(a.City, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				LEFT JOIN [Address] a ON a.AddressID = u.AddressID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitZipCode'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'UnitZipCode', ISNULL(a.Zip, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				LEFT JOIN [Address] a ON a.AddressID = u.AddressID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitRequiredDeposit'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'UnitRequiredDeposit', ut.RequiredDeposit
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END           
	
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitTypeDescription'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'UnitTypeDescription', ut.[Description]
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitTypeName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'UnitTypeName', ut.Name
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MaximumOccupancy'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'MaximumOccupancy', ut.MaximumOccupancy
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		-- **** Building Information ****
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Building'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'Building', b.Name
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END

		-- **** Transaction Information ***  
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Balance'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'Balance', CONVERT(nvarchar(20), balance.Balance, 1)
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID			
				CROSS APPLY GetObjectBalance2(null, GETDATE(), l.UnitLeaseGroupID, 0, b.PropertyID) balance
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'Balance:%') OR EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'BalanceDescription:%'))
		BEGIN
			
			-- Outstanding Charges Table
			CREATE TABLE #TempTransactions (
				ID					int identity,
				ObjectID			uniqueidentifier		NOT NULL,
				TransactionID		uniqueidentifier		NOT NULL,
				Amount				money					NOT NULL,
				TaxAmount			money					NULL,
				UnPaidAmount		money					NULL,
				TaxUnpaidAmount		money					NULL,
				[Description]		nvarchar(200)			NULL,
				TranDate			datetime2				NULL,
				GLAccountID			uniqueidentifier		NULL, 
				OrderBy				smallint				NULL,
				TaxRateGroupID		uniqueidentifier		NULL,
				LedgerItemTypeID	uniqueidentifier		NULL,
				LedgerItemTypeAbbr	nvarchar(50)			NULL,
				LedgerItemTypeName	nvarchar(50)			NULL,
				GLNumber			nvarchar(50)			NULL,
				IsWriteOffable		bit						NULL,
				Notes				nvarchar(500)			NULL,
				TaxRateID			uniqueidentifier		NULL)	

			DECLARE @myObjectIDs GuidCollection
			INSERT INTO @myObjectIDs
				SELECT DISTINCT l.UnitLeaseGroupID
				FROM Lease l
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)

			INSERT INTO #TempTransactions
				EXEC GetOutstandingChargesByList @accountID, @propertyID, @myObjectIDs, 'Lease', null, 1, 1

			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'Balance:%'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT 
						lids.Value, 
						fieldName.Value,
						(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(ISNULL(#t.UnpaidAmount, 0)), 0) AS MONEY), 1)
							FROM #TempTransactions #t
								INNER JOIN Lease l ON lids.Value = l.LeaseID
								INNER JOIN UnitLeaseGroup ulg ON #t.ObjectID = ulg.UnitLeaseGroupID AND l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							WHERE #t.LedgerItemTypeAbbr IN (SELECT * from SplitString (SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value)+1, 1000), ',')))--= (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value))))
					FROM @objectIDs lids
						LEFT JOIN @fieldNames fieldName ON 1=1
						WHERE fieldName.Value LIKE 'Balance:%'
			END
        
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'BalanceDescription:%'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT 
						lids.Value, 
						fieldName.Value,
						(STUFF((SELECT ', ' + #t.LedgerItemTypeName
							FROM #TempTransactions #t
								INNER JOIN Lease l ON lids.Value = l.LeaseID
								INNER JOIN UnitLeaseGroup ulg ON #t.ObjectID = ulg.UnitLeaseGroupID AND l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							WHERE #t.UnPaidAmount <> 0
							  AND #t.LedgerItemTypeAbbr IN (SELECT * from SplitString (SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value)+1, 1000), ','))
							GROUP BY #t.LedgerItemTypeName
							FOR XML PATH ('')), 1, 2, ''))
					FROM @objectIDs lids
						LEFT JOIN @fieldNames fieldName ON 1=1
						WHERE fieldName.Value LIKE 'BalanceDescription:%'
			END
		END
        
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'LedgerCharge:%') OR EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'LedgerChargeDescription:%'))
		BEGIN
			
			CREATE TABLE #TempLedgerCharges (
				UnitLeaseGroupID	uniqueidentifier		NOT NULL,
				Amount				money					NOT NULL,
				LedgerItemTypeName	nvarchar(50)			NOT NULL,
				LedgerItemTypeAbbr	nvarchar(50)			NULL,
			)	

			INSERT #TempLedgerCharges
				SELECT t.ObjectID, t.Amount, lit.[Name], lit.Abbreviation
				FROM [Transaction] t
					INNER JOIN Lease l on t.ObjectID = l.UnitLeaseGroupID
					INNER JOIN TransactionType tt on t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN LedgerItemType lit on t.LedgerItemTypeID = lit.LedgerItemTypeID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
				  AND t.AccountID = @accountID
				  AND tt.[Name] = 'Charge'

			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'LedgerCharge:%'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT 
						lids.Value, 
						fieldName.Value,
						(SELECT CONVERT(nvarchar(20), CAST(ISNULL(SUM(ISNULL(#tlc.Amount, 0)), 0) AS MONEY), 1)
							FROM #TempLedgerCharges #tlc
								INNER JOIN Lease l ON lids.Value = l.LeaseID
								INNER JOIN UnitLeaseGroup ulg ON #tlc.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							WHERE #tlc.LedgerItemTypeAbbr IN (SELECT * from SplitString (SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value)+1, 1000), ',')))--= (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value))))
					FROM @objectIDs lids
						LEFT JOIN @fieldNames fieldName ON 1=1
						WHERE fieldName.Value LIKE 'LedgerCharge:%'
			END
        
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'LedgerChargeDescription:%'))
			BEGIN
				INSERT INTO #FormLetterData
					SELECT 
						lids.Value, 
						fieldName.Value,
						(STUFF((SELECT ', ' + #tlc.LedgerItemTypeName
							FROM #TempLedgerCharges #tlc
								INNER JOIN Lease l ON lids.Value = l.LeaseID
								INNER JOIN UnitLeaseGroup ulg ON #tlc.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
							WHERE #tlc.LedgerItemTypeAbbr IN (SELECT * from SplitString (SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value)+1, 1000), ','))
							GROUP BY #tlc.LedgerItemTypeName
							FOR XML PATH ('')), 1, 2, ''))
					FROM @objectIDs lids
						LEFT JOIN @fieldNames fieldName ON 1=1
						WHERE fieldName.Value LIKE 'LedgerChargeDescription:%'
			END
		END
        
		

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LateFeesCharged'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'LateFeesCharged', CONVERT(nvarchar(20), CAST(ISNULL(SUM(ISNULL(t.Amount, 0)), 0) AS MONEY), 1)
				FROM Lease l
				LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID			
				INNER JOIN Settings s ON s.AccountID = @accountID
				--INNER JOIN AccountingPeriod ap ON ap.AccountID = @accountID AND ap.StartDate <= GETDATE() AND ap.EndDate >= GETDATE()
				INNER JOIN PropertyAccountingPeriod pap ON pap.AccountID = @accountID AND pap.StartDate <= GETDATE() AND pap.EndDate >= GETDATE() AND pap.PropertyID = @propertyID
				LEFT JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID 
											  AND t.TransactionDate >= pap.StartDate 
											  AND t.TransactionDate <= pap.EndDate
											  AND t.LedgerItemTypeID = s.LateFeeLedgerItemTypeID
											  AND t.PropertyID = pap.PropertyID
				LEFT JOIN [Transaction]	tr ON tr.ReversesTransactionID = t.TransactionID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
					AND tr.TransactionID IS NULL
					AND t.ReversesTransactionID IS NULL
				GROUP BY ulg.UnitLeaseGroupID, l.LeaseID									
		END

   
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'AutomobilePermitNumbers'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'AutomobilePermitNumbers', 
					(STUFF((SELECT ', ' + PermitNumber
							FROM Automobile a
							INNER JOIN PersonLease pl ON a.PersonID = pl.PersonID
							INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
							WHERE l.LeaseID = lids.Value
								AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
		END

		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RentableItemTypes'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'RentableItemTypes', 
					(STUFF((SELECT distinct ', ' + lip.Name
							FROM LedgerItem li
							INNER JOIN LeaseLedgerItem lli on lli.LedgerItemID = li.LedgerItemID
							INNER JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
							where lli.LeaseID = lids.Value
								AND li.LedgerItemPoolID is not null
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'RentableItemTypes:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT
					lids.Value,
					fieldName.Value, 
					(STUFF((SELECT distinct ', ' + lip.Name
							FROM LedgerItem li
							INNER JOIN LeaseLedgerItem lli on lli.LedgerItemID = li.LedgerItemID
							INNER JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
							where lli.LeaseID = lids.Value
								AND li.LedgerItemPoolID is not null
								AND dbo.RemoveSpecialCharacters(lip.Name) = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value)))
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'RentableItemTypes:%'
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RentableItemNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'RentableItemNames', 
					(STUFF((SELECT ', ' + li.Description
							FROM LeaseLedgerItem lli
							INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
							WHERE lli.LeaseID = lids.Value
							AND li.LedgerItemPoolID is not null
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value LIKE 'RentableItemNames:%'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT
					lids.Value,
					fieldName.Value, 
					(STUFF((SELECT ', ' + li.Description
							FROM LeaseLedgerItem lli
								INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
								INNER JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = li.LedgerItemPoolID
							WHERE lli.LeaseID = lids.Value
							  AND li.LedgerItemPoolID is not null
							  AND dbo.RemoveSpecialCharacters(lip.Name) = (SELECT SUBSTRING(fieldName.Value, CHARINDEX(':', fieldName.Value) + 1, LEN(fieldName.Value) - CHARINDEX(':', fieldName.Value)))
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
					LEFT JOIN @fieldNames fieldName ON 1=1
					WHERE fieldName.Value LIKE 'RentableItemNames:%%'
		END
		
        IF (EXISTS(SELECT * FROM @fieldNames WHERE Value like 'EmergencyContact%')) 
		BEGIN -- Emergency Contact Data
			CREATE TABLE #EmergencyContacts
			(
				ID				INT,
				Name	        NVARCHAR(500) null,
				Phone   	    NVARCHAR(25) null,
                StreetAddress   NVARCHAR(500) null,
                City            NVARCHAR(50) null,
                [State]         NVARCHAR(50) null,
                Zip             NVARCHAR(20) null,
				LeaseID			uniqueIdentifier

			)
			INSERT INTO #EmergencyContacts (ID, Name, Phone, StreetAddress, City, [State], Zip, LeaseID)
			    SELECT ROW_NUMBER() OVER(PARTITION BY l.LeaseID ORDER BY l.LeaseID, ec.FirstName, ec.LastName), ec.FirstName + ' ' + ec.LastName, ec.Phone1, a.StreetAddress, a.City, a.[State], a.Zip, l.LeaseID
			        FROM Person p
			            INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID 
			            INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
                        INNER JOIN Person ec ON ec.ParentPersonID = p.PersonID
                        LEFT JOIN [Address] a ON ec.PersonID = a.ObjectID
			    WHERE l.LeaseID in (SELECT Value FROM @objectIDs)
				    AND (l.LeaseStatus IN ('Cancelled', 'Denied') OR pl.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
			    ORDER BY ec.FirstName, ec.LastName

			-- Name
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'EmergencyContact1Name'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'EmergencyContact1Name', 
					(SELECT Name FROM #EmergencyContacts e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			-- Phone
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'EmergencyContact1Phone'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'EmergencyContact1Phone', 
					(SELECT Phone FROM #EmergencyContacts e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			-- StreetAddress
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'EmergencyContact1StreetAddress'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'EmergencyContact1StreetAddress', 
					(SELECT StreetAddress FROM #EmergencyContacts e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
			-- StreetAddress
			IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'EmergencyContact1CityStateZip'))
			BEGIN
				INSERT INTO #FormLetterData
				SELECT lids.Value, 'EmergencyContact1CityStateZip', 
					(SELECT City + ', ' + [State] + ' ' + Zip FROM #EmergencyContacts e WHERE e.ID = 1 AND e.LeaseID = lids.Value) 
				FROM @objectIDs lids								
			END
		END -- emergency contact data  

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CreditBuilder'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'CreditBuilder', 
					(SELECT TOP 1
						(CASE
							WHEN @forText = 1
							THEN ('http://res.mn/' COLLATE SQL_Latin1_General_CP1_CS_AS) + s.ShortCode + p.ShortCode + 'C' 
							ELSE 'https://' + s.Subdomain + '.myresman.com/Portal/Access/SignIn/'
						 END)
					 FROM Settings s
						INNER JOIN Person p ON p.AccountID = s.AccountID
						INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID AND pl.MainContact = 1
						INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
					 WHERE l.LeaseID = lids.Value
						AND (s.ShortCode IS NOT NULL OR @forText = 0)
						AND (p.ShortCode IS NOT NULL OR @forText = 0)
						AND s.AccountID = @accountID) 
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ResidentPortal'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'ResidentPortal', 
					(SELECT TOP 1
						(CASE
							WHEN @forText = 1
							THEN ('http://res.mn/' COLLATE SQL_Latin1_General_CP1_CS_AS) + s.ShortCode + p.ShortCode + 'R' 
							ELSE 'https://' + s.Subdomain + '.myresman.com/Portal/Access/SignIn/'
						 END)
					 FROM Settings s
						INNER JOIN Person p ON p.AccountID = s.AccountID
						INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID AND pl.MainContact = 1
						INNER JOIN Lease l ON l.LeaseID = pl.LeaseID						
					 WHERE l.LeaseID = lids.Value
						AND (s.ShortCode IS NOT NULL OR @forText = 0)
						AND (p.ShortCode IS NOT NULL OR @forText = 0)
						AND s.AccountID = @accountID)
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'NumberOfOnTimePayments'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'NumberOfOnTimePayments', 
				(SELECT DATEDIFF(MONTH, l.LeaseStartDate, GETDATE()) + 1
				 -
				 (SELECT COUNT(DISTINCT ULGAPInformationID)
					FROM ULGAPInformation
					WHERE ObjectID = ulg.UnitLeaseGroupID
					  AND Late = 1))
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    End
	-- end lease data

    -- **** Property Infomration ****
	-- if the template type is applican/resident or lease or ApplicationReceived, objectids are leaseid's use them and return the leaseid in the field called leaseid
    IF (@templateType = 'ApplicantResident' or @templateType = 'Lease' or @templateType = 'ApplicationReceived' OR @templateType = 'GuarantorInvitation' )
	BEGIN
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyName', p.Name
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitCount'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT
					l.LeaseID,
					'UnitCount',
					(SELECT ISNULL(COUNT(*), 0)
						FROM Unit u2
							INNER JOIN UnitType ut2 on ut2.UnitTypeID = u2.UnitTypeID
							INNER JOIN Property p2 on p2.PropertyID = ut2.PropertyID												
						WHERE p2.PropertyID = p.PropertyID
						  AND u2.ExcludedFromOccupancy = 0
						  AND u2.IsHoldingUnit = 0
						  AND (u2.DateRemoved IS NULL OR (u2.DateRemoved > GETDATE())))
				FROM Lease l
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
					INNER JOIN Unit u on u.UnitID = ulg.UnitID
					INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
					INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyStreetAddress'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyStreetAddress', ISNULL(a.StreetAddress, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyCity'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyCity', ISNULL(a.City, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyState'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyState', ISNULL(a.[State], '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyZipCode'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyZipCode', ISNULL(a.Zip, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPhoneNumber'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyPhoneNumber', ISNULL(p.PhoneNumber, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyEmail'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyEmail', ISNULL(p.Email, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyWebsite'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyWebsite', ISNULL(p.Website, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPortalWebsite'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'PropertyPortalWebsite', ('https://' + s.Subdomain + '.myresman.com/Portal/Access/SignIn/' + p.Abbreviation)
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID	
				INNER JOIN Settings s ON s.AccountID = @accountID		
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ManagementCompanyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'ManagementCompanyName', ISNULL(v.CompanyName, '')
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				LEFT JOIN Vendor v on v.VendorID = p.ManagementCompanyVendorID
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ManagerName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'ManagerName', per.PreferredName + ' ' + per.LastName
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID
				INNER JOIN Person per ON p.ManagerPersonID = per.PersonID
 				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MonthToMonthFee'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT l.LeaseID, 'MonthToMonthFee', CONVERT(nvarchar(20), CAST(p.MonthToMonthFee AS MONEY), 1)
				FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u on u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Property p ON p.PropertyID = ut.PropertyID			
				WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
		END


		CREATE TABLE #CreditBuilderSubscribers (
			ID			INT,
			[NAME]		NVARCHAR(100) null,
			Email		NVARCHAR(500) null,
			LeaseID		uniqueIdentifier
		)

		INSERT INTO #CreditBuilderSubscribers
			SELECT
				ROW_NUMBER() OVER(PARTITION BY l.LeaseID ORDER BY l.LeaseID, pl.OrderBy, p.LastName, p.FirstName),
				(p.FirstName + ' ' + p.LastName),
				p.Email,
				l.LeaseID	
			FROM Person p
				INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID
				INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
				INNER JOIN CreditReportingPerson crp ON p.PersonID = crp.PersonID
			WHERE crp.IntegrationPartnerItemID = 247 
			  AND crp.IsActive = 1
			ORDER BY pl.OrderBy, p.LastName, p.FirstName


		CREATE TABLE #CreditBuilderSubscriberPrice(
			Price MONEY NOT NULL,
			LeaseID UNIQUEIDENTIFIER NOT NULL
		)

		INSERT INTO #CreditBuilderSubscriberPrice
			SELECT  ISNULL(ipip.Value1, ''), l.LeaseID
			FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = ut.PropertyID
			LEFT JOIN [IntegrationPartnerItemProperty] ipip ON ipip.PropertyID = p.PropertyID
			WHERE l.LeaseID IN (SELECT Value FROM @objectIDs)
				AND ipip.IntegrationPartnerItemID = 247

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CreditBuilderPrice'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT LeaseID, 'CreditBuilderPrice', Price
				FROM #CreditBuilderSubscriberPrice
				WHERE LeaseID IN (SELECT Value FROM @objectIDs)
		END

		IF(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CreditBuilderPriceTotal'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'CreditBuilderPriceTotal', 
					(SELECT SUM(cbp.Price) FROM #CreditBuilderSubscribers cbs
						INNER JOIN #CreditBuilderSubscriberPrice cbp on cbs.LeaseID = cbp.LeaseID
						WHERE cbs.LeaseID = lids.Value) 
				FROM @objectIDs lids
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CreditBuilderSubscriber1'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'CreditBuilderSubscriber1', 
				(SELECT [Name] FROM #CreditBuilderSubscribers cbs WHERE cbs.ID = 1 AND cbs.LeaseID = lids.Value) 
			FROM @objectIDs lids		
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CreditBuilderSubscriber2'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'CreditBuilderSubscriber2', 
				(SELECT [Name] FROM #CreditBuilderSubscribers cbs WHERE cbs.ID = 2 AND cbs.LeaseID = lids.Value) 
			FROM @objectIDs lids		
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CreditBuilderSubscriber3'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'CreditBuilderSubscriber3', 
				(SELECT [Name] FROM #CreditBuilderSubscribers cbs WHERE cbs.ID = 3 AND cbs.LeaseID = lids.Value) 
			FROM @objectIDs lids		
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CreditBuilderSubscriber4'))
		BEGIN
			INSERT INTO #FormLetterData
			SELECT lids.Value, 'CreditBuilderSubscriber4', 
				(SELECT [Name] FROM #CreditBuilderSubscribers cbs WHERE cbs.ID = 4 AND cbs.LeaseID = lids.Value) 
			FROM @objectIDs lids		
		END


		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CreditBuilderSubscriberNames'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'CreditBuilderSubscriberNames',
					(STUFF((SELECT ', ' + (cbs.[Name])
							FROM #CreditBuilderSubscribers cbs
							WHERE cbs.LeaseID = lids.Value
							ORDER BY cbs.ID
							FOR XML PATH ('')), 1, 2, ''))
				FROM @objectIDs lids
		END
	END
	-- other types that require property related data should be added here. 
	ELSE IF (@templateType IN ('AppResAltContact', 'EmployeeAltContact', 'ReportBatchLink', 'WorkOrderCompleted', 'WorkOrderAssigned', 'WorkOrderSubmitted', 'WorkOrder', 'PackageReceived', 'RoommateInvitation', 'SendOnlineApplication', 'WaitingList', 'WorkOrderReceived', 'MakeReadyWorkOrderAssigned', 'CertificationApproved', 'CertificationDisputed', 'CertificationDenied', 'CertificationSubmitted') 
		OR @templatetype like ('OnlinePayment%'))
	-- there should be only one leaseid or workorderid or packagelogid or processorpaymentformid in the list of objectid's, and we have to use the propertyid 
	-- to get the property data cause the objectid is something else.
	BEGIN

		-- propertyinfo from @propertyID
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyName', p.Name
				FROM  Property p
				WHERE p.PropertyID = @propertyID 				
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitCount'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT
					(SELECT Value FROM @objectIDs),
					'UnitCount',
					(SELECT ISNULL(COUNT(*), 0)
						FROM Unit u2
							INNER JOIN UnitType ut2 on ut2.UnitTypeID = u2.UnitTypeID
							INNER JOIN Property p2 on p2.PropertyID = ut2.PropertyID												
						WHERE p2.PropertyID = p.PropertyID
						  AND u2.ExcludedFromOccupancy = 0
						  AND u2.IsHoldingUnit = 0
						  AND (u2.DateRemoved IS NULL OR (u2.DateRemoved > GETDATE())))
				FROM  Property p
				WHERE p.PropertyID = @propertyID 	
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyStreetAddress'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyStreetAddress', ISNULL(a.StreetAddress, '')
				FROM  Property p
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE p.PropertyID = @propertyID 	
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyCity'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyCity', ISNULL(a.City, '')
				FROM  Property p				
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE p.PropertyID = @propertyID
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyState'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyState', ISNULL(a.[State], '')
				FROM Property p 
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE p.PropertyID = @propertyID
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyZipCode'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyZipCode', ISNULL(a.Zip, '')
				FROM Property p
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE p.PropertyID = @propertyID
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPhoneNumber'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyPhoneNumber', ISNULL(p.PhoneNumber, '')
				FROM Property p
				WHERE p.PropertyID = @propertyID
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyEmail'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyEmail', ISNULL(p.Email, '')
				FROM Property p
				WHERE p.PropertyID = @propertyID
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyWebsite'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyWebsite', ISNULL(p.Website, '')
				FROM Property p
				WHERE p.PropertyID = @propertyID
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPortalWebsite'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyPortalWebsite', ('https://' + s.Subdomain + '.myresman.com/Portal/Access/SignIn/' + p.Abbreviation)
				FROM Property p
				INNER JOIN Settings s ON s.AccountID = @accountID	
				WHERE p.PropertyID = @propertyID
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ManagementCompanyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'ManagementCompanyName', ISNULL(v.CompanyName, '')
				FROM Property p
				LEFT JOIN Vendor v on v.VendorID = p.ManagementCompanyVendorID
				WHERE p.PropertyID = @propertyID 
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ManagerName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'ManagerName', per.PreferredName + ' ' + per.LastName
				FROM  Property p 
				INNER JOIN Person per ON p.ManagerPersonID = per.PersonID
 				WHERE p.PropertyID = @propertyID 
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MonthToMonthFee'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'MonthToMonthFee', CONVERT(nvarchar(20), CAST(p.MonthToMonthFee AS MONEY), 1)
				FROM Property p
				WHERE p.PropertyID = @propertyID
		END
	END
	ELSE -- @objectID is a list of personid's
	BEGIN
		-- propertyinfo from @propertyID
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyName', p.Name
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID 
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs) 				
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitCount'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT
					per.PersonID,
					'UnitCount',
					(SELECT ISNULL(COUNT(*), 0)
						FROM Unit u2
							INNER JOIN UnitType ut2 on ut2.UnitTypeID = u2.UnitTypeID
							INNER JOIN Property p2 on p2.PropertyID = ut2.PropertyID												
						WHERE p2.PropertyID = p.PropertyID
						  AND u2.ExcludedFromOccupancy = 0
						  AND u2.IsHoldingUnit = 0
						  AND (u2.DateRemoved IS NULL OR (u2.DateRemoved > GETDATE())))
				FROM Person per 
					INNER JOIN Property p on p.PropertyID = @propertyID 
					LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyStreetAddress'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyStreetAddress', ISNULL(a.StreetAddress, '')
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID 
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyCity'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyCity', ISNULL(a.City, '')
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID 
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyState'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyState', ISNULL(a.[State], '')
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID 
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyZipCode'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyZipCode', ISNULL(a.Zip, '')
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID 
				LEFT JOIN [Address] a ON a.AddressID = p.AddressID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPhoneNumber'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyPhoneNumber', ISNULL(p.PhoneNumber, '')
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyEmail'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyEmail', ISNULL(p.Email, '')
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyWebsite'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyWebsite', ISNULL(p.Website, '')
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyPortalWebsite'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PropertyPortalWebsite', ('https://' + s.Subdomain + '.myresman.com/Portal/Access/SignIn/' + p.Abbreviation)
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID	
				INNER JOIN Settings s ON s.AccountID = p.AccountID				
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ManagementCompanyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'ManagementCompanyName', ISNULL(v.CompanyName, '')
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID
				LEFT JOIN Vendor v on v.VendorID = p.ManagementCompanyVendorID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ManagerName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'ManagerName', per2.PreferredName + ' ' + per2.LastName
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID
				INNER JOIN Person per2 on p.ManagerPersonID = per2.PersonID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MonthToMonthFee'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'MonthToMonthFee', CONVERT(nvarchar(20), CAST(p.MonthToMonthFee AS MONEY), 1)
				FROM Person per 
				INNER JOIN Property p on p.PropertyID = @propertyID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
	END
		
	-- now we need to get aditional data based on the templatetype
	-- if the template type is vendor use the personid to get the contactname and join to get the vendor companyname and customernumber
	If (@templateType = 'vendor')
	BEGIN
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CompanyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'CompanyName', v.CompanyName
				FROM Person per INNER JOIN VendorPerson vp on vp.PersonID = per.PersonID
				INNER JOIN Vendor v on v.VendorID = vp.VendorID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
					OR per.PersonID = @personID
						
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CustomerNumber'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'CustomerNumber', v.CustomerNumber
				FROM Person per INNER JOIN VendorPerson vp on vp.PersonID = per.PersonID
				INNER JOIN Vendor v on v.VendorID = vp.VendorID
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
					OR per.PersonID = @personID
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ContactName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'ContactName', per.PreferredName
				FROM Person per 
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
					OR per.PersonID = @personID
		END
	END

	-- if the templatetype is applicant/resident or applicationreceived we will use personid to get person related data but use the leasid in the leaseid field
	IF (@templateType IN ('ApplicantResident', 'ApplicationReceived', 'WaitingList'))
	BEGIN
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'FirstName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'FirstName', per.FirstName
				FROM Person per				
				WHERE per.PersonID = @personID
		END

		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'LastName', per.LastName
				FROM Person per 
				WHERE per.PersonID = @personID
		END
		

		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PreferredName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PreferredName', per.PreferredName
				FROM Person per 				
				WHERE per.PersonID = @personID
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'EmailAddress'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'EmailAddress', per.Email
				FROM Person per 				
				WHERE per.PersonID = @personID
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Birthday'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'Birthday', FORMAT(per.Birthdate, 'M/d/yyyy')
				FROM Person per 				
				WHERE per.PersonID = @personID
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'AutoLicensePlate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'AutoLicensePlate', a.LicensePlateNumber
				FROM Automobile a 				
				WHERE a.PersonID = @personID
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'AutoLicenseState'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'AutoLicenseState', a.LicensePlateState
				FROM Automobile a 				
				WHERE a.PersonID = @personID
		END

		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'VehicleMake'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'VehicleMake', a.Make
				FROM Automobile a 				
				WHERE a.PersonID = @personID
		END

		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'VehicleModel'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'VehicleModel', a.Model
				FROM Automobile a 				
				WHERE a.PersonID = @personID
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE VALUE = 'VehicleColor'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'VehicleColor', a.Color
				FROM Automobile a
				WHERE a.PersonID = @personID
		END

		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'MobilePhone'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'MobilePhone', 
				CASE WHEN per.Phone1Type = 'Mobile' THEN per.Phone1
					 WHEN per.Phone2Type = 'Mobile' THEN per.Phone2
					 WHEN per.Phone3Type = 'Mobile' THEN per.Phone3
				END
				FROM Person per 				
				WHERE per.PersonID = @personID
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'HomePhone'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'HomePhone', 
				CASE WHEN per.Phone1Type = 'Home' THEN per.Phone1
					 WHEN per.Phone2Type = 'Home' THEN per.Phone2
					 WHEN per.Phone3Type = 'Home' THEN per.Phone3
				END
				FROM Person per 				
				WHERE per.PersonID = @personID
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'WorkPhone'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'WorkPhone', 
				CASE WHEN per.Phone1Type = 'Work' THEN per.Phone1
					 WHEN per.Phone2Type = 'Work' THEN per.Phone2
					 WHEN per.Phone3Type = 'Work' THEN per.Phone3
				END
				FROM Person per 				
				WHERE per.PersonID = @personID
		END
	END

	IF (@templateType = 'AppResAltContact' or @templateType = 'EmployeeAltContact')
	BEGIN
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Name'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'Name', per.PreferredName
				FROM Person per				
				WHERE per.PersonID = @personID
		END
	END

	-- if the template type is employee/user or nonresidentaccount get the common person related data from the personid and put the personid in the leaseid field
	--IF (@templateType =  'NonResidentAccount' or @templateType = 'Prospect' or @templateType = 'EmployeeUser' or @templateType = 'ProspectGuestCard' or @templateType = 'GuestCardReceived')
	IF (@templateType IN ('NonResidentAccount', 'Prospect', 'EmployeeUser', 'ProspectGuestCard', 'GuestCardReceived', 'GuestCardSubmitted', 'SendQuote'))
	BEGIN
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'FirstName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'FirstName', per.FirstName
				FROM Person per 
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END

		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'LastName', per.LastName
				FROM Person per 
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END

		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PreferredName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT per.PersonID, 'PreferredName', per.PreferredName
				FROM Person per 
				WHERE per.PersonID IN (SELECT Value FROM @objectIDs)
		END
	END

	-- if it's a workorder template, we get the work order fields from the WorkOrder table and get the property data by joining workorder to propertyid
	IF (@templatetype = 'WorkOrderCompleted' or @templateType = 'WorkOrderAssigned' or @templateType = 'workOrder' or @templateType = 'WorkOrderSubmitted' or @templateType = 'WorkOrderReceived' or @templateType = 'MakeReadyWorkOrderAssigned')
	BEGIN

		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Category'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'Category', pl.Name
				FROM WorkOrder w join PickListItem pl on w.WorkOrderCategoryID = pl.PickListItemID
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CompletedBy'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'CompletedBy', per.FirstName + ' ' + per.LastName
				FROM WorkOrder w join Person per on w.CompletedPersonID = per.PersonID
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'DateCompleted'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'DateCompleted', CONVERT(nvarchar(50), w.CompletedDate, 101)
				FROM WorkOrder w
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'DateReported'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'DateReported', CONVERT(nvarchar(50), w.ReportedDate, 101)
				FROM WorkOrder w
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Description'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'Description', w.Description
				FROM WorkOrder w
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Location'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'Location', w.ObjectType + ' ' + w.ObjectName
				FROM WorkOrder w
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Number'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'Number', w.Number
				FROM WorkOrder w 
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ReportedBy'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'ReportedBy', per.FirstName + ' ' + per.LastName
				FROM WorkOrder w join Person per on w.ReportedPersonID = per.PersonID
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ReportingNotes'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'ReportingNotes', w.ReportedNotes
				FROM WorkOrder w
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END	
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'DateDue'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'DateDue', CONVERT(nvarchar(50), w.DueDate, 101)
				FROM WorkOrder w 
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'AssignedTo'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT w.WorkOrderID, 'AssignedTo', per.FirstName + ' ' + per.LastName
				FROM WorkOrder w join Person per on w.AssignedPersonID = per.PersonID
				WHERE w.WorkOrderID = (SELECT Value from @objectIDs)
		END
	END

	IF (@templateType = 'PackageReceived')
	BEGIN
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Courier'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'Courier', COALESCE(pl.Courier, '')
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Sender'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'Sender', COALESCE(pl.Sender, '')
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'NumberOfPackages'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'NumberOfPackages', count(pk.PackageID)
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				join Package pk on pl.PackageLogID = pk.PackageLogID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
				group by pl.PackageLogID
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'DateReceived'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'DateReceived', COALESCE(CONVERT(nvarchar(50), pl.DateReceived, 101), '')
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'DatePickedUp'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'DatePickedUp', COALESCE(CONVERT(nvarchar(50), pl.DatePickedUp, 101), '')
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PickedUpBy'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'PickedUpBy', COALESCE(pl.PickedUpBy, '')
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'FirstName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'FirstName', per.FirstName
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'LastName', per.LastName
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PreferredName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT pl.PackageLogID, 'PreferredName', per.PreferredName
				FROM PackageLog pl join Person per on pl.RecipientPersonID = per.PersonID
				WHERE pl.PackageLogID = (SELECT Value from @objectIDs)
		END
	END	
	
	-- if the templatetype is employee/user and personid is not null, get the employee/user related data from a join to personid and populate LeaseId field with the personID
	-- this should only happen in the case of a one off email
	-- no fields for this now

	-- if the template type is prospect and the personid is not null, the prospectid is in the objectid, use it to get prospect related data and populate LeaseId field with the personID
	-- this should only happen in the case of a one off email
	-- no fields for this now
	
	-- if the teplate is onlinepayment, use the personid to get any specific fields we need but use the objectid as the "leaseid" (the field that that links the data back to the person)
	IF (@templateType like 'OnlinePayment%')
	BEGIN
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'FirstName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value from @objectIDs), 'FirstName', p.FirstName
				FROM Person p
				WHERE p.PersonID = @personID
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value from @objectIDs), 'LastName', p.LastName
				FROM Person p
				WHERE p.PersonID = @personID
		END
	END

	--If template type is RoommateInvitation then the main applicants personID was passed in to @personID and the leaseID was passed into @objectIDs
	IF (@templateType = 'RoommateInvitation')
	BEGIN
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ApplicantFirstName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'ApplicantFirstName', p.FirstName
				FROM Person p
				WHERE p.PersonID = @personID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ApplicantLastName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'ApplicantLastName', p.LastName
				FROM Person p
				WHERE p.PersonID = @personID
		END
	END

	IF (@templateType = 'InvoiceApprovalRequired' OR @templateType = 'InvoiceDisputed' OR @templateType = 'InvoiceApproved' )
	BEGIN
		set @objectID = (SELECT Value FROM @objectIDs)
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'InvoiceNumber'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'InvoiceNumber', i.Number
				FROM Invoice i
				WHERE i.InvoiceID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'VendorName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'VendorName', v.CompanyName
				FROM Invoice i join Vendor v on i.VendorID = v.VendorID
				WHERE i.InvoiceID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'InvoiceDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'InvoiceDate', CONVERT(nvarchar(50), i.InvoiceDate, 101) 
				FROM Invoice i
				WHERE i.InvoiceID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'ReceivedDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'ReceivedDate', CONVERT(nvarchar(50), i.ReceivedDate, 101) 
				FROM Invoice i
				WHERE i.InvoiceID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'DueDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'DueDate', CONVERT(nvarchar(50), i.DueDate, 101)
				FROM Invoice i
				WHERE i.InvoiceID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'AccountingDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'AccountingDate', CONVERT(nvarchar(50), i.AccountingDate, 101)
				FROM Invoice i
				WHERE i.InvoiceID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Total'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'Total', i.Total
				FROM Invoice i
				WHERE i.InvoiceID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Description'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'Description', i.[Description]
				FROM Invoice i
				WHERE i.InvoiceID = @objectID
		END
	end

	IF (@templateType = 'POApprovalRequired' OR @templateType = 'PODenied' OR @templateType = 'PODisputed' OR @templateType = 'POApproved' OR @templateType = 'POSubmitToVendor')
	BEGIN
		set @objectID = (SELECT Value FROM @objectIDs)
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PurchaseOrderNumber'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'PurchaseOrderNumber', p.Number
				FROM PurchaseOrder p
				WHERE p.PurchaseOrderID = @objectID		
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'VendorName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'VendorName', v.CompanyName
				FROM PurchaseOrder p join Vendor v on p.VendorID = v.VendorID
				WHERE p.PurchaseOrderID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PostingDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'PostingDate',CONVERT(nvarchar(50), p.[Date], 101) 
				FROM PurchaseOrder p
				WHERE p.PurchaseOrderID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Description'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'Description', p.[Description]
				FROM PurchaseOrder p
				WHERE p.PurchaseOrderID = @objectID
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Total'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'Total', p.Total
				FROM PurchaseOrder p
				WHERE p.PurchaseOrderID = @objectID
		END
	END

	IF (@templateType = 'WaitingList')
	BEGIN
		set @objectID = (SELECT Value FROM @objectIDs)
		--DECLARE @objectName nvarchar(200)

		--SET @objectName = (SELECT Number FROM Unit WHERE UnitID = @objectID)
		--IF(@objectName IS NULL)
		--BEGIN
		--	SET @objectName = (SELECT Name FROM UnitType WHERE UnitTypeID = @objectID)
		--	IF(@objectName IS NULL)
		--	BEGIN
		--		SET @objectName = (SELECT Name FROM LedgerItem WHERE LedgerItemID = @objectID)
		--		IF(@objectName IS NULL)
		--		BEGIN
		--			SET @objectName = (SELECT Name FROM LedgerItemPool WHERE LedgerItemPoolID = @objectID)

		--		END

		--	END
		--	ELSE
		--		SET @objectName = 'Unit Type ' + @objectName
		--END
		--ELSE
		--	SET @objectName = 'Unit ' + @objectName


		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'WaitingListName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'WaitingListName', ISNULL(u.Number, ISNULL(ut.Name, ISNULL(li.[Description], lip.Name)))
				FROM @objectIDs
				LEFT JOIN Unit u ON u.UnitID = Value
				LEFT JOIN UnitType ut ON ut.UnitTypeID = Value
				LEFT JOIN LedgerItem li ON li.LedgerItemID = Value
				LEFT JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = Value
		END
	END

	IF (@templateType = 'ReceivedApplication') 	
	BEGIN
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'FirstName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value from @objectIDs), 'FirstName', p.FirstName 
				FROM Person p 
				INNER JOIN ApplicantInformationPerson app on p.PersonID = app.PersonID
				WHERE app.ApplicantInformationID IN (SELECT Value from @objectIDs)
				AND app.ApplicantType = 'Main'
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'LastName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value from @objectIDs), 'LastName', p.LastName
				FROM Person p 
				INNER JOIN ApplicantInformationPerson app on p.PersonID = app.PersonID
				WHERE app.ApplicantInformationID IN (SELECT Value from @objectIDs)
				AND app.ApplicantType = 'Main'
		END
		IF	(EXISTS(SELECT * FROM @fieldNames WHERE Value = 'Unit'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value from @objectIDs), 'Unit', u.Number
				FROM Unit u 
				INNER JOIN UnitLeaseGroup ulg on ulg.UnitID = u.UnitID
				INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN ApplicantInformation app on app.LeaseID = l.LeaseID 
				WHERE app.ApplicantInformationID IN (SELECT Value from @objectIDs)
		END
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyName', p.Name
				FROM Property p
				WHERE p.PropertyID = @propertyID
		END
	END

	IF (@templateType IN ('CertificationApproved', 'CertificationDisputed', 'CertificationDenied', 'CertificationSubmitted'))
	BEGIN
		-- ***** Certification Information *****
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CertificationUnit'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT c.CertificationID, 'CertificationUnit', u.Number
				FROM Certification c
					INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u on u.UnitID = ulg.UnitID
				WHERE c.CertificationID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'CertificationPersonName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT c.CertificationID, 'CertificationPersonName', (STUFF((SELECT ', ' + (FirstName + ' ' + LastName)
																				FROM Person p
																				INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID AND pl.MainContact = 1
																				INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
																				INNER JOIN Certification c on c.LeaseID = l.LeaseID										
																				WHERE c.CertificationID IN (SELECT Value FROM @objectIDs)
																					AND pl.ResidencyStatus <> 'Cancelled'
																				ORDER BY pl.OrderBy, p.FirstName
																				FOR XML PATH ('')), 1, 2, ''))
				FROM Certification c
				WHERE
					c.CertificationID IN (SELECT Value FROM @objectIDs)
		END
	END

	IF (@templateType IN ('RepaymentAgreement'))
	BEGIN
		-- ***** Repayment Information *****
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'PropertyName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT (SELECT Value FROM @objectIDs), 'PropertyName', p.Name
				FROM  Property p
				WHERE p.PropertyID = @propertyID 				
		END 
    
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RepaymentAgreementID'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT r.RepaymentAgreementID, 'RepaymentAgreementID', r.AgreementID
				FROM RepaymentAgreement r
				WHERE r.RepaymentAgreementID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RepaymentAgreementStartDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT r.RepaymentAgreementID, 'RepaymentAgreementStartDate', COALESCE(CONVERT(nvarchar(50), r.AgreementStartDate, 101), '')
				FROM RepaymentAgreement r
				WHERE r.RepaymentAgreementID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RepaymentAgreementEndDate'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT r.RepaymentAgreementID, 'RepaymentAgreementEndDate', COALESCE(CONVERT(nvarchar(50), r.AgreementEndDate, 101), '')
				FROM RepaymentAgreement r
				WHERE r.RepaymentAgreementID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RepaymentAgreementTotalRequestedAmount'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT r.RepaymentAgreementID, 'RepaymentAgreementTotalRequestedAmount', CAST(r.TotalRequestedAmount AS MONEY)
				FROM RepaymentAgreement r
				WHERE r.RepaymentAgreementID IN (SELECT Value FROM @objectIDs)
		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'RepaymentAgreementSchedule'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT lids.Value, 'RepaymentAgreementSchedule',  
					REPLACE((STUFF((SELECT '[NL]' + (COALESCE(CONVERT(nvarchar(50), ras.DueDate, 101), '') + ' - $' + CONVERT(nvarchar(20), CAST(ras.Amount AS MONEY), 1))
							FROM RepaymentAgreementSchedule ras
							WHERE ras.RepaymentAgreementID = lids.Value
							ORDER BY ras.DueDate
							FOR XML PATH ('')), 1, 4, '')), '[NL]', CHAR(13) + CHAR(10))
				FROM @objectIDs lids

		END

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'UnitStreetAddress'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT r.RepaymentAgreementID, 'UnitStreetAddress', ISNULL(a.StreetAddress, '')
				FROM RepaymentAgreement r
					INNER JOIN Lease l ON r.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
					INNER JOIN Unit u on u.UnitID = ulg.UnitID
					LEFT JOIN [Address] a ON a.AddressID = u.AddressID
				WHERE r.RepaymentAgreementID IN (SELECT Value FROM @objectIDs)
		END
	END

	--For Guarantor templates, the objectID is a leaseID, the personID is the guarantor personID
	IF (@templateType = 'GuarantorInvitation')
	BEGIN
		SET @objectID = (SELECT TOP 1 Value FROM @objectIDs)




		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'GuarantorFirstName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'GuarantorFirstName', FirstName
					FROM Person
					WHERE PersonID = @personID
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'GuarantorLastName'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'GuarantorLastName', LastName
					FROM Person
					WHERE PersonID = @personID
		END

		

		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'GuarantorEmail'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'GuarantorEmail', Email
					FROM Person
					WHERE PersonID = @personID
		END
		
		IF (EXISTS(SELECT * FROM @fieldNames WHERE Value = 'GuarantorPhoneNumber'))
		BEGIN
			INSERT INTO #FormLetterData
				SELECT @objectID, 'GuarantorPhoneNumber', Phone1
					FROM Person
					WHERE PersonID = @personID
		END

	END

    SELECT * FROM #FormLetterData WHERE Value IS NOT NULL
	
END
		
		
		
		



GO
