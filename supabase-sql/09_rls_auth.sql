-- =====================================================================
--  9-САБАҚ · SUPABASE AUTH ЖӘНЕ ROW LEVEL SECURITY (RLS)
-- =====================================================================
--  Не үйренесіз:
--    • Supabase рөлдері: anon, authenticated, service_role
--    • auth.users кестесі және auth.uid() функциясы
--    • policy (саясат): кім қай жолды оқи, қоса, өзгерте, өшіре алады
--    • тіркелген қолданушыға профильді триггермен автоматты жасау
--    • әркім тек өз деректерін көреді: таңдаулылар, тапсырыстар
--    • API арқылы шақырылатын функцияларды шектеу
--
--  Қалай орындау: файлды толық көшіріп, бір рет Run басыңыз.
--  Саясаттарды 10_rls_test.sql файлы арқылы тексересіз.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 9.1. Дерекқорға кім жүгінеді?
-- ---------------------------------------------------------------------
-- Сайт не қосымша Supabase-қа API кілтімен жүгінеді. Postgres ішінде
-- әр сұрау белгілі бір РӨЛМЕН (role) орындалады:
--
--   anon           жүйеге кірмеген келуші. Сайтқа қойылатын кілт:
--                  anon не publishable кілті (Project Settings → API Keys)
--   authenticated  жүйеге кірген қолданушы (email, телефон, Google ...)
--   service_role   сервердің құпия кілті (service_role не secret).
--                  RLS-ті айналып өтеді, оны браузерге ЕШҚАШАН қоймаңыз
--   postgres       SQL Editor осы рөлмен жұмыс істейді, RLS оған әсер етпейді
--
-- Қолданушы кіргенде Supabase оған токен (JWT) береді. Postgres ішінде:
--   auth.uid()   ағымдағы қолданушының id-і (uuid), кірмесе — NULL
--   auth.jwt()   токеннің толық мазмұны (jsonb)
--
-- RLS қалай жұмыс істейді: RLS қосулы кестеге келген әр сұрауға саясаттың
-- шарты көрінбейтін where болып қосылады. Саясат жоқ болса, жол да жоқ.
-- 1-сабақтан бері барлық кестеде RLS қосулы, бірақ саясат жоқ, сондықтан
-- API қазір ештеңе көрсетпейді. Енді рұқсаттарды біртіндеп ашамыз.


-- ---------------------------------------------------------------------
-- 9.2. Каталог бәріне ашық (тек оқу)
-- ---------------------------------------------------------------------
create policy "Бәрі көре алады"
on categories for select
to anon, authenticated
using (true);

create policy "Бәрі көре алады"
on stores for select
to anon, authenticated
using (true);

create policy "Бәрі көре алады"
on products for select
to anon, authenticated
using (true);

create policy "Бәрі көре алады"
on reviews for select
to anon, authenticated
using (true);

--   create policy "атауы"    атауы еркін, түсінікті болса болғаны
--   on products              қай кесте
--   for select               қай әрекет: select, insert, update, delete не all
--   to anon, authenticated   қай рөлдерге
--   using (true)             шарт: қай жолдар көрінеді (true — барлығы)
--
-- insert, update, delete саясаттары жоқ. Демек тауарды сайттан ешкім
-- өзгерте алмайды, тек SQL Editor, Dashboard не service_role кілті бар сервер.


-- ---------------------------------------------------------------------
-- 9.3. Профиль: әр қолданушыға бір жол
-- ---------------------------------------------------------------------
-- Supabase Auth қолданушыларды auth.users кестесінде сақтайды. Ол кестеге
-- өз бағандарымызды қоспаймыз. Орнына public-те profiles кестесін жасап,
-- оны auth.users-пен id арқылы байланыстырамыз.
create table profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "Өз профилін көреді"
on profiles for select
to authenticated
using ((select auth.uid()) = id);

create policy "Өз профилін өзгертеді"
on profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

--   using (...)       қандай БАР жолдарды көріп, өзгертуге болады
--   with check (...)  өзгергеннен кейінгі ЖАҢА жол қандай болуы керек
--                     (басқа біреудің id-іне ауыстырып жібере алмайды)
--   (select auth.uid())  select ішіне орау — Supabase кеңесі: Postgres
--                     оны әр жолға емес, бүкіл сұрауға бір рет есептейді


-- ---------------------------------------------------------------------
-- 9.4. Тіркелген сәтте профиль өзі жасалсын (trigger)
-- ---------------------------------------------------------------------
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

--   security definer   функция оны құрған рөлдің (postgres) құқығымен
--                      орындалады. Қолданушыны Auth сервисі қосады, ал оның
--                      public.profiles-қа жазуға құқығы жоқ, сондықтан керек.
--                      security definer функцияда search_path = '' міндетті.
--   raw_user_meta_data тіркелу кезінде жіберілген қосымша деректер:
--                      supabase.auth.signUp({ email, password,
--                        options: { data: { full_name: 'Айгерім С.' } } })

