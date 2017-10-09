CREATE TABLE [dbo].[Lease]
(
[LeaseID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[PersonCreatedID] [uniqueidentifier] NOT NULL,
[LeaseStatus] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime] NULL,
[LeaseStartDate] [date] NOT NULL,
[LeaseEndDate] [date] NOT NULL,
[RentDueDay] [int] NOT NULL,
[LateFeeGracePeriod] [tinyint] NOT NULL,
[MaximumLateFee] [money] NOT NULL,
[InitialLateFee] [money] NOT NULL,
[AdditionalLateFeePerDay] [money] NOT NULL,
[AssessLateFees] [bit] NOT NULL,
[LeasingAgentPersonID] [uniqueidentifier] NULL,
[LateFeeScheduleID] [uniqueidentifier] NOT NULL,
[LeaseTermID] [uniqueidentifier] NULL,
[LeaseCreated] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Lease] ADD CONSTRAINT [PK_PersonUnitContract] PRIMARY KEY CLUSTERED  ([LeaseID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Lease_LeaseEndDate] ON [dbo].[Lease] ([LeaseEndDate]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Lease_LeaseStartDate] ON [dbo].[Lease] ([LeaseStartDate]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Lease_LeaseStatus] ON [dbo].[Lease] ([LeaseStatus]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Lease_UnitLeaseGroupID] ON [dbo].[Lease] ([UnitLeaseGroupID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Lease] WITH NOCHECK ADD CONSTRAINT [FK_Lease_UnitLeaseGroup] FOREIGN KEY ([UnitLeaseGroupID], [AccountID]) REFERENCES [dbo].[UnitLeaseGroup] ([UnitLeaseGroupID], [AccountID])
GO
ALTER TABLE [dbo].[Lease] NOCHECK CONSTRAINT [FK_Lease_UnitLeaseGroup]
GO
