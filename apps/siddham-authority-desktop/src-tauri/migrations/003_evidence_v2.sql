alter table audit_event add column assurance text not null default 'AAL2';
alter table audit_event add column decision_reasons text not null default '[]';
alter table audit_event add column policy_digest text not null default '';
alter table audit_event add column schema_version integer not null default 1;
