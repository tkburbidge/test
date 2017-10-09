CREATE TABLE [dbo].[ServiceProvider]
(
[ServiceProviderID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[UtilityType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PhoneNumber] [nvarchar] (35) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsDeleted] [bit] NOT NULL,
[IsSystem] [bit] NOT NULL CONSTRAINT [DF__UtilityPr__IsSys__0C90CB45] DEFAULT ((0)),
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ServiceProvider] ADD CONSTRAINT [PK_UtilityProvider] PRIMARY KEY CLUSTERED  ([ServiceProviderID], [AccountID], [PropertyID]) ON [PRIMARY]
GO
