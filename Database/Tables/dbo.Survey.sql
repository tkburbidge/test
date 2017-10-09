CREATE TABLE [dbo].[Survey]
(
[SurveyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Instructions] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[StartDate] [date] NULL,
[EndDate] [date] NULL,
[IsDeleted] [bit] NOT NULL,
[LimitationType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Published] [bit] NOT NULL,
[IsSystem] [bit] NOT NULL,
[SystemType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Survey] ADD CONSTRAINT [PK_Survey] PRIMARY KEY CLUSTERED  ([SurveyID], [AccountID]) ON [PRIMARY]
GO
