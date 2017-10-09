CREATE TABLE [dbo].[Utility]
(
[UtilityID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[AccountNumber] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[UtilityType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ServiceProviderID] [uniqueidentifier] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[UtilityProviderID] [uniqueidentifier] NULL,
[StartDate] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Utility] ADD CONSTRAINT [PK_Utility] PRIMARY KEY CLUSTERED  ([UtilityID], [AccountID]) ON [PRIMARY]
GO
