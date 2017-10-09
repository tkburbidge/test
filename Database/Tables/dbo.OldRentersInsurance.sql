CREATE TABLE [dbo].[OldRentersInsurance]
(
[AccountID] [bigint] NOT NULL,
[LeaseID] [uniqueidentifier] NOT NULL,
[RentersInsuranceType] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Provider] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PolicyNumber] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactPhoneNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactEmail] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartDate] [date] NULL,
[ExpirationDate] [date] NULL,
[Coverage] [money] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[OldRentersInsurance] ADD CONSTRAINT [PK_OldRentersInsurance_1] PRIMARY KEY CLUSTERED  ([LeaseID], [AccountID]) ON [PRIMARY]
GO
