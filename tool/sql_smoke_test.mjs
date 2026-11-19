// Runs every migration against an in-memory Postgres and checks the
// security model: tenant isolation, permissions, data scope, guards, RPCs.
// Usage: cd tool && npm install && npm test
import { PGlite } from '@electric-sql/pglite';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(here, '..', 'supabase', 'migrations');

const db = new PGlite();
let passed = 0;
let failed = 0;

function ok(name, cond, extra = '') {
  if (cond) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name} ${extra}`);
  }
}

async function q(sql, params = []) {
  const r = await db.query(sql, params);
  return r.rows;
}

async function as(userId, fn) {
  await db.exec(`select set_config('request.jwt.claim.sub', '${userId}', false); set role authenticated;`);
  try {
    return await fn();
  } finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
  }
}

async function fails(name, fn, pattern) {
  try {
    await fn();
    ok(name, false, '(expected an error but the call succeeded)');
  } catch (e) {
    const msg = String(e.message || e);
    ok(name, pattern ? pattern.test(msg) : true, `(got: ${msg})`);
  }
}

// ---------------------------------------------------------------- stubs
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
  grant usage on schema public to anon, authenticated;

  create schema auth;
  create table auth.users (
    id uuid primary key default gen_random_uuid(),
    email text,
    raw_user_meta_data jsonb not null default '{}'::jsonb
  );
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth to authenticated;
  grant execute on function auth.uid() to authenticated, anon;

  create schema storage;
  create table storage.buckets (id text primary key, name text, public boolean, file_size_limit bigint);
  create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql immutable as
    $$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
  grant usage on schema storage to authenticated;
  grant select, insert, update, delete on storage.objects to authenticated;
  grant execute on function storage.foldername(text) to authenticated;
`);

console.log('Applying migrations');
const files = readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
for (const f of files) {
  try {
    await db.exec(readFileSync(join(migrationsDir, f), 'utf8'));
    console.log(`  applied ${f}`);
  } catch (e) {
    console.log(`  FAILED  ${f}: ${e.message}`);
    process.exit(1);
  }
}

// ---------------------------------------------------------------- helpers
async function signUp(email, meta = {}) {
  const [u] = await q(
    `insert into auth.users (email, raw_user_meta_data) values ($1, $2::jsonb) returning id`,
    [email, JSON.stringify(meta)],
  );
  return u.id;
}
const orgMeta = (org, name) => ({ registration_type: 'organization', org_name: org, full_name: name });

// ---------------------------------------------------------------- 1. registration
console.log('\n1. Organization registration');
const ownerA = await signUp('owner@alpha.test', orgMeta('Alpha Ltd', 'Alice Owner'));
const ownerB = await signUp('owner@beta.test', orgMeta('Beta Ltd', 'Bob Owner'));
const [orgA] = await q(`select * from organizations where name = 'Alpha Ltd'`);
const [orgB] = await q(`select * from organizations where name = 'Beta Ltd'`);
ok('two organizations created', !!orgA && !!orgB);
ok('five default roles seeded', (await q(`select count(*)::int c from roles where organization_id = $1`, [orgA.id]))[0].c === 5);
ok('head office created', (await q(`select count(*)::int c from branches where organization_id = $1 and is_head_office`, [orgA.id]))[0].c === 1);
const [ownerEmp] = await q(`select * from employees where user_id = $1`, [ownerA]);
ok('owner employee row linked', ownerEmp && ownerEmp.first_name === 'Alice' && ownerEmp.last_name === 'Owner');
ok('owner code generated (EMP0001)', ownerEmp.employee_code === 'EMP0001', ownerEmp.employee_code);
ok('owner has no invite code', ownerEmp.invite_code === null);
ok('owner has no onboarding checklist', (await q(`select count(*)::int c from onboarding_items where employee_id = $1`, [ownerEmp.id]))[0].c === 0);
ok('onboarding template seeded', (await q(`select count(*)::int c from onboarding_template_items where organization_id = $1`, [orgA.id]))[0].c === 9);

await as(ownerA, async () => {
  const [ctx] = await q(`select public.current_context() as c`);
  ok('current_context returns org and role', ctx.c.organization.name === 'Alpha Ltd' && ctx.c.role.is_owner === true);
  ok('owner receives every permission', ctx.c.permissions.length === 20, String(ctx.c.permissions.length));
});

// ---------------------------------------------------------------- 2. employees and invites
console.log('\n2. Employees, onboarding and invitations');
const [roles] = await q(`select jsonb_object_agg(name, id) as r from roles where organization_id = $1`, [orgA.id]);
const [hq] = await q(`select id from branches where organization_id = $1 and is_head_office`, [orgA.id]);
const [dHr] = await q(`select id from departments where organization_id = $1 and code = 'HR'`, [orgA.id]);

