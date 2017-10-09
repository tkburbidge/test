CREATE TABLE [dbo].[SpecialClaim]
(
[SpecialClaimID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Type] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [int] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Date] [datetime] NOT NULL,
[ClaimID] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateApproved] [datetime] NULL,
[ApprovedByPersonID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AffordableProgramAllocationID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SpecialClaim] ADD CONSTRAINT [PK_SpecialClaim] PRIMARY KEY CLUSTERED  ([SpecialClaimID], [AccountID]) ON [PRIMARY]
GO
