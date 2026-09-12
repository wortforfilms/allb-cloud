create table approval_request(
  id text primary key,
  request_id text unique not null references authority_request(request_id),
  request_hash text not null,
  workspace_id text not null references workspace(id),
  action text not null,
  resource text not null,
  requested_by text not null references principal(id),
  status text not null check(status in ('pending','approved','rejected','expired','cancelled','consumed')),
  required_quorum integer not null check(required_quorum > 0),
  expires_at text not null,
  created_at text not null,
  decided_at text,
  cancelled_at text
);

create table approval_vote(
  id text primary key,
  approval_id text not null references approval_request(id),
  approver text not null references principal(id),
  decision text not null check(decision in ('approve','reject')),
  comment text not null,
  created_at text not null,
  unique(approval_id,approver)
);

create table approval_consumption(
  approval_id text primary key references approval_request(id),
  request_id text unique not null references authority_request(request_id),
  request_hash text not null,
  consumed_at text not null
);

create table authority_delegation(
  id text primary key,
  grantor text not null references principal(id),
  delegate text not null references principal(id),
  workspace_id text not null references workspace(id),
  action text not null,
  status text not null check(status in ('active','revoked','expired')),
  expires_at text not null,
  created_at text not null,
  revoked_at text
);

create table emergency_access(
  id text primary key,
  principal_id text not null references principal(id),
  workspace_id text not null references workspace(id),
  action text not null,
  justification text not null,
  status text not null check(status in ('pending','approved','rejected','revoked','expired')),
  reviewed_by text references principal(id),
  expires_at text not null,
  created_at text not null,
  reviewed_at text,
  revoked_at text
);

create table approval_lifecycle_event(
  seq integer primary key autoincrement,
  id text unique not null,
  subject_id text not null,
  subject_kind text not null check(subject_kind in ('approval','delegation','emergency')),
  action text not null,
  actor text not null references principal(id),
  details text not null,
  created_at text not null
);
create trigger approval_event_no_update before update on approval_lifecycle_event begin select raise(abort,'approval lifecycle events are immutable'); end;
create trigger approval_event_no_delete before delete on approval_lifecycle_event begin select raise(abort,'approval lifecycle events are immutable'); end;
create trigger approval_vote_no_update before update on approval_vote begin select raise(abort,'approval votes are immutable'); end;
create trigger approval_vote_no_delete before delete on approval_vote begin select raise(abort,'approval votes are immutable'); end;
create trigger approval_consumption_no_update before update on approval_consumption begin select raise(abort,'approval consumption is immutable'); end;
create trigger approval_consumption_no_delete before delete on approval_consumption begin select raise(abort,'approval consumption is immutable'); end;

