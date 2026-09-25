-- =====================================================================
--  8-САБАҚ · VIEW, FUNCTION, TRIGGER
-- =====================================================================
--  Не үйренесіз:
--    • view (көрініс): сақталған сұрау, кесте сияқты оқылады
--    • function: Supabase-та .rpc() арқылы шақырылатын функция
--    • plpgsql: бірнеше қадамды бір транзакцияда орындайтын функция
--    • trigger: кестеде оқиға болғанда функцияны өзі іске қосу
--
--  Қалай орындау: файлды толық көшіріп, бір рет Run басыңыз. Ол view,
--  function, trigger құрады. Содан кейін әр бөлімдегі тексеру
--  сұрауларын (select ...) жеке-жеке белгілеп орындап көріңіз.
--
--  Supabase-та көру: Database → Functions, Database → Triggers,
--  ал view-лар Table Editor тізімінде тұрады.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 8.1. view: тауар каталогы
-- ---------------------------------------------------------------------
-- 6-сабақтағы join-ді әр жолы қайта жазбау үшін оны атпен сақтаймыз.
create view product_catalog
with (security_invoker = on)
as
select p.id, p.name, p.color, p.price, p.old_price, p.in_stock, p.badge,
       p.description,
       c.slug as category_slug,
       c.name as category
from products p
join categories c on c.id = p.category_id;

-- security_invoker = on — Supabase-та міндетті түрде жазыңыз. Сонда
-- view-ды оқыған адамға кестелердің RLS саясаттары қолданылады.
-- Жазылмаса, view оны құрған postgres рөлімен орындалып, RLS-ті айналып
-- өтеді де, жабық деректі API арқылы көрсетіп қоюы мүмкін.

-- Тексеру: view кесте сияқты оқылады
select name, color, price, category
from product_catalog
where category_slug = 'sofa';

-- Supabase JS:  supabase.from('product_catalog').select('*').eq('category_slug', 'sofa')


-- ---------------------------------------------------------------------
-- 8.2. view: тапсырыстардың қысқаша есебі
-- ---------------------------------------------------------------------
-- 4-сабақта айтқандай, API арқылы sum алу әдепкі бойынша өшірулі.
-- Сомаларды view ішінде есептеп қойсақ, JS жай ғана оқиды.
create view order_summary
with (security_invoker = on)
as
select o.id, o.created_at, o.status, o.payment,
       cu.full_name                     as customer,
       s.name                           as store,
       sum(oi.quantity)                 as items,
       sum(oi.quantity * oi.unit_price) as total
from orders o
join customers   cu on cu.id = o.customer_id
join stores      s  on s.id  = o.store_id
join order_items oi on oi.order_id = o.id
group by o.id, cu.full_name, s.name;

-- group by o.id жеткілікті: id — primary key, сондықтан o.status,
-- o.created_at сияқты бағандарды қайта жазбай-ақ ала береміз.

-- Тексеру:
select * from order_summary order by created_at;


-- ---------------------------------------------------------------------
-- 8.3. function: баға аралығындағы тауарлар
-- ---------------------------------------------------------------------
create function products_in_price_range(min_price integer, max_price integer)
returns setof products
language sql
stable
set search_path = ''
as $$
  select *
  from public.products
  where price between min_price and max_price
  order by price;
$$;

--   returns setof products  products кестесінің жолдарын қайтарады
--   language sql            денесі жай SQL сұрау
--   stable                  деректі өзгертпейді, тек оқиды
--   set search_path = ''    Supabase-тің қауіпсіздік кеңесі: кесте аттарын
--                           толық жазамыз (public.products), сонда функцияны
--                           басқа схемадағы жалған кестемен "алдауға" болмайды
--   $$ ... $$               функцияның денесі

-- Тексеру:
select name, color, price
from products_in_price_range(300000, 500000);

-- Supabase JS:
--   supabase.rpc('products_in_price_range', { min_price: 300000, max_price: 500000 })


-- ---------------------------------------------------------------------
-- 8.4. function: бір мән қайтаратын (бөліп төлеу 0-0-12)
-- ---------------------------------------------------------------------
create function monthly_payment(total integer, months integer default 12)
returns integer
language sql
immutable
set search_path = ''
as $$
  select ceil(total::numeric / months)::integer;
$$;

--   immutable            бір кірісте әрқашан бір нәтиже (кестеге қарамайды)
--   default 12           екінші аргумент жазылмаса, 12 ай
--   ::numeric, ::integer  түрін ауыстыру (cast). ceil — жоғары қарай дөңгелектеу

-- Тексеру:
select name, color, price,
       monthly_payment(price)     as per_month_12,
       monthly_payment(price, 24) as per_month_24
from products
order by price desc;


-- ---------------------------------------------------------------------
-- 8.5. plpgsql function: тапсырысты бір қадамда жасау
-- ---------------------------------------------------------------------
-- Тапсырыс жасау екі кестеге жазуды қажет етеді: orders және order_items.
-- Функция ішіндегінің бәрі БІР транзакцияда орындалады: бір жері қате
-- болса, ештеңе сақталмайды. Жартылай жазылған тапсырыс қалмайды.
create function create_order(
  customer_phone text,
  store_slug     text,
  items          jsonb,              -- [{"product_id": 16, "quantity": 2}, ...]
  pay            text default 'card'
)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_customer_id bigint;
  v_store_id    bigint;
  v_order_id    bigint;
  v_count       integer;
