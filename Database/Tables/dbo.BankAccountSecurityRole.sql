CREATE TABLE [dbo].[BankAccountSecurityRole]
(
[BankAccountSecurityRoleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BankAccountID] [uniqueidentifier] NOT NULL,
[SecurityRoleID] [uniqueidentifier] NOT NULL,
[HasAccess] [bit] NOT NULL,
[SignedCheckThreshold] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankAccountSecurityRole] ADD CONSTRAINT [PK_BankAccountSecurityRole] PRIMARY KEY CLUSTERED  ([BankAccountSecurityRoleID], [AccountID]) ON [PRIMARY]
GO
