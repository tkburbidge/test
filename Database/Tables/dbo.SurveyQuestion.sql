CREATE TABLE [dbo].[SurveyQuestion]
(
[SurveyQuestionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SurveyID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Question] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HelpText] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OrderBy] [int] NOT NULL,
[Required] [bit] NOT NULL,
[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SurveyQuestion] ADD CONSTRAINT [PK_ServeyQuestion] PRIMARY KEY CLUSTERED  ([SurveyQuestionID], [AccountID]) ON [PRIMARY]
GO
