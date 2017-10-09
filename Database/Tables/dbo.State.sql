CREATE TABLE [dbo].[State]
(
[CountryID] [int] NOT NULL,
[Abbreviation] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[State] ADD CONSTRAINT [PK_State] PRIMARY KEY CLUSTERED  ([CountryID], [Abbreviation]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[State] WITH NOCHECK ADD CONSTRAINT [FK_State_Country] FOREIGN KEY ([CountryID]) REFERENCES [dbo].[Country] ([CountryID])
GO
ALTER TABLE [dbo].[State] NOCHECK CONSTRAINT [FK_State_Country]
GO
