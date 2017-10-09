CREATE TABLE [dbo].[dm_tran_active_transactions_saved]
(
[runtime] [datetime] NOT NULL,
[transaction_id] [bigint] NOT NULL,
[name] [nvarchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[transaction_begin_time] [datetime] NOT NULL,
[transaction_type] [int] NOT NULL,
[transaction_state] [int] NOT NULL,
[transaction_status] [int] NOT NULL,
[transaction_status2] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dm_tran_active_transactions_saved] ADD CONSTRAINT [dm_tran_active_transactions_saved_pk] PRIMARY KEY CLUSTERED  ([transaction_id], [runtime]) ON [PRIMARY]
GO