-- public-тегі кез келген функцияны API арқылы шақыруға болады (9.7).
-- Бұл функция тек триггерге арналған, ал security definer функцияның
-- бәріне ашық тұруы қауіпті. Сондықтан рұқсатты алып тастаймыз, триггер
-- бұдан кейін де жұмыс істей береді:
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Триггерге дейін тіркелген қолданушылар болса, оларға да профиль жасаймыз:
insert into profiles (id, full_name)
select id, raw_user_meta_data ->> 'full_name'
from auth.users
on conflict (id) do nothing;


-- ---------------------------------------------------------------------
-- 9.5. Таңдаулылар: әркім тек өзінікін көреді
-- ---------------------------------------------------------------------
create table favorites (
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  product_id bigint not null references products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index on favorites (product_id);

alter table favorites enable row level security;

create policy "Өз таңдаулыларын көреді"
on favorites for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Өзіне ғана қосады"
on favorites for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Өзінікін ғана өшіреді"
on favorites for delete
to authenticated
using ((select auth.uid()) = user_id);

-- default auth.uid() — user_id-ді клиенттен жіберудің керегі жоқ:
--   supabase.from('favorites').insert({ product_id: 1 })
-- update саясаты жоқ, сондықтан таңдаулыны ешкім өзгерте алмайды
-- (өшіріп, қайта қосуға болады).


-- ---------------------------------------------------------------------
-- 9.6. Тапсырыстар: клиент тек өз тапсырыстарын көреді
-- ---------------------------------------------------------------------
-- Дүкен клиентін (customers) сайттағы аккаунтпен (auth.users) байланыстырамыз.
-- Телефонмен тапсырыс берген клиенттің аккаунты жоқ болуы мүмкін,
-- сондықтан бос (NULL) бола алады.
alter table customers
  add column user_id uuid unique references auth.users (id) on delete set null;

create policy "Өз жазбасын көреді"
on customers for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Өз тапсырыстарын көреді"
on orders for select
to authenticated
using (
  customer_id in (
    select id from public.customers where user_id = (select auth.uid())
  )
);

create policy "Өз тапсырысының құрамын көреді"
on order_items for select
to authenticated
using (
  order_id in (
    select o.id
    from public.orders o
    join public.customers c on c.id = o.customer_id
    where c.user_id = (select auth.uid())
  )
);

-- Саясаттың шарты кез келген SQL бола алады: ішкі сұрау, join ...
-- 8-сабақтағы order_summary view-ы security_invoker болғандықтан, оған да
-- осы саясаттар қолданылады: қолданушы view арқылы да тек өзінікін көреді.


-- ---------------------------------------------------------------------
-- 9.7. API арқылы шақырылатын функцияларды шектеу
-- ---------------------------------------------------------------------
-- public-тегі әр функцияны кез келген адам .rpc() арқылы шақыра алады.
-- create_order функциясы security definer емес, сондықтан RLS оны
-- қорғайды (anon мен authenticated-те orders-қа insert саясаты жоқ).
-- Бірақ сенбей, артық рұқсатты алып тастаған дұрыс:
revoke execute on function create_order(text, text, jsonb, text) from public, anon, authenticated;

-- Енді оны тек SQL Editor (postgres) және сервер (service_role) шақырады.


-- ---------------------------------------------------------------------
-- 9.8. Тексеру: барлық саясаттар
-- ---------------------------------------------------------------------
-- Бұларды Supabase-та Authentication → Policies бетінен де көруге болады.
-- Advisors → Security Advisor бөлімі қауіпсіздік қателерін өзі іздейді:
-- RLS өшірулі кесте, search_path жазылмаған функция т.б.
-- Performance Advisor жаңа индекстерге "Unused Index" (INFO) деп жазуы
-- мүмкін: деректер аз, индекс әлі қолданылмаған. Бұл қалыпты жағдай.
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd;


-- =====================================================================
--  ТАПСЫРМАЛАР · 10-сабақтан кейін орындаңыз, шешімдері sheshimder.sql-да
-- =====================================================================
-- Тапсырма 9-1. RLS-і ӨШІРУЛІ қалған кестелерді табатын сұрау жазыңыз
--   (public схемасы). Кеңес: pg_tables кестесінің rowsecurity бағаны.
--   Supabase-тің Security Advisor бөлімі де осыны тексереді.
--
-- Тапсырма 9-2. reviews кестесіне user_id бағанын қосыңыз (default
--   auth.uid()) және саясаттар жазыңыз: жүйеге кірген қолданушы өз
--   атынан пікір қоса алады, өз пікірін өшіре алады.
--
-- Тапсырма 9-3. Каталог саясатын өзгертіңіз: anon тек қоймадағы
--   тауарларды көрсін, ал authenticated барлығын көрсін.
--   Кеңес: ескі саясатты drop policy ... on products; арқылы өшіріп,
--   әр рөлге бөлек саясат жазыңыз.
--
-- Тапсырма 9-4. Қолданушы өз профилін өзі қоса алатындай insert
--   саясатын жазыңыз (id тек өзінің id-і болуы керек).
-- =====================================================================
