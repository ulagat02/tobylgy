-- =====================================================================
--  ШЕШІМДЕР · барлық тапсырмалардың жауабы
-- =====================================================================
--  Алдымен өзіңіз жазып көріңіз, содан кейін ғана осында қараңыз.
--  Бір есептің бірнеше дұрыс шешімі болуы мүмкін: нәтижесі бірдей болса,
--  сіздің жолыңыз да дұрыс.
--
--  Бұл файлды ТОЛЫҚ ОРЫНДАМАҢЫЗ. Әр шешімді жеке белгілеп орындаңыз.
--  "▸ Жеке орындаңыз" деген жерден кейінгі бөлікті бөлек Run-мен
--  (жақсысы — жаңа query бетінде) орындаңыз.
--
--  begin; ... rollback; — сынақ режимі: нәтиже көрсетіледі, бірақ
--  өзгерістің бәрі кері қайтарылады (5-сабақты қараңыз).
-- =====================================================================


-- =====================================================================
--  1-САБАҚ
-- =====================================================================

-- Тапсырма 1-1
alter table products
  add column warranty_months integer not null default 24
  check (warranty_months >= 0);

-- Тапсырма 1-2
create table suppliers (
  id         bigint generated always as identity primary key,
  name       text not null,
  phone      text unique,
  country    text not null default 'Қазақстан',
  created_at timestamptz not null default now()
);

alter table suppliers enable row level security;
-- Саясат жазылмады, сондықтан бұл кестені API арқылы ешкім оқи алмайды.
-- Security Advisor оны "RLS Enabled No Policy" (INFO) деп көрсетеді:
-- тек әкімшіге арналған кесте үшін бұл қалыпты.

-- Тапсырма 1-3
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'products'
order by ordinal_position;

-- Тапсырма 1-4
-- integer болса:
--   • санмен есептеуге болады: sum(price), avg(price), price * 2
--   • дұрыс салыстырады және сұрыптайды. text ретінде '90000' > '1450000',
--     себебі мәтін әріп-әріппен салыстырылады ('9' > '1')
--   • check (price > 0) сияқты шектеу қоюға болады
--   • қате мән ('бір миллион') жазылмайды
--   • аз орын алады


-- =====================================================================
--  2-САБАҚ
-- =====================================================================

-- Тапсырма 2-1
insert into products (category_id, name, color, price)
values ((select id from categories where slug = 'outdoor'), 'Бақ орындығы Samal', 'Тик', 95000)
returning id, created_at;

-- Тапсырма 2-2
update products
set price = round(price * 1.1)
where name = 'Бақ орындығы Samal'
returning name, price;                     -- 104500

-- Тапсырма 2-3
update products
set old_price = price,
    price     = 89000
where name = 'Бақ орындығы Samal'
returning name, old_price, price;

-- Тапсырма 2-4
-- Мына команда қате береді:
--   insert into products (category_id, name, color, price)
--   values ((select id from categories where slug = 'outdoor'), 'Бақ орындығы Samal', 'Тик', 95000);
--   → duplicate key value violates unique constraint "products_name_color_key"
-- 1-сабақтағы unique (name, color) шектеуі: бір модельдің бір түсі бір-ақ рет.

-- Тапсырма 2-5
delete from products
where name = 'Бақ орындығы Samal'
returning *;

-- Тапсырма 2-6
insert into categories (slug, name)
values ('decor', 'Декор')
on conflict (slug) do update set name = excluded.name;


-- =====================================================================
--  3-САБАҚ
-- =====================================================================

-- Тапсырма 3-1
select name, color, price
from products
where in_stock
order by price;

-- Тапсырма 3-2
select name, color, price
from products
where price between 400000 and 1000000
order by price;

-- Тапсырма 3-3
select name, color
from products
where color ilike '%мәрмәр%';

-- Тапсырма 3-4
select name, color, price
from products
order by price
limit 5;

-- Тапсырма 3-5
select name, color, old_price, price,
       round((old_price - price) * 100.0 / old_price) as discount_pct
from products
where old_price is not null
order by discount_pct desc;

-- Тапсырма 3-6
select name, color, badge, in_stock
from products
where badge = 'new' or not in_stock;

-- Тапсырма 3-7
select name, rating
from stores
where rating >= 4.7
order by rating desc;

-- Тапсырма 3-8
-- 3-бет: алдыңғы 2 беттің 2 × 4 = 8 тауарын өткізіп жібереміз
select id, name, color
from products
order by id
limit 4 offset 8;