let empId;
let hrEmpId;
await as(ownerA, async () => {
  const [b2] = await q(
    `insert into branches (organization_id, name, code) values ($1, 'Chattogram', 'CTG') returning id`, [orgA.id]);
  globalThis.ctg = b2.id;
  const [e] = await q(
    `insert into employees (organization_id, first_name, last_name, work_email, branch_id, department_id, joining_date)
     values ($1, 'Eve', 'Employee', 'eve@alpha.test', $2, $3, current_date - 400) returning id, employee_code, invite_code, role_id, onboarding_status`,
    [orgA.id, hq.id, dHr.id]);
  empId = e.id;
  ok('employee code auto generated', e.employee_code === 'EMP0002', e.employee_code);
  ok('invite code generated (10 chars)', e.invite_code && e.invite_code.length === 10);
  ok('default role is Employee', e.role_id === roles.r['Employee']);
  ok('onboarding starts pending', e.onboarding_status === 'pending');
  ok('9 onboarding items copied', (await q(`select count(*)::int c from onboarding_items where employee_id = $1`, [e.id]))[0].c === 9);

  const [h] = await q(
    `insert into employees (organization_id, first_name, last_name, role_id, branch_id, department_id)
     values ($1, 'Hana', 'Resources', $2, $3, $4) returning id`,
    [orgA.id, roles.r['HR Admin'], hq.id, dHr.id]);
  hrEmpId = h.id;

  const items = await q(`select id from onboarding_items where employee_id = $1 order by sort_order`, [e.id]);
  await q(`update onboarding_items set is_done = true where id = $1`, [items[0].id]);
  ok('status becomes in_progress', (await q(`select onboarding_status s from employees where id = $1`, [e.id]))[0].s === 'in_progress');
  for (const it of items) await q(`update onboarding_items set is_done = true where id = $1`, [it.id]);
  ok('status becomes completed', (await q(`select onboarding_status s from employees where id = $1`, [e.id]))[0].s === 'completed');
});

const [{ invite_code: inviteEve }] = await q(`select invite_code from employees where id = $1`, [empId]);
const eveUser = await signUp('eve@alpha.test', {});
await as(eveUser, async () => {
  await fails('bad invite code rejected', () => q(`select public.claim_invite('ZZZZZZZZZZ')`), /invalid|already been used/i);
  await q(`select public.claim_invite($1)`, [inviteEve.toLowerCase()]);
  const [ctx] = await q(`select public.current_context() as c`);
  ok('invite claim links the login', ctx.c.employee.id === empId);
  await fails('invite cannot be reused by same account', () => q(`select public.claim_invite($1)`, [inviteEve]), /already linked/i);
});
ok('invite code cleared after claim', (await q(`select invite_code from employees where id = $1`, [empId]))[0].invite_code === null);

const hrUser = await signUp('hana@alpha.test', {});
const [{ invite_code: inviteHr }] = await q(`select invite_code from employees where id = $1`, [hrEmpId]);
await as(hrUser, async () => { await q(`select public.claim_invite($1)`, [inviteHr]); });

// ---------------------------------------------------------------- 3. employee access
console.log('\n3. Standard employee access');
await as(eveUser, async () => {
  ok('sees only own row in employees', (await q(`select id from employees`)).length === 1);
  ok('sees all colleagues in directory', (await q(`select id from employee_directory`)).length === 3);
  ok('directory hides other organizations', (await q(`select id from employee_directory where organization_id <> $1`, [orgA.id])).length === 0);
  ok('can read branches', (await q(`select id from branches`)).length === 2);
  await fails('cannot create a branch', () => q(`insert into branches (organization_id, name) values ($1, 'X')`, [orgA.id]), /row-level security/i);
  await fails('cannot create an employee', () => q(`insert into employees (organization_id, first_name) values ($1, 'X')`, [orgA.id]), /row-level security/i);
  await fails('cannot open admin dashboard', () => q(`select public.dashboard_admin_stats()`), /access/i);
  ok('audit log is hidden', (await q(`select id from audit_logs`)).length === 0);
  const escalate = await db.query(`update employees set role_id = $1 where id = $2 returning id`, [roles.r['Owner'], empId]);
  ok('role escalation updates zero rows', escalate.rows.length === 0);
  ok('own role unchanged', (await q(`select role_id from employees where id = $1`, [empId]))[0].role_id === roles.r['Employee']);
  ok('cannot read private data of others', (await q(`select 1 from employee_private`)).length === 0);
  ok('can read celebrations', (await q(`select * from public.upcoming_celebrations(400)`)).length >= 1);
});

