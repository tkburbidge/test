CREATE TABLE [dbo].[AffordableHousehold]
(
[AffordableHouseholdID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HouseholdIncome] [money] NULL,
[DeathDate] [datetime] NULL,
[DisplacedReason] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[UnbornChildren] [int] NOT NULL,
[ExpectedAdoptions] [int] NOT NULL,
[ExpectedFosterChildren] [int] NOT NULL,
[PreviousHousing] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FullTimeStudentException] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NeedsAccessibleUnit] [bit] NOT NULL,
[HouseholdType] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PlacedInService] [bit] NOT NULL,
[TRACSTenantID] [nchar] (9) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CreatedDate] [datetime] NULL,
[CreatedBy] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HHCitizenshipEligibility] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableHousehold] ADD CONSTRAINT [PK_AffordableHousehold] PRIMARY KEY CLUSTERED  ([AffordableHouseholdID]) ON [PRIMARY]
GO
