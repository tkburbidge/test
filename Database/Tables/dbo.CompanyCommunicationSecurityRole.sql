CREATE TABLE [dbo].[CompanyCommunicationSecurityRole]
(
[CompanyCommunicationSecurityRoleID] [uniqueidentifier] NOT NULL,
[CompanyCommunicationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SecurityRoleID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CompanyCommunicationSecurityRole] ADD CONSTRAINT [PK_CompanyCommunicationSecurityRole_1] PRIMARY KEY CLUSTERED  ([CompanyCommunicationSecurityRoleID], [AccountID]) ON [PRIMARY]
GO
