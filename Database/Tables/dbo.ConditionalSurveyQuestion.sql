CREATE TABLE [dbo].[ConditionalSurveyQuestion]
(
[ConditionalSurveyQuestionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PossibleSurveyAnswerID] [uniqueidentifier] NOT NULL,
[SurveyQuestionID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ConditionalSurveyQuestion] ADD CONSTRAINT [PK_ConditionalSurveyQuestion] PRIMARY KEY CLUSTERED  ([ConditionalSurveyQuestionID], [AccountID]) ON [PRIMARY]
GO
