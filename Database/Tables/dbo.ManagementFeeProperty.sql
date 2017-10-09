CREATE TABLE [dbo].[ManagementFeeProperty]
(
[ManagementFeePropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ManagementFeeID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ManagementFeeProperty] ADD CONSTRAINT [PK_ManagementFeeProperty] PRIMARY KEY CLUSTERED  ([ManagementFeePropertyID], [AccountID]) ON [PRIMARY]
GO
