CREATE TABLE [dbo].[Ordering]
(
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Value] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Ordering] ADD CONSTRAINT [PK_Ordering] PRIMARY KEY CLUSTERED  ([Type], [Value]) ON [PRIMARY]
GO
