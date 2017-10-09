CREATE TABLE [dbo].[AffordableSubmissionUnit]
(
[AffordableSubmissionUnitID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL,
[TransactionType] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldUnitNumber] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewUnitNumber] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldFirstAddressLine] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewFirstAddressLine] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldCity] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewCity] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldState] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewState] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewZip] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldZip] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewMobilityAccess] [bit] NULL,
[OldMobilityAccess] [bit] NULL,
[NewHearingAccess] [bit] NULL,
[OldHearingAccess] [bit] NULL,
[NewVisualAccess] [bit] NULL,
[OldVisualAccess] [bit] NULL,
[NewUnitStatus] [nvarchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldUnitStatus] [nvarchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewNumberOfBedrooms] [int] NULL,
[OldNumberOfBedrooms] [int] NULL,
[NewBIN] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OldBIN] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewSquareFootage] [int] NULL,
[OldSquareFootage] [int] NULL,
[OldAffordableProgramAllocationID] [uniqueidentifier] NULL,
[NewAffordableProgramAllocation] [uniqueidentifier] NULL,
[NewAffordableProgramAllocationID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableSubmissionUnit] ADD CONSTRAINT [PK_AffordableSubmissionUnit] PRIMARY KEY CLUSTERED  ([AffordableSubmissionUnitID], [AccountID]) ON [PRIMARY]
GO
