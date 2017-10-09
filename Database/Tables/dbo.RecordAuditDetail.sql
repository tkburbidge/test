CREATE TABLE [dbo].[RecordAuditDetail]
(
[RecordAuditDetailID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RecordAuditID] [uniqueidentifier] NOT NULL,
[RecordChanged] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OldValue] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewValue] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RecordAuditDetail] ADD CONSTRAINT [PK_RecordAuditDetail] PRIMARY KEY CLUSTERED  ([RecordAuditDetailID], [AccountID]) ON [PRIMARY]
GO
