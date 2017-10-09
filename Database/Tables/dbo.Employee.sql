CREATE TABLE [dbo].[Employee]
(
[PersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[EmergencyContactPersonID] [uniqueidentifier] NULL,
[Title] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[WageType] [nvarchar] (6) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HireDate] [date] NULL,
[QuitDate] [date] NULL,
[BenefitsEligibleDate] [date] NULL,
[RetirementEligibleDate] [date] NULL,
[EnrollmentDate] [date] NULL,
[LivesOnSite] [bit] NOT NULL,
[AlertViaEmail] [bit] NOT NULL,
[ReasonForLeaving] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FingerPrintTemplate] [varbinary] (max) NULL,
[Number] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ShowInResidentPortal] [bit] NOT NULL,
[EmployeeBio] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ResidentPortalGroup] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[Employee] ADD CONSTRAINT [PK_Employee_1] PRIMARY KEY CLUSTERED  ([PersonID], [AccountID]) ON [PRIMARY]
GO
