create table sync_outbox(
  seq integer primary key autoincrement,
  event_id text unique not null references audit_event(id),
  payload text not null,
  attempts integer not null default 0,
  last_error text,
  acknowledged_at text,
  created_at text not null
);