// ---------------------------------------------------------------- 4. notices and notifications
console.log('\n4. Notice board and notifications');
let noticeAll;
let noticeCtg;
await as(ownerA, async () => {
  const [n1] = await q(`insert into notices (organization_id, title, body, category) values ($1, 'Office closed Friday', 'Please note.', 'general') returning id`, [orgA.id]);
  noticeAll = n1.id;
  const [n2] = await q(`insert into notices (organization_id, title, body, audience, branch_id) values ($1, 'Chattogram only', 'Branch update', 'branch', $2) returning id`, [orgA.id, globalThis.ctg]);
  noticeCtg = n2.id;
  await q(`insert into notices (organization_id, title, body, status) values ($1, 'Draft notice', 'x', 'draft')`, [orgA.id]);
  await q(`insert into notices (organization_id, title, body, publish_at) values ($1, 'Scheduled', 'x', now() + interval '2 days')`, [orgA.id]);
});
await as(eveUser, async () => {
  const titles = (await q(`select title from notices order by title`)).map((r) => r.title);
  ok('employee sees published all-audience notice', titles.includes('Office closed Friday'));
  ok('employee does not see other branch notice', !titles.includes('Chattogram only'));
  ok('employee does not see draft or scheduled', !titles.includes('Draft notice') && !titles.includes('Scheduled'));
  const notes = await q(`select title, category from notifications`);
  ok('notification fan-out reached employee', notes.some((n) => n.title === 'Office closed Friday'));
  ok('welcome notification exists', notes.some((n) => n.title === 'Welcome aboard'));
  await q(`insert into notice_receipts (notice_id, employee_id, organization_id, read_at) values ($1, $2, $3, now())`, [noticeAll, empId, orgA.id]);
  await q(`update notice_receipts set acknowledged_at = now() where notice_id = $1 and employee_id = $2`, [noticeAll, empId]);
  ok('read receipt stored', (await q(`select 1 from notice_receipts`)).length === 1);
  await q(`update notifications set read_at = now() where read_at is null`);
  ok('notifications can be marked read', (await q(`select 1 from notifications where read_at is null`)).length === 0);
  await fails('notification content cannot be edited', () => q(`update notifications set title = 'hacked'`), /permission denied/i);
  await fails('employee cannot create notices', () => q(`insert into notices (organization_id, title) values ($1, 'x')`, [orgA.id]), /row-level security/i);
});
ok('owner was not notified of own notice', (await q(`select 1 from notifications n join employees e on e.id = n.employee_id where e.user_id = $1 and n.category = 'notice'`, [ownerA])).length === 0);
await q(`update notices set publish_at = now() - interval '1 minute' where title = 'Scheduled'`);
await as(eveUser, async () => { await q(`select public.dispatch_due_notice_notifications()`); });
ok('due scheduled notice dispatched lazily', (await q(`select 1 from notifications n join employees e on e.id = n.employee_id where e.user_id = $1 and n.title = 'Scheduled'`, [eveUser])).length === 1);

// ---------------------------------------------------------------- 5. tenant isolation
console.log('\n5. Tenant isolation');
await as(ownerB, async () => {
  ok('org B owner sees only own organization employees', (await q(`select id from employees where organization_id = $1`, [orgA.id])).length === 0 && (await q(`select id from employees`)).length === 1);
  ok('org B owner cannot see org A notices', (await q(`select id from notices where organization_id = $1`, [orgA.id])).length === 0);
  ok('org B owner cannot see org A roles', (await q(`select id from roles where organization_id = $1`, [orgA.id])).length === 0);
  await fails('cannot insert into org A', () => q(`insert into branches (organization_id, name) values ($1, 'Evil')`, [orgA.id]), /row-level security/i);
  await fails('cannot use org A branch as reference', () =>
    q(`insert into employees (organization_id, first_name, branch_id) values ($1, 'Mix', $2)`, [orgB.id, hq.id]),
    /does not belong to this organization/i);
  await fails('cannot edit org A profile', async () => {
    const r = await db.query(`update organizations set name = 'Hacked' where id = $1 returning id`, [orgA.id]);
    if (r.rows.length === 0) throw new Error('row-level security: nothing updated');
  }, /row-level|nothing updated/i);
});
ok('org A name intact', (await q(`select name from organizations where id = $1`, [orgA.id]))[0].name === 'Alpha Ltd');

