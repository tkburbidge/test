CREATE TYPE [dbo].[RolePermissionCollection] AS TABLE
(
[RolePermissionID] [uniqueidentifier] NULL,
[AccountID] [bigint] NULL,
[SecurityRoleID] [uniqueidentifier] NULL,
[PermissionID] [int] NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
