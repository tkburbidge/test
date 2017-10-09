CREATE TABLE [dbo].[TableAudit]
(
[TableAuditID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ChangedPersonID] [uniqueidentifier] NOT NULL,
[TableName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ColumnName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OldValue] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewValue] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Action] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateTime] [datetime] NOT NULL,
[IPAddress] [nvarchar] (39) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TableAudit] ADD CONSTRAINT [PK_TableAudit] PRIMARY KEY CLUSTERED  ([TableAuditID], [AccountID]) ON [PRIMARY]
GO
