CREATE TABLE [dbo].[WorkOrderTransaction]
(
[AccountID] [bigint] NOT NULL,
[WorkOrderID] [uniqueidentifier] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrderTransaction] ADD CONSTRAINT [PK_WorkOrderTransaction] PRIMARY KEY CLUSTERED  ([WorkOrderID], [AccountID], [TransactionID]) ON [PRIMARY]
GO
