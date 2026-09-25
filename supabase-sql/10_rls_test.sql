-- =====================================================================
--  10-САБАҚ · RLS-ТІ ТЕКСЕРУ: БАСҚА АДАМ БОЛЫП СҰРАУ ЖІБЕРУ
-- =====================================================================
--  Не үйренесіз:
--    • сынақ қолданушыларын жасау
--    • SQL Editor-да anon не белгілі бір қолданушы болып сұрау жіберу
--    • 9-сабақтағы саясаттардың жұмысын өз көзіңізбен тексеру
--
--  Дайындық (бір рет):
--    1) Supabase → Authentication → Users → Add user → Create new user.
--       Екі қолданушы жасаңыз, "Auto Confirm User" белгісін қойыңыз:
--         aigerim@example.com   (пароль кез келген, мысалы Test-12345)
--         erlan@example.com
--    2) Table Editor → profiles: екі жол пайда болуы керек. Бұл
--       9-сабақтағы on_auth_user_created триггерінің жұмысы.
--
--  Қалай орындау: блоктарды (10.1, 10.2 ...) БІР-БІРДЕН белгілеп, Run
--  басыңыз. Әр блоктың соңғы сұрауының нәтижесі көрсетіледі.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 10.1. Қолданушылар және олардың профильдері
-- ---------------------------------------------------------------------
select u.email, u.id, p.full_name, p.created_at as profile_created
from auth.users u
left join profiles p on p.id = u.id
order by u.email;


-- ---------------------------------------------------------------------
-- 10.2. Профильдерді толтырып, аккаунттарды клиенттерге байланыстыру
-- ---------------------------------------------------------------------
update profiles set full_name = 'Айгерім С.'
where id = (select id from auth.users where email = 'aigerim@example.com');

update profiles set full_name = 'Ерлан Т.'
where id = (select id from auth.users where email = 'erlan@example.com');

update customers
set user_id = (select id from auth.users where email = 'aigerim@example.com')
where phone = '+77000000001';

update customers
set user_id = (select id from auth.users where email = 'erlan@example.com')
where phone = '+77000000002';

select c.full_name, c.phone, u.email
from customers c
join auth.users u on u.id = c.user_id;


-- ---------------------------------------------------------------------
-- 10.3. Айгерім болып кіріп, таңдаулыға тауар қосу
-- ---------------------------------------------------------------------
-- SQL Editor-да басқа адам болып сұрау жіберу үшін екі қадам керек:
--   1) request.jwt.claims — "мен кіммін": токендегі sub = қолданушы id-і
--   2) set local role authenticated — рөлді ауыстыру
-- Supabase API да дәл осылай істейді: токенді тексеріп, осы екеуін қояды.
-- local сөзі: өзгеріс тек осы Run ішінде әрекет етеді.
select set_config('request.jwt.claims',
  json_build_object('sub',  (select id from auth.users where email = 'aigerim@example.com'),
                    'role', 'authenticated')::text,
  true);
set local role authenticated;

insert into favorites (product_id)
select id from products
where (name, color) in (('Диван Tamir', 'Зәйтүн'), ('Кофе үстелдері Duo', 'Емен'))
on conflict do nothing;

select auth.uid() as me, p.name, p.color
from favorites f
join products p on p.id = f.product_id;

reset role;

-- user_id-ді жазбадық: default auth.uid() Айгерімнің id-ін өзі қойды.


-- ---------------------------------------------------------------------
-- 10.4. Ерлан болып кіру: ол тек өз таңдаулысын көреді
-- ---------------------------------------------------------------------
select set_config('request.jwt.claims',
  json_build_object('sub',  (select id from auth.users where email = 'erlan@example.com'),
                    'role', 'authenticated')::text,
  true);
set local role authenticated;

insert into favorites (product_id)
select id from products where name = 'Кресло Aru' and color = 'Беж'
on conflict do nothing;

select auth.uid() as me, p.name, p.color
from favorites f
join products p on p.id = f.product_id;

reset role;

-- Кестеде 3 жол бар, бірақ Ерлан тек өзінің 1 жолын көреді.
-- Біз where жазған жоқпыз: оны RLS саясаты қосты.


-- ---------------------------------------------------------------------
-- 10.5. Ерлан Айгерімнің таңдаулысын өшіріп көреді
-- ---------------------------------------------------------------------
select set_config('request.jwt.claims',
  json_build_object('sub',  (select id from auth.users where email = 'erlan@example.com'),
                    'role', 'authenticated')::text,
  true);
set local role authenticated;

with deleted as (
  delete from favorites
  where product_id = (select id from products where name = 'Диван Tamir' and color = 'Зәйтүн')
  returning *
)
select count(*) as deleted_rows from deleted;

reset role;

-- deleted_rows = 0. Бұл Айгерімнің жазбасы. Ерлан үшін ол "жоқ",
-- сондықтан өшпейді. Қате де шықпайды, жай 0 жол.