begin
  select id into v_customer_id from public.customers where phone = customer_phone;
  if v_customer_id is null then
    raise exception 'Клиент табылмады: %', customer_phone;
  end if;

  select id into v_store_id from public.stores where slug = store_slug;
  if v_store_id is null then
    raise exception 'Дүкен табылмады: %', store_slug;
  end if;

  insert into public.orders (customer_id, store_id, payment)
  values (v_customer_id, v_store_id, pay)
  returning id into v_order_id;

  -- Бағаны клиенттен алмаймыз, products кестесінен аламыз
  insert into public.order_items (order_id, product_id, quantity, unit_price)
  select v_order_id, p.id, (item ->> 'quantity')::integer, p.price
  from jsonb_array_elements(items) as item
  join public.products p on p.id = (item ->> 'product_id')::bigint;

  get diagnostics v_count = row_count;
  if v_count <> jsonb_array_length(items) then
    raise exception 'Кейбір тауарлар табылмады: %', items;
  end if;

  return v_order_id;
end;
$$;

--   declare ... begin ... end   plpgsql функциясының құрылымы
--   select ... into v_...       нәтижені айнымалыға сақтау
--   raise exception             қате шығарып, бәрін тоқтату (транзакция кері қайтады)
--   jsonb_array_elements        JSON массивті жолдарға жаяды
--   get diagnostics             соңғы команда неше жолға әсер еткенін білу
--
-- Сынап көріңіз. Бұл деректі өзгертеді, сондықтан жаңа query бетінде
-- сынақ режимінде орындаңыз (5-сабақтағы begin / rollback):
--
--   begin;
--     select create_order(
--       '+77000000009',                              -- Бауыржан К.
--       'symbat',
--       jsonb_build_array(jsonb_build_object(
--         'product_id', (select id from products where name = 'Аспалы шам Ay'),
--         'quantity',   2))
--     );
--     select * from order_summary order by id desc limit 1;
--   rollback;
--
-- Жоқ тауармен шақырсаңыз, қате шығады және orders-қа да ештеңе жазылмайды:
--   select create_order('+77000000009', 'symbat', '[{"product_id": 999, "quantity": 1}]');
--
-- Supabase JS (JSON массивті тікелей жібересіз):
--   supabase.rpc('create_order', {
--     customer_phone: '+77000000009',
--     store_slug: 'symbat',
--     items: [{ product_id: 16, quantity: 2 }]
--   })


-- ---------------------------------------------------------------------
-- 8.6. trigger: updated_at бағанын автоматты жаңарту
-- ---------------------------------------------------------------------
-- Жол өзгерген сайын "соңғы өзгерген уақыт" өзі жазылсын.
alter table products add column updated_at timestamptz not null default now();

create function set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();   -- new — сақталғалы тұрған жаңа жол
  return new;
end;
$$;

create trigger products_set_updated_at
before update on products
for each row
execute function set_updated_at();

--   returns trigger    триггерге арналған функция
--   before update      жол сақталмас БҰРЫН іске қосылады, new-ді өзгертуге болады
--   for each row       өзгерген әр жол үшін бір рет
--
-- Тексеру (бұл сұрауды кейін жеке орындаңыз). Баға өзгермейді, бірақ
-- жол "жаңарды", сондықтан updated_at жаңа уақытты көрсетеді:
update products
set price = price
where name = 'Кресло Aru' and color = 'Коньяк'
returning name, color, created_at, updated_at;

-- Supabase-та бұл үшін дайын moddatetime кеңейтімі (extension) де бар:
-- Database → Extensions → moddatetime.


-- =====================================================================
--  ТАПСЫРМАЛАР · шешімдері sheshimder.sql файлында
-- =====================================================================
-- Тапсырма 8-1. customer_stats view-ын жасаңыз (security_invoker = on):
--   клиенттің аты, қаласы, тапсырыс саны мен жалпы сомасы (екеуі де бас
--   тартылғандарсыз) және соңғы тапсырыс күні. Тапсырысы жоқ клиенттер де
--   шықсын.
--
-- Тапсырма 8-2. products_by_category(category_slug text) функциясын
--   жазыңыз: берілген санаттың тауарларын бағасы бойынша қайтарсын.
--   Тексеру: select * from products_by_category('armchair');
--
-- Тапсырма 8-3. order_total(target_id bigint) функциясы: тапсырыстың
--   сомасын (quantity * unit_price қосындысы) қайтарсын.
--   Ойланыңыз: параметрді неге order_id деп атамаған дұрыс?
--
-- Тапсырма 8-4. order_items кестесіне before insert триггерін жазыңыз:
--   unit_price жазылмаса (null), тауардың қазіргі бағасы өзі қойылсын.
--   Сынақ режимінде тексеріңіз.
--
-- Тапсырма 8-5. (сынақ режимінде) create_order арқылы Бауыржан К.-ға
--   zeta дүкенінен тапсырыс жасаңыз: 1 кресло Aru (Графит) және
--   2 төсек жинағы Tun, бөліп төлеумен. order_summary-ден тексеріңіз.
-- =====================================================================
