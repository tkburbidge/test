CREATE TABLE [dbo].[MessageDetail]
(
[AccountID] [bigint] NOT NULL,
[Date] [date] NULL,
[MessageDetailID] [uniqueidentifier] NOT NULL,
[MessageID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[MessageDetail] ADD CONSTRAINT [PK_MessageDetail] PRIMARY KEY CLUSTERED  ([AccountID], [MessageDetailID]) ON [PRIMARY]
GO
