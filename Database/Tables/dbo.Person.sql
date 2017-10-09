CREATE TABLE [dbo].[Person]
(
[PersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SpousePersonID] [uniqueidentifier] NULL,
[ParentPersonID] [uniqueidentifier] NULL,
[EmergencyPersonID] [uniqueidentifier] NULL,
[AlternatePersonType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Email] [nvarchar] (150) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Salutation] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FirstName] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MiddleName] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PreferredName] [nvarchar] (150) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Phone1] [nvarchar] (35) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Phone1Type] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Phone2] [nvarchar] (35) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Phone2Type] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Phone3] [nvarchar] (35) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Phone3Type] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DriversLicenseNumber] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DriversLicenseState] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SSN] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsTransactionable] [bit] NOT NULL,
[IsMale] [bit] NULL,
[Birthdate] [date] NULL,
[PrimaryLanguage] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Website] [nvarchar] (150) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FacebookUserID] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[USCitizen] [bit] NULL,
[LastModified] [datetime] NOT NULL,
[IDNumberType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PreferredContactMethod] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SSNDisplay] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Ethnicity] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ShortCode] [nvarchar] (4) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Person] ADD CONSTRAINT [PK_Person] PRIMARY KEY CLUSTERED  ([PersonID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Person_FirstName] ON [dbo].[Person] ([FirstName]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Person_LastName] ON [dbo].[Person] ([LastName]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Person_PreferredName] ON [dbo].[Person] ([PreferredName]) ON [PRIMARY]
GO
