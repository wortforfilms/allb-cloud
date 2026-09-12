create table policy_bundle(
  id text primary key,
  version text unique not null,
  document text not null,
  digest text not null,
  state text not null check(state in ('draft','active','retired')),
  created_by text not null references principal(id),
  created_at text not null,
  activated_at text,
  retired_at text
);

create table policy_lifecycle_event(
  seq integer primary key autoincrement,
  id text unique not null,
  policy_id text not null references policy_bundle(id),
  action text not null check(action in ('create','simulate','activate','retire')),
  actor text not null references principal(id),
  details text not null,
  created_at text not null
);
create trigger policy_event_no_update before update on policy_lifecycle_event begin select raise(abort,'policy lifecycle events are immutable'); end;
create trigger policy_event_no_delete before delete on policy_lifecycle_event begin select raise(abort,'policy lifecycle events are immutable'); end;

create table authority_request(
  request_id text primary key,
  session_id text not null references authority_session(id),
  request_hash text not null,
  operation_id text unique,
  created_at text not null,
  expires_at text not null
);
create trigger authority_request_no_update before update of request_id,session_id,request_hash,created_at,expires_at on authority_request begin select raise(abort,'authority request identity is immutable'); end;
create trigger authority_request_no_delete before delete on authority_request begin select raise(abort,'authority request claims are retained'); end;

