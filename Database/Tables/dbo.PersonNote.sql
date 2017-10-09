CREATE TABLE [dbo].[PersonNote]
(
[PersonNoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[CreatedByPersonTypePropertyID] [uniqueidentifier] NULL,
[AlertTaskID] [uniqueidentifier] NULL,
[Date] [date] NOT NULL,
[Location] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Note] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[InteractionType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NOT NULL CONSTRAINT [DF_PersonNote_DateCreated] DEFAULT (getutcdate()),
[PersonType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF__tmp_ms_xx__Perso__7E188EBC] DEFAULT (''),
[ObjectID] [uniqueidentifier] NULL,
[NoteRead] [bit] NOT NULL,
[MITSEventType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NULL,
[ClosedDate] [datetime] NULL,
[RepliedToPersonNoteID] [uniqueidentifier] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonNote] ADD CONSTRAINT [PK_PersonNote] PRIMARY KEY CLUSTERED  ([PersonNoteID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonNote_Date] ON [dbo].[PersonNote] ([Date]) INCLUDE ([ContactType], [CreatedByPersonID], [DateCreated], [InteractionType], [PersonID], [PersonType], [PropertyID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonNote_DateCreated] ON [dbo].[PersonNote] ([DateCreated]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonNote_InteractionObjectID] ON [dbo].[PersonNote] ([InteractionType], [ObjectID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonNote_PersonID] ON [dbo].[PersonNote] ([PersonID]) INCLUDE ([InteractionType], [PropertyID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonNote] WITH NOCHECK ADD CONSTRAINT [FK_PersonNote_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[PersonNote] NOCHECK CONSTRAINT [FK_PersonNote_Person]
GO
