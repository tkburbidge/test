CREATE TABLE [dbo].[PropertyProspectSource]
(
[PropertyProspectSourceID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[ProspectSourceID] [uniqueidentifier] NOT NULL,
[CostPerYear] [money] NOT NULL,
[ExpirationDate] [date] NULL,
[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyProspectSource] ADD CONSTRAINT [PK_PropertyProspectSource] PRIMARY KEY CLUSTERED  ([PropertyProspectSourceID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyProspectSource] WITH NOCHECK ADD CONSTRAINT [FK_PropertyProspectSource_ProspectSource] FOREIGN KEY ([ProspectSourceID], [AccountID]) REFERENCES [dbo].[ProspectSource] ([ProspectSourceID], [AccountID])
GO
ALTER TABLE [dbo].[PropertyProspectSource] NOCHECK CONSTRAINT [FK_PropertyProspectSource_ProspectSource]
GO
