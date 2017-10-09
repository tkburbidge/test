CREATE TABLE [dbo].[AffordablePerson]
(
[AffordablePersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[SSNException] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DisabledHearing] [bit] NOT NULL,
[DisabledMobility] [bit] NOT NULL,
[DisabledVisual] [bit] NOT NULL,
[PoliceOrSecurity] [bit] NOT NULL,
[Veteran] [bit] NOT NULL,
[Citizenship] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ChildCare] [bit] NOT NULL,
[DisabilityAssistance] [bit] NOT NULL,
[OriginalHouseholdMember] [bit] NOT NULL,
[Ethnicity] [int] NULL,
[Race] [int] NULL,
[Gender] [nvarchar] (7) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FullTimeStudent] [bit] NULL,
[Elderly] [bit] NULL,
[DisabledRefused] [bit] NOT NULL,
[DateVerified] [datetime] NULL,
[VerifiedByPersonID] [uniqueidentifier] NULL,
[DisabledMental] [bit] NOT NULL,
[Disabled] [bit] NOT NULL,
[Frail] [bit] NOT NULL,
[WaitListLotteryID] [uniqueidentifier] NULL,
[AlienRegistration] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AlienRegistrationDisplay] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MarriedStatus] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordablePerson] ADD CONSTRAINT [PK_AffordablePerson] PRIMARY KEY CLUSTERED  ([AffordablePersonID], [AccountID]) ON [PRIMARY]
GO
