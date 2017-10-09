CREATE TABLE [dbo].[UnitNote]
(
[UnitNoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL,
[UnitStatusID] [uniqueidentifier] NOT NULL,
[NoteTypeID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NOT NULL CONSTRAINT [DF_UnitNote_DateCreated] DEFAULT (getdate()),
[Date] [date] NOT NULL CONSTRAINT [DF_UnitNote_Date] DEFAULT (getdate())
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitNote] ADD CONSTRAINT [PK_UnitMaintenanceCleaningLog] PRIMARY KEY CLUSTERED  ([UnitNoteID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_UnitNote_UnitID] ON [dbo].[UnitNote] ([UnitID]) INCLUDE ([DateCreated], [UnitStatusID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitNote] WITH NOCHECK ADD CONSTRAINT [FK_UnitMaintenanceCleaningLog_Unit] FOREIGN KEY ([UnitID], [AccountID]) REFERENCES [dbo].[Unit] ([UnitID], [AccountID])
GO
ALTER TABLE [dbo].[UnitNote] WITH NOCHECK ADD CONSTRAINT [FK_UnitMaintenanceCleaningLog_UnitStatus] FOREIGN KEY ([UnitStatusID], [AccountID]) REFERENCES [dbo].[UnitStatus] ([UnitStatusID], [AccountID])
GO
ALTER TABLE [dbo].[UnitNote] NOCHECK CONSTRAINT [FK_UnitMaintenanceCleaningLog_Unit]
GO
ALTER TABLE [dbo].[UnitNote] NOCHECK CONSTRAINT [FK_UnitMaintenanceCleaningLog_UnitStatus]
GO
