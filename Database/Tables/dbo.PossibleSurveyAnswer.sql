CREATE TABLE [dbo].[PossibleSurveyAnswer]
(
[PossibleSurveyAnswerID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SurveyQuestionID] [uniqueidentifier] NOT NULL,
[AnswerText] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [int] NOT NULL,
[IsOther] [bit] NOT NULL,
[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PossibleSurveyAnswer] ADD CONSTRAINT [PK_PossibleSurveyAnswer] PRIMARY KEY CLUSTERED  ([PossibleSurveyAnswerID], [AccountID]) ON [PRIMARY]
GO
