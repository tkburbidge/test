CREATE TABLE [dbo].[Automobile]
(
[AutomobileID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[LicensePlateNumber] [nvarchar] (12) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LicensePlateState] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Make] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Model] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Color] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PermitNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Automobile] ADD CONSTRAINT [PK_Automobile] PRIMARY KEY CLUSTERED  ([AutomobileID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Automobile] WITH NOCHECK ADD CONSTRAINT [FK_Automobile_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[Automobile] NOCHECK CONSTRAINT [FK_Automobile_Person]
GO
