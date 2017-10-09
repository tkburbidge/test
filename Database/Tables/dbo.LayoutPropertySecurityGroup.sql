CREATE TABLE [dbo].[LayoutPropertySecurityGroup]
(
[LayoutPropertySecurityGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LayoutID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[SecurityGroupID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LayoutPropertySecurityGroup] ADD CONSTRAINT [PK_LayoutPropertySecurityGroup] PRIMARY KEY CLUSTERED  ([LayoutPropertySecurityGroupID], [AccountID]) ON [PRIMARY]
GO
