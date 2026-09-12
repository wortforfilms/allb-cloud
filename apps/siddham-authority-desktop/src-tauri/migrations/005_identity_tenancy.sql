create table organization(
  id text primary key,
  display_name text not null,
  status text not null check(status in ('active','suspended')),
  created_at text not null
);

create table principal(
  id text primary key,
  kind text not null check(kind in ('human','service','agent')),
  display_name text not null,
  status text not null check(status in ('active','suspended','revoked')),
  created_at text not null,
  revoked_at text
);

create table device(
  id text primary key,
  principal_id text not null references principal(id),
  display_name text not null,
  public_key_digest text not null,
  status text not null check(status in ('active','revoked','recovering')),
  recovery_generation integer not null default 0,
  enrolled_at text not null,
  revoked_at text
);

create table workspace(
  id text primary key,
  organization_id text not null references organization(id),
  display_name text not null,
  status text not null check(status in ('active','suspended')),
  created_at text not null
);

create table workspace_membership(
  workspace_id text not null references workspace(id),
  principal_id text not null references principal(id),
  role text not null,
  status text not null check(status in ('active','suspended','revoked')),
  created_at text not null,
  primary key(workspace_id,principal_id)
);

create table authority_session(
  id text primary key,
  principal_id text not null references principal(id),
  device_id text not null references device(id),
  assurance text not null check(assurance in ('AAL2','AAL3','mTLS','Scoped capability')),
  recovery_generation integer not null,
  issued_at text not null,
  expires_at text not null,
  revoked_at text
);

create table federation_provider(
  id text primary key,
  organization_id text not null references organization(id),
  protocol text not null check(protocol in ('oidc','saml')),
  issuer text not null,
  metadata_digest text not null,
  status text not null check(status in ('configured','active','disabled')),
  created_at text not null
);

create index authority_session_principal on authority_session(principal_id);
create index membership_principal on workspace_membership(principal_id);

