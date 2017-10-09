CREATE TABLE [dbo].[FormLetterMergeField]
(
[MergeField] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Category] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF__FormLette__Categ__4870AB22] DEFAULT ('Other')
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[FormLetterMergeField] ADD CONSTRAINT [pk_FormLetterMergeField] PRIMARY KEY CLUSTERED  ([MergeField], [Type]) ON [PRIMARY]
GO
