CREATE TABLE [dbo].[Pet]
(
[PetID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Breed] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Color] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Weight] [int] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RegistrationType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RegistrationNumber] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RegistrationIssuedBy] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ProofOfVaccinations] [bit] NOT NULL,
[ValidationOfDogBreed] [bit] NOT NULL,
[Age] [int] NULL,
[VaccinationExpirationDate] [date] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Pet] ADD CONSTRAINT [PK_Pet] PRIMARY KEY CLUSTERED  ([PetID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Pet] WITH NOCHECK ADD CONSTRAINT [FK_Pet_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[Pet] NOCHECK CONSTRAINT [FK_Pet_Person]
GO