-- =====================================================================
--  4-САБАҚ
-- =====================================================================

-- Тапсырма 4-1
select count(*)          as in_stock_count,
       round(avg(price)) as avg_price
from products
where in_stock;

-- Тапсырма 4-2
select badge, count(*) as products
from products
group by badge
order by badge;
-- Иә: group by NULL мәндерді бір топқа жинайды (badge = NULL жолы).

-- Тапсырма 4-3
select name, max(price) as max_price
from products
group by name
having max(price) > 1000000;

-- Тапсырма 4-4
select name,
       max(price) - min(price) as price_gap
from products
group by name
having max(price) - min(price) > 0
order by price_gap desc;

-- Тапсырма 4-5
select sum(old_price - price) as total_saving
from products
where old_price is not null;
-- where-сіз де дұрыс шығады: NULL - сан = NULL, ал sum NULL-ды өткізеді.

-- Тапсырма 4-6
select category_id,
       count(*) filter (where in_stock)     as in_stock,
       count(*) filter (where not in_stock) as on_order
from products
group by category_id
order by category_id;


-- =====================================================================
--  5-САБАҚ
-- =====================================================================

-- Тапсырма 5-1 (сынақ режимі)
begin;
  insert into orders (customer_id, store_id)
  values (
    (select id from customers where phone = '+77000000009'),
    (select id from stores where slug = 'symbat')
  );

  insert into order_items (order_id, product_id, quantity, unit_price)
  values (
    (select id from orders
     where customer_id = (select id from customers where phone = '+77000000009')),
    (select id from products where name = 'Аспалы шам Ay'),
    1,
    (select price from products where name = 'Аспалы шам Ay')
  );

  select *
  from order_items
  where order_id = (select id from orders
                    where customer_id = (select id from customers where phone = '+77000000009'));
rollback;
-- Жаңа тапсырысты customer_id арқылы таптық: Бауыржанның басқа тапсырысы жоқ.
-- Нағыз қосымшада id-ді returning арқылы аласыз (JS: .insert(...).select('id').single())
-- не бәрін бір функцияда жасайсыз (8-сабақтағы create_order).

-- Тапсырма 5-2 (сынақ режимі)
begin;
  delete from orders
  where id = (select min(id) from orders);

  select count(*) as order_items_left from order_items;   -- 16 емес, 15
rollback;
-- order_items.order_id бағанында on delete cascade тұр: тапсырыс өшкенде
-- оның құрамы да бірге өшті.

-- Тапсырма 5-3
-- Жоқ. order_items-тің бастапқы кілті (order_id, product_id): бір тапсырыста
-- бір тауар бір-ақ рет жазылады. Екі диван керек болса, quantity = 2.

-- Тапсырма 5-4
select order_id,
       count(*)      as lines,
       sum(quantity) as units
from order_items
group by order_id
order by order_id;


-- =====================================================================
--  6-САБАҚ
-- =====================================================================

-- Тапсырма 6-1
select cu.full_name,
       sum(oi.quantity * oi.unit_price) as spent
from customers cu
join orders      o  on o.customer_id = cu.id
join order_items oi on oi.order_id = o.id
where o.status <> 'cancelled'
group by cu.id, cu.full_name
order by spent desc;

-- Тапсырма 6-2
select p.name, p.color
from products p
left join order_items oi on oi.product_id = p.id
where oi.product_id is null;

-- Тапсырма 6-3
select c.name             as category,
       count(p.id)        as products,
       round(avg(p.price)) as avg_price
from categories c
left join products p on p.category_id = c.id
group by c.id, c.name
order by products desc, c.name;

-- Тапсырма 6-4
select o.created_at, p.name, p.color, oi.quantity, oi.unit_price
from customers cu
join orders      o  on o.customer_id = cu.id
join order_items oi on oi.order_id = o.id
join products    p  on p.id = oi.product_id
where cu.full_name = 'Айгерім С.'
order by o.created_at;

-- Тапсырма 6-5
select p.name, p.color,
       sum(oi.quantity) as units
from orders o
join order_items oi on oi.order_id = o.id
join products    p  on p.id = oi.product_id
where o.payment = 'installment'
  and o.status <> 'cancelled'
group by p.id, p.name, p.color
order by units desc, p.name;

-- Тапсырма 6-6
-- reviews.customer_id бос бола алады (on delete set null), сондықтан left join.
select coalesce(cu.full_name, 'Аноним') as customer,
       p.name, p.color, r.rating, r.body, r.created_at
from reviews r
join products       p  on p.id = r.product_id
left join customers cu on cu.id = r.customer_id
order by r.created_at desc;

