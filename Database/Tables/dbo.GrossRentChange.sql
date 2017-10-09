CREATE TABLE [dbo].[GrossRentChange]
(
[GrossRentChangeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NULL,
[EffectiveDate] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[GrossRentChange] ADD CONSTRAINT [PK_GrossRentChange] PRIMARY KEY CLUSTERED  ([GrossRentChangeID], [AccountID]) ON [PRIMARY]
GO
