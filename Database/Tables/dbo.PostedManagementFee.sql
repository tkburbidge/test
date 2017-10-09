CREATE TABLE [dbo].[PostedManagementFee]
(
[PostedManagementFeeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ManagementFeeID] [uniqueidentifier] NOT NULL,
[PostedManagementFeesID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PostedManagementFee] ADD CONSTRAINT [PK_PostedManagementFee] PRIMARY KEY CLUSTERED  ([PostedManagementFeeID], [AccountID]) ON [PRIMARY]
GO