-- Тапсырма 6-7
select cu.city, count(o.id) as orders
from customers cu
left join orders o on o.customer_id = cu.id
group by cu.city
order by orders desc, cu.city;


-- =====================================================================
--  7-САБАҚ
-- =====================================================================

-- Тапсырма 7-1
select name, color, price
from products
where price = (select max(price) from products);

-- Тапсырма 7-2
select cu.full_name
from customers cu
where not exists (
  select 1 from reviews r where r.customer_id = cu.id
);

-- Тапсырма 7-3
select
  case
    when price < 100000  then 'арзан'
    when price < 1000000 then 'орташа'
    else 'қымбат'
  end as price_level,
  count(*) as products
from products
group by price_level
order by min(price);

-- Тапсырма 7-4
with ranked as (
  select cu.full_name, o.id, o.created_at, o.status,
         row_number() over (partition by o.customer_id order by o.created_at desc) as rn
  from orders o
  join customers cu on cu.id = o.customer_id
)
select full_name, id, created_at, status
from ranked
where rn = 1
order by created_at desc;

-- Тапсырма 7-5
select p.name, p.color,
       sum(oi.quantity) as units
from order_items oi
join orders   o on o.id = oi.order_id
join products p on p.id = oi.product_id
where o.status <> 'cancelled'
group by p.id, p.name, p.color
order by units desc, p.name, p.color
limit 3;
-- 3-орында 2 данадан сатылған бірнеше тауар тең тұр. limit солардың біреуін
-- ғана алады, сондықтан order by-ға атауын қостық: нәтиже әр жолы бірдей.
-- Теңдердің бәрін алу керек болса: limit 3 орнына fetch first 3 rows with ties

-- Тапсырма 7-6
select o.id,
       to_char(o.created_at at time zone 'Asia/Qyzylorda', 'HH24:MI') as local_time,
       cu.full_name
from orders o
join customers cu on cu.id = o.customer_id
where o.created_at >= '2026-09-01' and o.created_at < '2026-10-01'
order by o.created_at;

-- Тапсырма 7-7
with totals as (
  select order_id, sum(quantity * unit_price) as total
  from order_items
  group by order_id
)
select s.name                                                               as store,
       o.id,
       o.created_at::date                                                   as day,
       t.total,
       row_number() over (partition by o.store_id order by o.created_at)    as nth,
       sum(t.total)  over (partition by o.store_id order by o.created_at)    as running_total
from orders o
join stores s on s.id = o.store_id
join totals t on t.order_id = o.id
order by s.name, nth;


-- =====================================================================
--  8-САБАҚ
-- =====================================================================

-- Тапсырма 8-1
create view customer_stats
with (security_invoker = on)
as
select cu.id, cu.full_name, cu.city,
       count(distinct o.id) filter (where o.status <> 'cancelled') as orders,
       coalesce(sum(oi.quantity * oi.unit_price)
                filter (where o.status <> 'cancelled'), 0)       as spent,
       max(o.created_at)                                           as last_order_at
from customers cu
left join orders      o  on o.customer_id = cu.id
left join order_items oi on oi.order_id = o.id
group by cu.id, cu.full_name, cu.city;

-- ▸ Жеке орындаңыз:
select * from customer_stats order by spent desc;

-- Тапсырма 8-2
create function products_by_category(category_slug text)
returns setof products
language sql
stable
set search_path = ''
as $$
  select p.*
  from public.products p
  join public.categories c on c.id = p.category_id
  where c.slug = category_slug
  order by p.price;
$$;

-- ▸ Жеке орындаңыз:
select name, color, price from products_by_category('armchair');

-- Тапсырма 8-3
create function order_total(target_id bigint)
returns bigint
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(quantity * unit_price), 0)
  from public.order_items
  where order_id = target_id;
$$;

-- ▸ Жеке орындаңыз:
select id, order_total(id) as total from orders order by id;

-- Параметрді order_id деп атасақ, where order_id = order_id бағанды өзімен
-- салыстырар еді: SQL функцияда аттары бірдей болса, кестенің бағаны басым.
-- Шарт әрқашан true болып, барлық тапсырыстың сомасы шығар еді.

-- Тапсырма 8-4
create function fill_unit_price()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.unit_price is null then
    select price into new.unit_price
    from public.products
    where id = new.product_id;
  end if;
  return new;
end;
$$;

create trigger order_items_fill_unit_price
before insert on order_items
for each row
execute function fill_unit_price();

