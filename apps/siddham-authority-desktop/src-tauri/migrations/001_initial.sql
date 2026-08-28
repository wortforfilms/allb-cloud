create table audit_event(
  seq integer primary key autoincrement,
  id text unique not null,
  principal text not null,
  action text not null,
  resource text not null,
  workspace text not null,
  decision text not null,
  policy_version text not null,
  request_hash text not null,
  event_hash text unique not null,
  previous_event_hash text,
  created_at text not null
);
create trigger audit_no_update before update on audit_event begin select raise(abort,'audit events are immutable'); end;
create trigger audit_no_delete before delete on audit_event begin select raise(abort,'audit events are immutable'); end;
