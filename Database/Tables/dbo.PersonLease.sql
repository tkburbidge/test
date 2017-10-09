CREATE TABLE [dbo].[PersonLease]
(
[PersonLeaseID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[LeaseID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ApprovalStatus] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ResidencyStatus] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HouseholdStatus] [nvarchar] (35) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MoveInDate] [date] NOT NULL,
[MoveOutDate] [date] NULL,
[ApplicationDate] [date] NOT NULL,
[NoticeGivenDate] [date] NULL,
[LeaseSignedDate] [date] NULL,
[ReasonForLeaving] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MoveOutNotes] [nvarchar] (300) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MainContact] [bit] NOT NULL,
[OrderBy] [tinyint] NOT NULL,
[ApplicantTypeID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonLease] ADD CONSTRAINT [PK_PersonUnitContract_1] PRIMARY KEY CLUSTERED  ([PersonLeaseID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonLease_ApplicationDate] ON [dbo].[PersonLease] ([ApplicationDate]) INCLUDE ([LeaseID], [MoveInDate]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonLease_LeaseID] ON [dbo].[PersonLease] ([LeaseID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonLease_PersonID] ON [dbo].[PersonLease] ([PersonID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonLease] WITH NOCHECK ADD CONSTRAINT [FK_PersonUnitContract_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[PersonLease] WITH NOCHECK ADD CONSTRAINT [FK_PersonUnitContract_UnitContract] FOREIGN KEY ([LeaseID], [AccountID]) REFERENCES [dbo].[Lease] ([LeaseID], [AccountID])
GO
ALTER TABLE [dbo].[PersonLease] NOCHECK CONSTRAINT [FK_PersonUnitContract_Person]
GO
ALTER TABLE [dbo].[PersonLease] NOCHECK CONSTRAINT [FK_PersonUnitContract_UnitContract]
GO
