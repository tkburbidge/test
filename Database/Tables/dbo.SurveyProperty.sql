CREATE TABLE [dbo].[SurveyProperty]
(
[AccountID] [bigint] NOT NULL,
[SurveyID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SurveyProperty] ADD CONSTRAINT [PK_SurveyProperty] PRIMARY KEY CLUSTERED  ([AccountID], [SurveyID], [PropertyID]) ON [PRIMARY]
GO
