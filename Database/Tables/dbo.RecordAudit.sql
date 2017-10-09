CREATE TABLE [dbo].[RecordAudit]
(
[RecordAuditID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[CreatedDate] [date] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[Timestamp] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RecordAudit] ADD CONSTRAINT [PK_RecordAudit] PRIMARY KEY CLUSTERED  ([RecordAuditID], [AccountID]) ON [PRIMARY]
GO
