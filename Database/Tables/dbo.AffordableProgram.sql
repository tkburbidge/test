CREATE TABLE [dbo].[AffordableProgram]
(
[AffordableProgramID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StateID] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsFloatingUnits] [bit] NOT NULL CONSTRAINT [DF__Affordabl__IsFlo__0C7BBCAC] DEFAULT ((0)),
[ProjectNumber] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OwnerDUNS] [int] NULL,
[OwnerTIN] [int] NULL,
[ParentCompanyDUNS] [int] NULL,
[ParentCompanyTIN] [int] NULL,
[DoesNotRequireRecertification] [bit] NOT NULL,
[IsHUD] [bit] NOT NULL,
[FirstYearRecertificationOnly] [bit] NOT NULL,
[IncomeAffordableProgramTableGroupID] [uniqueidentifier] NULL,
[EndDate] [date] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableProgram] ADD CONSTRAINT [PK__Affordab__DAD07044D128746F] PRIMARY KEY CLUSTERED  ([AffordableProgramID], [AccountID]) ON [PRIMARY]
GO
