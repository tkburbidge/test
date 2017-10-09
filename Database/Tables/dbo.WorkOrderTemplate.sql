CREATE TABLE [dbo].[WorkOrderTemplate]
(
[WorkOrderTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[DaysUntilDue] [int] NOT NULL,
[LocationID] [uniqueidentifier] NULL,
[LocationType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LocationName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[InventoryItemID] [uniqueidentifier] NULL,
[ReceivedPersonID] [uniqueidentifier] NOT NULL,
[ReportedPersonID] [uniqueidentifier] NULL,
[Appointment] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactPhone] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Pets] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (248) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[WorkOrderCategoryID] [uniqueidentifier] NOT NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Priority] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[VendorID] [uniqueidentifier] NULL,
[RecurringItemID] [uniqueidentifier] NOT NULL,
[AssignedPersonID] [uniqueidentifier] NOT NULL,
[Areas] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrderTemplate] ADD CONSTRAINT [PK_WorkOrderTemplate] PRIMARY KEY CLUSTERED  ([WorkOrderTemplateID], [AccountID]) ON [PRIMARY]
GO
