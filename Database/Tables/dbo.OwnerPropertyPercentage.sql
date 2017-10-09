CREATE TABLE [dbo].[OwnerPropertyPercentage]
(
[OwnerPropertyPercentageID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[OwnerPropertyID] [uniqueidentifier] NOT NULL,
[OwnerPropertyPercentageGroupID] [uniqueidentifier] NOT NULL,
[Percentage] [decimal] (13, 10) NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[OwnerPropertyPercentage] ADD CONSTRAINT [PK_OwnerPropertyPercentage] PRIMARY KEY CLUSTERED  ([OwnerPropertyPercentageID], [AccountID]) ON [PRIMARY]
GO
