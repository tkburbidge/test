CREATE TABLE [dbo].[Prospect]
(
[ProspectID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ResponsiblePersonTypePropertyID] [uniqueidentifier] NULL,
[PropertyProspectSourceID] [uniqueidentifier] NOT NULL,
[MovingFrom] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateNeeded] [date] NULL,
[Building] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Floor] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MaxRent] [int] NULL,
[OtherPreferences] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LostReasonPickListItemID] [uniqueidentifier] NULL,
[LostReasonNotes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LostDate] [date] NULL,
[DesiredBedroomsMin] [int] NULL,
[DesiredBedroomsMax] [int] NULL,
[DesiredBathroomsMin] [int] NULL,
[DesiredBathroomsMax] [int] NULL,
[OnlineApplicationSent] [bit] NOT NULL,
[LastModified] [datetime] NULL,
[FirstPersonNoteID] [uniqueidentifier] NULL,
[LastPersonNoteID] [uniqueidentifier] NULL,
[NextAlertTaskID] [uniqueidentifier] NULL,
[Occupants] [int] NULL,
[ReasonForMovingPickListItemID] [uniqueidentifier] NULL,
[Unqualified] [bit] NULL,
[IsExcludedFromCampaign] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Prospect] ADD CONSTRAINT [PK_Traffic] PRIMARY KEY CLUSTERED  ([ProspectID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Prospect_PersonID] ON [dbo].[Prospect] ([PersonID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Prospect] WITH NOCHECK ADD CONSTRAINT [FK_Prospect_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[Prospect] WITH NOCHECK ADD CONSTRAINT [FK_Prospect_PersonTypeProperty] FOREIGN KEY ([ResponsiblePersonTypePropertyID], [AccountID]) REFERENCES [dbo].[PersonTypeProperty] ([PersonTypePropertyID], [AccountID])
GO
ALTER TABLE [dbo].[Prospect] WITH NOCHECK ADD CONSTRAINT [FK_Prospect_PropertyProspectSource] FOREIGN KEY ([PropertyProspectSourceID], [AccountID]) REFERENCES [dbo].[PropertyProspectSource] ([PropertyProspectSourceID], [AccountID])
GO
ALTER TABLE [dbo].[Prospect] NOCHECK CONSTRAINT [FK_Prospect_Person]
GO
ALTER TABLE [dbo].[Prospect] NOCHECK CONSTRAINT [FK_Prospect_PersonTypeProperty]
GO
ALTER TABLE [dbo].[Prospect] NOCHECK CONSTRAINT [FK_Prospect_PropertyProspectSource]
GO