-- ▸ Жеке орындаңыз (сынақ режимі):
begin;
  insert into order_items (order_id, product_id, quantity)
  values (
    (select min(id) from orders),
    (select id from products where name = 'Аспалы шам Ay'),
    1
  );

  select * from order_items where order_id = (select min(id) from orders);
rollback;
-- unit_price жазбадық, бірақ 45000 болып тұр. not null шектеуі before
-- триггерден КЕЙІН тексеріледі, сондықтан қате шықпады.

-- Тапсырма 8-5 (сынақ режимі)
begin;
  select create_order(
    '+77000000009',
    'zeta',
    jsonb_build_array(
      jsonb_build_object('product_id', (select id from products
                                        where name = 'Кресло Aru' and color = 'Графит'),
                         'quantity', 1),
      jsonb_build_object('product_id', (select id from products
                                        where name = 'Төсек жинағы Tun'),
                         'quantity', 2)
    ),
    'installment'
  );

  select * from order_summary where customer = 'Бауыржан К.';
rollback;


-- =====================================================================
--  9-САБАҚ
-- =====================================================================

-- Тапсырма 9-1
select tablename
from pg_tables
where schemaname = 'public'
  and not rowsecurity;
-- Бос нәтиже — жақсы белгі: барлық кестеде RLS қосулы.

-- Тапсырма 9-2
alter table reviews
  add column user_id uuid default auth.uid()
  references auth.users (id) on delete set null;

create index on reviews (user_id);

create policy "Өз атынан пікір қосады"
on reviews for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Өз пікірін өшіреді"
on reviews for delete
to authenticated
using ((select auth.uid()) = user_id);

-- ▸ Жеке орындаңыз (сынақ режимі): Айгерім пікір қалдырады
begin;
  select set_config('request.jwt.claims',
    json_build_object('sub',  (select id from auth.users where email = 'aigerim@example.com'),
                      'role', 'authenticated')::text,
    true);
  set local role authenticated;

  insert into reviews (product_id, rating, body)
  values ((select id from products where name = 'Кофе үстелдері Duo' and color = 'Жаңғақ'),
          5, 'Жаңғақ түсі диванмен жақсы үйлесті.');

  select r.rating, r.body, r.user_id = auth.uid() as is_mine
  from reviews r
  order by r.created_at desc
  limit 3;
rollback;

-- Тапсырма 9-3
drop policy "Бәрі көре алады" on products;

create policy "Келуші қоймадағыны көреді"
on products for select
to anon
using (in_stock);

create policy "Кірген қолданушы бәрін көреді"
on products for select
to authenticated
using (true);

-- ▸ Жеке орындаңыз:
set local role anon;
select count(*) as anon_sees from products;   -- 10 (16 емес)
reset role;

-- Бұрынғы күйге қайтару:
--   drop policy "Келуші қоймадағыны көреді" on products;
--   drop policy "Кірген қолданушы бәрін көреді" on products;
--   create policy "Бәрі көре алады" on products for select
--   to anon, authenticated using (true);

-- Тапсырма 9-4
create policy "Өз профилін қосады"
on profiles for insert
to authenticated
with check ((select auth.uid()) = id);


-- =====================================================================
--  10-САБАҚ
-- =====================================================================

-- Тапсырма 10-1
select set_config('request.jwt.claims',
  json_build_object('sub',  (select id from auth.users where email = 'erlan@example.com'),
                    'role', 'authenticated')::text,
  true);
set local role authenticated;

select id, created_at, store, status, total
from order_summary
order by created_at;

reset role;
-- 1 тапсырыс: Ерланның 3 шілдедегі тапсырысы.

-- Тапсырма 10-2
set local role anon;
select count(*) as visible_profiles from profiles;
reset role;
-- 0: profiles саясаттары тек authenticated рөліне жазылған, anon-ға
-- ешқандай саясат жоқ.

-- Тапсырма 10-3
select set_config('request.jwt.claims',
  json_build_object('sub',  (select id from auth.users where email = 'aigerim@example.com'),
                    'role', 'authenticated')::text,
  true);
set local role authenticated;

with mine as (
  update profiles set full_name = 'Айгерім Сейітова'
  where id = (select auth.uid())
  returning id
),
others as (
  update profiles set full_name = 'Бұзақы'
  where id <> (select auth.uid())
  returning id
)
select (select count(*) from mine)   as my_rows,       -- 1
       (select count(*) from others) as others_rows;   -- 0

reset role;
-- Айгерім басқалардың профилін көрмейді де, өзгерте де алмайды.
