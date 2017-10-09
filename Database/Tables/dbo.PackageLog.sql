CREATE TABLE [dbo].[PackageLog]
(
[PackageLogID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DateReceived] [datetime] NOT NULL,
[ReceivingPersonID] [uniqueidentifier] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL,
[Courier] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Sender] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RecipientPersonID] [uniqueidentifier] NOT NULL,
[Notes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AlternatePickup] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DatePickedUp] [datetime] NULL,
[PickedUpBy] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PackageLog] ADD CONSTRAINT [PK_PackageLog] PRIMARY KEY CLUSTERED  ([PackageLogID], [AccountID]) ON [PRIMARY]
GO
