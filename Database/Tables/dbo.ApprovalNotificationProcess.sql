CREATE TABLE [dbo].[ApprovalNotificationProcess]
(
[ApprovalNotificationProcessID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Processed] [bit] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApprovalNotificationProcess] ADD CONSTRAINT [PK_ApprovalNotificationProcess] PRIMARY KEY CLUSTERED  ([ApprovalNotificationProcessID], [AccountID]) ON [PRIMARY]
GO