// ---------------------------------------------------------------- 6. HR admin, scope and guards
console.log('\n6. HR admin, data scope and guards');
await as(hrUser, async () => {
  ok('HR sees every employee of the org', (await q(`select id from employees`)).length === 3);
  const [d] = await q(`select public.dashboard_admin_stats() as s`);
  ok('HR dashboard total is 3', d.s.summary.total === 3, JSON.stringify(d.s.summary));
  ok('dashboard has branch and trend data', d.s.by_branch.length === 2 && d.s.joining_trend.length === 6);
  await q(`insert into employee_private (employee_id, organization_id, national_id) values ($1, $2, 'NID-123')`, [empId, orgA.id]);
  ok('HR can read private data', (await q(`select national_id from employee_private where employee_id = $1`, [empId]))[0].national_id === 'NID-123');
  await fails('HR cannot assign Owner role', () => q(`update employees set role_id = $1 where id = $2`, [roles.r['Owner'], empId]), /Only an owner/i);
  await fails('HR cannot manage roles', () => q(`select public.set_role_permissions($1, array['employees.view'])`, [roles.r['Employee']]), /permission/i);
  await fails('HR cannot edit company profile', async () => {
    const r = await db.query(`update organizations set name = 'X' where id = $1 returning id`, [orgA.id]);
    if (r.rows.length === 0) throw new Error('row-level security: nothing updated');
  }, /row-level|nothing updated/i);
  const r = await q(`select public.regenerate_invite($1) as c`, [hrEmpId]).catch((e) => e);
  ok('cannot regenerate invite for activated employee', r instanceof Error && /already has an active login/i.test(r.message));
  await q(`update employees set role_id = $1 where id = $2`, [roles.r['Department Manager'], empId]);
  ok('HR can assign non-owner role', true);
});
ok('role change notified the employee', (await q(`select 1 from notifications n join employees e on e.id = n.employee_id where e.user_id = $1 and n.category = 'security'`, [eveUser])).length === 1);
await as(ownerA, async () => {
  await fails('owner cannot demote the last owner (self)', () => q(`update employees set role_id = $1 where id = $2`, [roles.r['Employee'], ownerEmp.id]), /own role|at least one owner/i);
  await q(`select public.set_role_permissions($1, array['dashboard.team','employees.view','notices.manage'])`, [roles.r['Department Manager']]);
  ok('role permissions replaced', (await q(`select count(*)::int c from role_permissions where role_id = $1`, [roles.r['Department Manager']]))[0].c === 3);
  await fails('owner role permissions are fixed', () => q(`select public.set_role_permissions($1, array['employees.view'])`, [roles.r['Owner']]), /every permission/i);
  await fails('unknown permission rejected', () => q(`select public.set_role_permissions($1, array['nope.nope'])`, [roles.r['Employee']]), /Unknown permission/i);
  await fails('system role cannot be deleted', async () => {
    const r = await db.query(`delete from roles where id = $1 returning id`, [roles.r['Employee']]);
    if (r.rows.length === 0) throw new Error('nothing deleted');
  }, /System roles|nothing deleted/i);
  await fails('head office cannot be deleted', () => q(`delete from branches where id = $1`, [hq.id]), /head office/i);
  const [custom] = await q(`insert into roles (organization_id, name, data_scope) values ($1, 'Receptionist', 'branch') returning id`, [orgA.id]);
  ok('custom role can be created', !!custom.id);
  await fails('cannot create a second owner role', () => q(`insert into roles (organization_id, name, is_owner) values ($1, 'Boss', true)`, [orgA.id]), /System roles are created/i);
});

// Department manager scope (Eve is now a Department Manager in HR department)
await as(eveUser, async () => {
  const rows = await q(`select first_name from employees order by first_name`);
  const names = rows.map((r) => r.first_name);
  ok('dept manager sees own dept colleagues only', names.includes('Eve') && names.includes('Hana') && !names.includes('Alice'), names.join(','));
  const [t] = await q(`select public.dashboard_team_stats() as s`);
  ok('team dashboard counts scoped members', t.s.summary.total === 1, JSON.stringify(t.s.summary));
  await fails('dept manager still cannot open admin dashboard', () => q(`select public.dashboard_admin_stats()`), /access/i);
});

