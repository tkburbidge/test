CREATE TABLE [dbo].[TaskTemplateSecurityRole]
(
[TaskTemplateSecurityRoleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TaskTemplateID] [uniqueidentifier] NOT NULL,
[SecurityRoleID] [uniqueidentifier] NOT NULL,
[IsCarbonCopy] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaskTemplateSecurityRole] ADD CONSTRAINT [PK_TaskTemplateSecurityRole] PRIMARY KEY CLUSTERED  ([TaskTemplateSecurityRoleID], [AccountID]) ON [PRIMARY]
GO
