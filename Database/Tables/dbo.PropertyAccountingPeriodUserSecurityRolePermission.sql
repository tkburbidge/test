CREATE TABLE [dbo].[PropertyAccountingPeriodUserSecurityRolePermission]
(
[PropertyAccountingPeriodUserSecurityRolePermissionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UserOrPermissionGroupID] [uniqueidentifier] NOT NULL,
[PropertyAccountingPeriodID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyAccountingPeriodUserSecurityRolePermission] ADD CONSTRAINT [PK_PropertyAccountingPeriodUserSecurityRolePermission] PRIMARY KEY CLUSTERED  ([AccountID], [PropertyAccountingPeriodUserSecurityRolePermissionID]) ON [PRIMARY]
GO