// ---------------------------------------------------------------- 7. archive, limits, audit
console.log('\n7. Archive, plan limits and audit trail');
await as(hrUser, async () => {
  await fails('cannot archive self', () => q(`select public.archive_employee($1)`, [hrEmpId]), /own record/i);
  await q(`select public.archive_employee($1)`, [empId]);
});
ok('archived employee loses access', (await q(`select 1 from employees where id = $1 and archived_at is not null`, [empId])).length === 1);
await as(eveUser, async () => {
  ok('archived employee context is empty', (await q(`select public.current_context() as c`))[0].c === null);
  ok('archived employee sees nothing', (await q(`select id from employees`)).length === 0);
});
await as(ownerA, async () => {
  await fails('owner cannot archive themselves', () => q(`select public.archive_employee($1)`, [ownerEmp.id]), /own record/i);
  await q(`select public.archive_employee($1, false)`, [empId]);
});
await q(`update organizations set max_employees = 3 where id = $1`, [orgA.id]);
await as(ownerA, async () => {
  await fails('employee plan limit enforced', () => q(`insert into employees (organization_id, first_name) values ($1, 'Over')`, [orgA.id]), /limit/i);
  await fails('subscription fields are protected', () => q(`update organizations set max_employees = 9999 where id = $1`, [orgA.id]), /platform/i);
  await q(`update organizations set phone = '+8801000000000', city = 'Dhaka' where id = $1`, [orgA.id]);
  ok('owner can edit company profile', (await q(`select city from organizations where id = $1`, [orgA.id]))[0].city === 'Dhaka');
  const logs = await q(`select action, entity_type from audit_logs order by id desc limit 50`);
  ok('audit trail visible to owner', logs.length > 5);
  ok('audit records role permission change', logs.some((l) => l.entity_type === 'role_permissions'));
  const priv = await q(`select changes from audit_logs where entity_type = 'employee_private' limit 1`);
  ok('private data is redacted in audit', priv.length === 1 && JSON.stringify(priv[0].changes).includes('redacted') && !JSON.stringify(priv[0].changes).includes('NID-123'));
});

// ---------------------------------------------------------------- 7b. role usage and notice statistics
console.log('\n7b. Role usage and notice statistics');
await as(ownerA, async () => {
  const usage = await q(`select * from public.role_usage()`);
  ok('role usage lists all roles', usage.length === 6, String(usage.length));
  const ownerUsage = usage.find((u) => u.role_id === roles.r['Owner']);
  ok('owner role has one employee', Number(ownerUsage.employee_count) === 1);
  const [s] = await q(`select public.notice_stats($1) as s`, [noticeAll]);
  ok('notice stats count audience, reads and acknowledgements',
    s.s.audience === 3 && s.s.read === 1 && s.s.acknowledged === 1, JSON.stringify(s.s));
});
// Eve's role was granted notices.manage earlier; return her to the plain Employee role.
await q(`update employees set role_id = $1 where id = $2`, [roles.r['Employee'], empId]);
await as(eveUser, async () => {
  await fails('employee cannot read notice stats', () => q(`select public.notice_stats($1)`, [noticeAll]), /permission/i);
  ok('employee without roles.view gets no usage rows', (await q(`select * from public.role_usage()`)).length === 0);
});
ok('notice author name stored', (await q(`select created_by_name from notices where id = $1`, [noticeAll]))[0].created_by_name === 'Alice Owner');

// ---------------------------------------------------------------- 8. storage policies
console.log('\n8. Storage policies');
await q(`update employees set archived_at = null where id = $1`, [empId]);
await as(ownerA, async () => {
  await q(`insert into storage.objects (bucket_id, name) values ('org-assets', $1)`, [`${orgA.id}/logo-1.png`]);
  ok('owner can upload company logo', true);
  await fails('owner cannot write into other org folder', () => q(`insert into storage.objects (bucket_id, name) values ('org-assets', $1)`, [`${orgB.id}/logo-1.png`]), /row-level security/i);
  await q(`insert into storage.objects (bucket_id, name) values ('employee-documents', $1)`, [`${orgA.id}/${empId}/cv.pdf`]);
  ok('owner can upload employee document', true);
});
await as(eveUser, async () => {
  ok('employee can read own document object', (await q(`select 1 from storage.objects where bucket_id = 'employee-documents'`)).length === 1);
  await fails('employee cannot upload documents', () => q(`insert into storage.objects (bucket_id, name) values ('employee-documents', $1)`, [`${orgA.id}/${empId}/x.pdf`]), /row-level security/i);
  await q(`insert into storage.objects (bucket_id, name) values ('avatars', $1)`, [`${orgA.id}/${empId}/photo-1.jpg`]);
  await q(`select public.set_my_photo($1)`, [`${orgA.id}/${empId}/photo-1.jpg`]);
  await fails('employee cannot set photo outside own folder', () => q(`select public.set_my_photo($1)`, [`${orgA.id}/${hrEmpId}/photo.jpg`]), /Invalid photo/i);
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
