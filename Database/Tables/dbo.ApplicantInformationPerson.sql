CREATE TABLE [dbo].[ApplicantInformationPerson]
(
[AccountID] [bigint] NOT NULL,
[ApplicantInformationPersonID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ApplicantInformationID] [uniqueidentifier] NOT NULL,
[ApplicantType] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FeesAssessed] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicantInformationPerson] ADD CONSTRAINT [PK_ApplicantInformationPerson] PRIMARY KEY CLUSTERED  ([ApplicantInformationPersonID], [AccountID]) ON [PRIMARY]
GO
