CREATE TABLE [dbo].[css_monitor_dmv_runs]
(
[runtime] [datetime] NOT NULL,
[session_id] [smallint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[css_monitor_dmv_runs] ADD CONSTRAINT [PK_css_monitor_dmv_runs] PRIMARY KEY CLUSTERED  ([runtime]) ON [PRIMARY]
GO
