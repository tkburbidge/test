CREATE TABLE [dbo].[ManagementFee]
(
[ManagementFeeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[VendorID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ManagementFee] ADD CONSTRAINT [PK_ManagementFee] PRIMARY KEY CLUSTERED  ([ManagementFeeID], [AccountID]) ON [PRIMARY]
GO
