CREATE TABLE [dbo].[SurveyAnswer]
(
[SurveyAnswerID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SurveyResponseID] [uniqueidentifier] NOT NULL,
[PossibleSurveyAnswerID] [uniqueidentifier] NOT NULL,
[AnswerText] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SurveyAnswer] ADD CONSTRAINT [PK_SurveyAnswer] PRIMARY KEY CLUSTERED  ([SurveyAnswerID], [AccountID]) ON [PRIMARY]
GO
