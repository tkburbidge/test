CREATE TABLE [dbo].[SurveyResponse]
(
[SurveyResponseID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SurveyID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NULL,
[DateTimeStarted] [datetime] NOT NULL,
[DateTimeEnded] [datetime] NULL,
[LeaseID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SurveyResponse] ADD CONSTRAINT [PK_SurveyResponse] PRIMARY KEY CLUSTERED  ([SurveyResponseID], [AccountID]) ON [PRIMARY]
GO
