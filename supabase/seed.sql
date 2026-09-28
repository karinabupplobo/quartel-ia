-- =============================================================================
-- Demo seed: fictional school. Local/demo only — never runs in production.
-- Deterministic UUIDs so every module's seed can reference the same people.
-- Login accounts (auth.users + e_user_roles) are created by a separate script
-- through the Admin API, not here.
-- =============================================================================

insert into public.e_tenants (id, name, slug) values
  ('10000000-0000-4000-8000-000000000001', 'Escola Horizonte de Idiomas', 'horizonte');

insert into public.e_tenant_modules (tenant_id, module)
select '10000000-0000-4000-8000-000000000001', m
from unnest(enum_range(null::public.e_module_key)) as m;

insert into public.e_courses (id, tenant_id, name, description) values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
   'General English', 'Adult English, levels A1 to C1'),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
   'English for Teens', 'Ages 11 to 17, levels A1 to B2'),
  ('30000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001',
   'Spanish', 'Adult Spanish, levels A1 to B2');

-- Fictional people. Phones use the +55 11 90000-xxxx range.
insert into public.e_people (id, tenant_id, full_name, email, phone_e164, birth_date) values
  -- management
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
   'Ana Ribeiro', 'ana.ribeiro@example.com', '+5511900000001', '1984-03-12'),
  -- teachers
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
   'Daniel Souza', 'daniel.souza@example.com', '+5511900000002', '1990-07-25'),
  ('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001',
   'Lucía Fernández', 'lucia.fernandez@example.com', '+5511900000003', '1988-11-02'),
  -- students
  ('20000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000001',
   'Bruno Carvalho', 'bruno.carvalho@example.com', '+5511900000011', '1996-01-30'),
  ('20000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000001',
   'Camila Nogueira', 'camila.nogueira@example.com', '+5511900000012', '1992-05-17'),
  ('20000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000001',
   'Rafael Mendes', 'rafael.mendes@example.com', '+5511900000013', '2001-09-08'),
  ('20000000-0000-4000-8000-000000000014', '10000000-0000-4000-8000-000000000001',
   'Juliana Prado', 'juliana.prado@example.com', '+5511900000014', '1987-12-21'),
  -- minor student (no phone of their own; contact goes through the guardian)
  ('20000000-0000-4000-8000-000000000015', '10000000-0000-4000-8000-000000000001',
   'Pedro Albuquerque', null, null, '2012-04-03'),
  -- guardian of Pedro
  ('20000000-0000-4000-8000-000000000021', '10000000-0000-4000-8000-000000000001',
   'Maria Albuquerque', 'maria.albuquerque@example.com', '+5511900000021', '1980-08-14');

insert into public.e_guardianships (tenant_id, guardian_person_id, student_person_id) values
  ('10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000021',
   '20000000-0000-4000-8000-000000000015');
