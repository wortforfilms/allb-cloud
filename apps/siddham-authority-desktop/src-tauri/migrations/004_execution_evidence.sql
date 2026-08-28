alter table audit_event add column request_id text not null default '';
create index audit_event_request_id on audit_event(request_id);

create table execution_event(
  seq integer primary key autoincrement,
  id text unique not null,
  authorization_event_id text not null references audit_event(id),
  request_id text not null,
  operation_id text unique not null,
  status text not null,
  execution_mode text not null,
  input_digest text not null,
  output_digest text not null,
  event_hash text unique not null,
  created_at text not null
);
create trigger execution_no_update before update on execution_event begin select raise(abort,'execution events are immutable'); end;
create trigger execution_no_delete before delete on execution_event begin select raise(abort,'execution events are immutable'); end;

create table execution_outbox(
  seq integer primary key autoincrement,
  event_id text unique not null references execution_event(id),
  payload text not null,
  attempts integer not null default 0,
  last_error text,
  acknowledged_at text,
  created_at text not null
);
