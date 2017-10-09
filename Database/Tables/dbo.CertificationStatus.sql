CREATE TABLE [dbo].[CertificationStatus]
(
[CertificationStatusID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[DateCreated] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationStatus] ADD CONSTRAINT [PK_CertificationStatus] PRIMARY KEY CLUSTERED  ([CertificationStatusID], [AccountID]) ON [PRIMARY]
GO
