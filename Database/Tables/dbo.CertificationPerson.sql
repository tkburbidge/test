CREATE TABLE [dbo].[CertificationPerson]
(
[CertificationPersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL,
[HouseholdStatus] [nvarchar] (35) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FullTimeStudent] [bit] NOT NULL,
[Disabled] [bit] NOT NULL,
[Elderly] [bit] NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Frail] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationPerson] ADD CONSTRAINT [PK_CertificationPerson] PRIMARY KEY CLUSTERED  ([CertificationPersonID], [AccountID]) ON [PRIMARY]
GO