-- ---------------------------------------------------------------------
-- 10.6. Кім не көреді? Үш рөлді салыстыру
-- ---------------------------------------------------------------------
-- а) anon — жүйеге кірмеген келуші
set local role anon;

select (select count(*) from products)    as products,
       (select count(*) from reviews)     as reviews,
       (select count(*) from customers)   as customers,
       (select count(*) from orders)      as orders,
       (select count(*) from order_items) as order_items,
       (select count(*) from favorites)   as favorites;

reset role;
-- Күтілетін нәтиже: 16, 7, 0, 0, 0, 0 — каталог ашық, қалғаны жабық.

-- ә) Айгерім
select set_config('request.jwt.claims',
  json_build_object('sub',  (select id from auth.users where email = 'aigerim@example.com'),
                    'role', 'authenticated')::text,
  true);
set local role authenticated;

select (select count(*) from products)    as products,
       (select count(*) from reviews)     as reviews,
       (select count(*) from customers)   as customers,
       (select count(*) from orders)      as orders,
       (select count(*) from order_items) as order_items,
       (select count(*) from favorites)   as favorites;

reset role;
-- Күтілетін нәтиже: 16, 7, 1, 2, 3, 2 — тек өзінің жазбасы, тапсырыстары,
-- таңдаулылары.

-- б) postgres (SQL Editor-дың өз рөлі) — RLS әсер етпейді
select (select count(*) from products)    as products,
       (select count(*) from reviews)     as reviews,
       (select count(*) from customers)   as customers,
       (select count(*) from orders)      as orders,
       (select count(*) from order_items) as order_items,
       (select count(*) from favorites)   as favorites;
-- Күтілетін нәтиже: 16, 7, 9, 12, 16, 3 — бәрі.


-- ---------------------------------------------------------------------
-- 10.7. Айгерімнің тапсырыстар тарихы (8-сабақтағы view арқылы)
-- ---------------------------------------------------------------------
select set_config('request.jwt.claims',
  json_build_object('sub',  (select id from auth.users where email = 'aigerim@example.com'),
                    'role', 'authenticated')::text,
  true);
set local role authenticated;

select id, created_at, store, status, items, total
from order_summary
order by created_at;

reset role;

-- view security_invoker = on болғандықтан, оған Айгерімнің саясаттары
-- қолданылды: 12 тапсырыстың тек екеуі көрінеді.


-- ---------------------------------------------------------------------
-- 10.8. Әдейі ҚАТЕ беретін әрекеттер
-- ---------------------------------------------------------------------
-- Жаңа query бетіне көшіріп, белгілеп, Ctrl + / басыңыз (түсініктеме
-- белгілері алынады) да, Run басыңыз:
--
-- а) Ерлан басқа біреудің атынан таңдаулы қоспақ:
--   select set_config('request.jwt.claims',
--     json_build_object('sub',  (select id from auth.users where email = 'erlan@example.com'),
--                       'role', 'authenticated')::text,
--     true);
--   set local role authenticated;
--   insert into favorites (user_id, product_id)
--   values ('00000000-0000-0000-0000-000000000000', 1);
--   → new row violates row-level security policy for table "favorites"
--
-- ә) Кірмеген келуші тапсырыс жасамақ:
--   set local role anon;
--   select create_order('+77000000001', 'zetta', '[{"product_id": 1, "quantity": 1}]');
--   → permission denied for function create_order (9.7-де рұқсатты алдық)


-- ---------------------------------------------------------------------
-- 10.9. Басқа тәсілдер
-- ---------------------------------------------------------------------
-- • SQL Editor-да рөл таңдайтын мәзір де бар (әдепкіде "postgres" деп
--   тұрады): authenticated-ті және қолданушыны таңдап, set_config-сіз
--   сол адам болып сұрау жіберуге болады.
-- • Нағыз тексеру — сайттың өзінен: 11_supabase_js.md файлындағы
--   мысалда Айгерім email мен парольмен кіріп, favorites-ті оқиды.


-- =====================================================================
--  ТАПСЫРМАЛАР · шешімдері sheshimder.sql файлында
-- =====================================================================
-- Тапсырма 10-1. Ерлан болып кіріп, order_summary арқылы оның
--   тапсырыстарын шығарыңыз. Неше тапсырыс көрінді?
--
-- Тапсырма 10-2. anon болып profiles кестесін оқып көріңіз. Неше жол
--   көрінді? Неге?
--
-- Тапсырма 10-3. Айгерім болып кіріп, өз профиліндегі full_name-ді
--   'Айгерім Сейітова' деп өзгертіңіз (returning арқылы көрсетіңіз).
--   Сосын сол Run ішінде Ерланның профилін өзгертіп көріңіз: неше жол
--   өзгерді?
-- =====================================================================
