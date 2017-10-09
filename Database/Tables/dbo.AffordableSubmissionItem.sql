CREATE TABLE [dbo].[AffordableSubmissionItem]
(
[AffordableSubmissionItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AffordableSubmissionID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[TransactionType] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsBaseline] [bit] NOT NULL,
[HeadOfHouseholdFirstName] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HeadOfHouseholdMiddleName] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HeadOfHouseholdLastName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HeadOfHouseholdBirthdate] [date] NULL,
[HeadOfHouseholdSSN] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PaidAmount] [int] NULL,
[UnitNumber] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ChangeCode] [nvarchar] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableSubmissionItem] ADD CONSTRAINT [PK_AffordableSubmissionItem] PRIMARY KEY CLUSTERED  ([AffordableSubmissionItemID], [AccountID]) ON [PRIMARY]
GO
