CREATE TABLE [dbo].[ApplicantScreeningPerson]
(
[ApplicantScreeningPersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ApplicantScreeningID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ApplicantType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GuarantorFor] [uniqueidentifier] NULL,
[SpouseOf] [uniqueidentifier] NULL,
[CurrentRent] [money] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicantScreeningPerson] ADD CONSTRAINT [PK_ApplicationScreeningPerson] PRIMARY KEY CLUSTERED  ([ApplicantScreeningPersonID], [AccountID]) ON [PRIMARY]
GO
