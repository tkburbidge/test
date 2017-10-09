CREATE TABLE [dbo].[CertificationMessage]
(
[CertificationMessageID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationRuleID] [int] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationMessage] ADD CONSTRAINT [PK_CertificationMessage] PRIMARY KEY CLUSTERED  ([CertificationMessageID], [AccountID]) ON [PRIMARY]
GO
