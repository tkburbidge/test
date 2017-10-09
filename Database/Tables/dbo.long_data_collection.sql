CREATE TABLE [dbo].[long_data_collection]
(
[runtime] [datetime] NOT NULL,
[time_ms] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[long_data_collection] ADD CONSTRAINT [PK_long_data_collection] PRIMARY KEY CLUSTERED  ([runtime]) ON [PRIMARY]
GO
