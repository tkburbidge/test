SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 2, 2017
-- Description:	Gets the WorkOrder Make Ready Board
-- =============================================
CREATE PROCEDURE [dbo].[GetMakeReadyBoardInformation] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@localDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #BoredInfo (
		UnitID uniqueidentifier not null,
		Unit nvarchar(50) null,
		LeaseID uniqueidentifier null,
		IsVacant bit null,
		ResidentList nvarchar(500) null,
		MoveInDate date null,
		MoveOutDate date null,
		UnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		LastVacatedDate date null,
		UnitType nvarchar(50) null,
		[Status] nvarchar(50) null,
		DateAvailable date null,
		MakeReadyNote nvarchar(MAX) null,
		MakeReadyUnitNoteID uniqueidentifier null,
		MakeReadyDate date null)

	CREATE TABLE #BoredWorkOrders (
		UnitID uniqueidentifier not null,
		Unit nvarchar(50) null,
		WorkOrderID uniqueidentifier null,
		WorkOrderCategoryID uniqueidentifier null,
		[Description] nvarchar(MAX) null,
		[Status] nvarchar(100) null,
		VendorName nvarchar(100) null,
		AssignedPersonID uniqueidentifier null,
		ScheduledDate date null,
		CompletedDate date null)



		
	INSERT #BoredInfo
		SELECT	DISTINCT
				u.UnitID,
				u.Number,
				[CurrentLease].LeaseID,
				CASE 
					WHEN ([CurrentLease].LeaseID IS NOT NULL) THEN CAST(0 AS bit)
					ELSE CAST(1 AS bit) END AS 'IsVacant',
				--CAST(0 as bit) AS 'IsVacant',
				[PendingLease].Residents AS 'Residents',
				[PendingLease].MoveInDate AS 'MoveInDate',
				[CurrentLease].MoveOutDate AS 'MoveOutDate',
				[PendingLease].UnitLeaseGroupID AS 'UnitLeaseGroupID',
				[PendingLease].LeaseID AS 'PendingLeaseID',
				u.LastVacatedDate AS 'LastVacatedDate',
				ut.Name AS 'UnitType',							-- UnitType.Name
				(SELECT TOP 1 us.Name
					FROM UnitStatus us
						INNER JOIN UnitNote un ON us.UnitStatusID = un.UnitStatusID
					WHERE un.UnitID = u.UnitID
					ORDER BY un.[Date] DESC, un.DateCreated DESC) AS 'Status',
				u.DateAvailable AS 'DateAvailable',
				-- MakeReadyNote
				[MakeReadyNote].Notes AS 'MakeReadyNote',
				[MakeReadyNote].UnitNoteID AS 'MakeReadyUnitNoteID',
				[MakeReadyNote].[Date] AS 'MakeReadyDate'

			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID

				LEFT JOIN
						(SELECT pulg.UnitID, pl.LeaseID, MIN(ppl.MoveInDate) AS 'MoveInDate', pulg.UnitLeaseGroupID,
								(SELECT (STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
									 FROM Person 
										 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
										 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
									 WHERE PersonLease.LeaseID = pl.LeaseID
										   AND PersonType.[Type] = 'Resident'				   
										   AND PersonLease.MainContact = 1				   
									 FOR XML PATH ('')), 1, 2, ''))) AS 'Residents'
							FROM UnitLeaseGroup pulg
								INNER JOIN Lease pl ON pulg.UnitLeaseGroupID = pl.UnitLeaseGroupID
								INNER JOIN PersonLease ppl ON pl.LeaseID = ppl.LeaseID AND ppl.MainContact = 1
								INNER JOIN Person pper ON ppl.PersonID = pper.PersonID
							WHERE pl.LeaseStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer')
							GROUP BY pulg.UnitID, pl.LeaseID, pulg.UnitLeaseGroupID) AS [PendingLease] ON u.UnitID = [PendingLease].UnitID

				LEFT JOIN
						(SELECT culg.UnitID, cl.LeaseID, cl.LeaseStartDate, MAX(cpl.MoveOutDAte) AS 'MoveOutDate'
							FROM UnitLeaseGroup culg
								INNER JOIN Lease cl ON culg.UnitLeaseGroupID = cl.UnitLeaseGroupID
								LEFT JOIN PersonLease cpl ON cl.LeaseID = cpl.LeaseID
							WHERE cl.LeaseStatus IN ('Current', 'Under Eviction')
							GROUP BY culg.UnitID, cl.LeaseID, cl.LeaseStartDate) AS [CurrentLease] ON u.UnitID = [CurrentLease].UnitID

				LEFT JOIN
						(SELECT ROW_NUMBER() OVER (PARTITION BY UnitID ORDER BY [Date] DESC, DateCreated DESC) AS 'FindTheLatest', un.UnitNoteID, un.UnitID, un.Notes, un.[Date], un.DateCreated
							FROM UnitNote un
								INNER JOIN PickListItem pliMakeReady ON un.NoteTypeID = pliMakeReady.PickListItemID
							WHERE un.Notes <> 'Unit Created'
							  AND pliMakeReady.[Type] = 'UnitNoteType'
							  AND pliMakeReady.Name = 'Make Ready') [MakeReadyNote] ON u.UnitID = [MakeReadyNote].UnitID AND [MakeReadyNote].FindTheLatest = 1	

			WHERE ((SELECT TOP 1 us.Name
						FROM UnitStatus us
							INNER JOIN UnitNote un ON us.UnitStatusID = un.UnitStatusID
						WHERE un.UnitID = u.UnitID
						ORDER BY un.[Date] DESC, un.DateCreated DESC) IN ('Ready', 'Not Ready', 'Abated'))
			  AND u.IsHoldingUnit = 0
			  AND ((u.DateRemoved IS NULL) OR (u.DateRemoved > @localDate))
			  AND [MakeReadyNote].UnitNoteID IS NOT NULL
			  AND (([CurrentLease].LeaseID IS NULL)  OR ([MakeReadyNote].DateCreated >= [CurrentLease].LeaseStartDate))

	INSERT #BoredWorkOrders
		SELECT	#bi.UnitID,
				#bi.Unit,
				wo.WorkOrderID,
				wo.WorkOrderCategoryID,
				wo.[Description],
				wo.[Status],
				v.CompanyName AS 'VendorName',
				assPer.PersonID AS 'AssignedPersonID',
				wo.ScheduledDate,
				wo.CompletedDate
			FROM WorkOrder wo
				INNER JOIN #BoredInfo #bi ON wo.ObjectID = #bi.UnitID
				LEFT JOIN Person assPer ON wo.AssignedPersonID = assPer.PersonID
				LEFT JOIN Vendor v ON wo.VendorID = v.VendorID
			WHERE #bi.MakeReadyUnitNoteID IS NOT NULL
			  AND DATEPART(YEAR, wo.ReportedDateTime) = DATEPART(YEAR, #bi.MakeReadyDate)
			  AND DATEPART(MONTH, wo.ReportedDateTime) = DATEPART(MONTH, #bi.MakeReadyDate)
			  AND DATEPART(DAY, wo.ReportedDateTime) = DATEPART(DAY, #bi.MakeReadyDate)	

	SELECT * 
		FROM #BoredInfo
		ORDER BY Unit

	SELECT *
		FROM #BoredWorkOrders
		ORDER BY Unit

	SELECT	DISTINCT *
		FROM Person
		WHERE PersonID IN (SELECT DISTINCT AssignedPersonID 
								FROM #BoredWorkOrders)

END
GO
