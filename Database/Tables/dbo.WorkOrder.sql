CREATE TABLE [dbo].[WorkOrder]
(
[WorkOrderID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[ReceivedPersonID] [uniqueidentifier] NOT NULL,
[UnitNoteID] [uniqueidentifier] NULL,
[WorkOrderCategoryID] [uniqueidentifier] NOT NULL,
[VendorID] [uniqueidentifier] NULL,
[ReportedPersonID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ObjectName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Number] [int] NOT NULL,
[Description] [nvarchar] (248) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EstimatedCost] [money] NULL,
[Priority] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Status] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ReportedPersonName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReportedDate] [date] NOT NULL,
[ReportedNotes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DueDate] [date] NOT NULL,
[AssignedPersonID] [uniqueidentifier] NOT NULL,
[StartedPersonID] [uniqueidentifier] NULL,
[StartedDate] [datetime] NULL,
[CompletedPersonID] [uniqueidentifier] NULL,
[CompletedDate] [datetime] NULL,
[CompletedNotes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Appointment] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactPhone] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Pets] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ScheduledDate] [datetime] NULL,
[InventoryItemID] [uniqueidentifier] NULL,
[CancellationReasonPickListItemID] [uniqueidentifier] NULL,
[CancellationDate] [date] NULL,
[ReportedDateTime] [datetime] NOT NULL,
[LastModified] [datetime] NOT NULL,
[Areas] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrder] ADD CONSTRAINT [PK_WorkOrder] PRIMARY KEY CLUSTERED  ([WorkOrderID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrder] WITH NOCHECK ADD CONSTRAINT [FK_WorkOrder_UnitMaintenanceCleaningLog] FOREIGN KEY ([UnitNoteID], [AccountID]) REFERENCES [dbo].[UnitNote] ([UnitNoteID], [AccountID])
GO
ALTER TABLE [dbo].[WorkOrder] NOCHECK CONSTRAINT [FK_WorkOrder_UnitMaintenanceCleaningLog]
GO
