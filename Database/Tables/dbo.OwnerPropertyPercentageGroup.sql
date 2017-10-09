CREATE TABLE [dbo].[OwnerPropertyPercentageGroup]
(
[OwnerPropertyPercentageGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Notes] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[OwnerPropertyPercentageGroup] ADD CONSTRAINT [PK_OwnerPropertyPercentageGroup] PRIMARY KEY CLUSTERED  ([OwnerPropertyPercentageGroupID], [AccountID]) ON [PRIMARY]
GO
