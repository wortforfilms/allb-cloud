create table governed_object(
  id text primary key,
  workspace_id text not null references workspace(id),
  kind text not null check(kind in ('dataset','model','agent','policy','release','evidence')),
  status text not null,
  content_digest text not null,
  metadata text not null,
  updated_at text not null
);

create table execution_control(
  request_id text primary key references authority_request(request_id),
  cancelled_at text,
  deadline_at text not null,
  max_input_bytes integer not null,
  created_at text not null
);

create table handler_execution(
  operation_id text primary key,
  request_id text unique not null references authority_request(request_id),
  handler_id text not null,
  target text not null,
  status text not null check(status in ('started','succeeded','failed','cancelled','timed_out')),
  started_at text not null,
  completed_at text,
  error text
);

