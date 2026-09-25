-- =====================================================================
--  7-САБАҚ · КҮРДЕЛІРЕК СҰРАУЛАР
-- =====================================================================
--  Не үйренесіз:
--    • ішкі сұрау (subquery), in, exists / not exists
--    • case: шартқа қарай мән беру
--    • coalesce: NULL орнына басқа мән
--    • with (CTE): ұзын сұрауды қадамдарға бөлу
--    • күн мен уақыт: уақыт белдеуі, date_trunc, interval
--    • терезе функциялары: row_number, rank, sum() over, lag
--
--  Қалай орындау: сұрауларды бір-бірден белгілеп орындаңыз.
--  Бұл сабақ деректі өзгертпейді.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 7.1. Ішкі сұрау (subquery): бір мән қайтаратын
-- ---------------------------------------------------------------------
-- Орташа бағадан қымбат тауарлар. Жақша ішіндегі сұрау бірінші
-- орындалады да, бір сан қайтарады (≈ 746 063).
select name, color, price
from products
where price > (select avg(price) from products)
order by price desc;


-- ---------------------------------------------------------------------
-- 7.2. in (subquery): тізім қайтаратын ішкі сұрау
-- ---------------------------------------------------------------------
-- Кем дегенде бір рет бөліп төлеумен сатып алған клиенттер:
select full_name, city
from customers
where id in (select customer_id from orders where payment = 'installment');


-- ---------------------------------------------------------------------
-- 7.3. exists / not exists: "бар ма, жоқ па?"
-- ---------------------------------------------------------------------
-- Пікірі жоқ тауарлар. Ішкі сұрау әр тауар үшін тексеріледі.
select p.name, p.color
from products p
where not exists (
  select 1 from reviews r where r.product_id = p.id
);

-- 6-сабақтағы left join ... is null тәсілі де осы нәтижені береді.
-- not exists жиі түсініктірек оқылады.


-- ---------------------------------------------------------------------
-- 7.4. case: шартқа қарай мән беру
-- ---------------------------------------------------------------------
select name, color, price,
  case
    when price < 100000  then 'арзан'
    when price < 1000000 then 'орташа'
    else 'қымбат'
  end as price_level
from products
order by price;

-- Сайттағыдай қоймадағы күйі:
select name, color,
  case when in_stock then 'Қоймада бар' else 'Тапсырыспен · 10–14 күн' end as stock
from products;


-- ---------------------------------------------------------------------
-- 7.5. coalesce: NULL орнына басқа мән
-- ---------------------------------------------------------------------
-- coalesce(a, b) — a NULL болмаса a, әйтпесе b.
select name, coalesce(address, 'Онлайн дүкен') as address
from stores;

select name, color, coalesce(badge, '—') as badge
from products;


-- ---------------------------------------------------------------------
-- 7.6. with (CTE): сұрауды қадамдарға бөлу
-- ---------------------------------------------------------------------
-- CTE — сұрау ішіндегі уақытша "кесте". Алдымен әр тапсырыстың сомасын
-- есептейміз, содан кейін сол нәтижеден орташа чекті табамыз.
with order_totals as (
  select order_id, sum(quantity * unit_price) as total
  from order_items
  group by order_id
)
select count(*)          as orders,
       round(avg(total)) as avg_check,
       max(total)        as max_check
from order_totals;

-- Бірнеше CTE қатар жазылады. Орташа чектен жоғары тапсырыстар:
with order_totals as (
  select order_id, sum(quantity * unit_price) as total
  from order_items
  group by order_id
),
average as (
  select avg(total) as avg_total from order_totals
)
select t.order_id, t.total
from order_totals t, average a
where t.total > a.avg_total
order by t.total desc;


-- ---------------------------------------------------------------------
-- 7.7. Күн мен уақыт
-- ---------------------------------------------------------------------
-- Supabase уақытты UTC бойынша көрсетеді. Қызылорда уақыты UTC+5.
-- at time zone уақытты жергілікті сағатқа айналдырады:
select id,
       created_at,
       created_at at time zone 'Asia/Qyzylorda' as local_time,
       created_at::date                         as day,
       extract(month from created_at)           as month
from orders
order by created_at;

-- Уақыт аралығы (interval): күнге қосу, айыру
select now()                     as right_now,
       now() - interval '30 days' as month_ago,
       date '2026-09-25' + 14     as delivery_day;   -- тапсырыспен: 14 күннен кейін

-- Белгілі аралықтағы тапсырыстар (қыркүйек айы):
select id, created_at, status
from orders
where created_at >= '2026-09-01' and created_at < '2026-10-01'
order by created_at;

-- Айлар бойынша түсім: date_trunc күнді айдың басына дейін қысқартады.
select to_char(date_trunc('month', o.created_at), 'YYYY-MM') as month,
       count(distinct o.id)                                 as orders,
       sum(oi.quantity * oi.unit_price)                     as revenue
from orders o
join order_items oi on oi.order_id = o.id
where o.status <> 'cancelled'
group by 1
order by 1;

-- group by 1 — "select-тегі 1-баған бойынша" деген қысқа жазу.


-- ---------------------------------------------------------------------
-- 7.8. Терезе функциялары (window functions)
-- ---------------------------------------------------------------------
-- Агрегат (sum, count) жолдарды бір жолға қысады. Терезе функциясы
-- жолдарды қыспайды: әр жолдың жанына "өз тобы" бойынша есеп қосады.
-- over (...) — "терезе": partition by — топ, order by — топ ішіндегі рет.

-- Әр тауардың бағасы және оның санатындағы орташа баға:
select p.name, p.color, p.price, c.name as category,
       round(avg(p.price) over (partition by p.category_id)) as category_avg
from products p
join categories c on c.id = p.category_id
order by c.name, p.price;

-- rank: әр санаттағы тауарлардың баға бойынша орны
select c.name as category, p.name, p.color, p.price,
       rank() over (partition by p.category_id order by p.price desc) as place
from products p
join categories c on c.id = p.category_id
order by c.name, place;

-- rank тең бағаларға бірдей орын береді (Dala: 1, 2, 2), ал row_number
-- әрқашан 1, 2, 3 деп нөмірлейді.

-- Әр санаттың ең қымбат тауары (терезе функциясы where-де тұра алмайды,
-- сондықтан алдымен CTE ішінде есептеп, сосын сүземіз):
with ranked as (
  select c.name as category, p.name, p.color, p.price,
         rank() over (partition by p.category_id order by p.price desc) as place
  from products p
  join categories c on c.id = p.category_id
)
select category, name, color, price
from ranked
where place = 1
order by price desc;

-- row_number: әр клиенттің тапсырыстарын нөмірлеу (1 — ең біріншісі)
select cu.full_name, o.id as order_id, o.created_at,
       row_number() over (partition by o.customer_id order by o.created_at) as nth
from orders o
join customers cu on cu.id = o.customer_id
order by cu.full_name, nth;

-- sum() over (order by ...): жинақталған (өсіп отыратын) түсім
with monthly as (
  select date_trunc('month', o.created_at) as month,
         sum(oi.quantity * oi.unit_price)  as revenue
  from orders o
  join order_items oi on oi.order_id = o.id
  where o.status <> 'cancelled'
  group by 1
)
select to_char(month, 'YYYY-MM')                  as month,
       revenue,
       sum(revenue) over (order by month)          as running_total,
       revenue - lag(revenue) over (order by month) as vs_prev_month
from monthly
order by month;

-- lag(x) — алдыңғы жолдағы x мәні. Бірінші айда алдыңғы ай жоқ, сондықтан NULL.


-- =====================================================================
--  ТАПСЫРМАЛАР · шешімдері sheshimder.sql файлында
-- =====================================================================
-- Тапсырма 7-1. Ең қымбат тауардың атауы мен түсі (ішкі сұрау арқылы,
--   order by / limit қолданбай).
--
-- Тапсырма 7-2. Бірде-бір пікір қалдырмаған клиенттер (not exists).
--
-- Тапсырма 7-3. Тауарларды 'арзан' / 'орташа' / 'қымбат' деп бөліп
--   (7.4-тегі шекаралар), әр топта неше тауар барын санаңыз.
--
-- Тапсырма 7-4. Әр клиенттің соңғы тапсырысы: клиент аты, тапсырыс id,
--   күні, статусы. row_number қолданыңыз.
--
-- Тапсырма 7-5. Ең көп сатылған 3 тауар (дана саны бойынша, бас тартылған
--   тапсырыстарсыз).
--
-- Тапсырма 7-6. Қыркүйек айындағы тапсырыстар Қызылорда уақытымен:
--   id, жергілікті уақыты (сағат:минут), клиенттің аты.
--   Кеңес: to_char(уақыт, 'HH24:MI')
--
-- Тапсырма 7-7. Әр дүкеннің тапсырыстарын нөмірлеңіз (дүкен ішінде
--   1, 2, 3 ...) және әр тапсырыстың дүкен ішіндегі жинақталған сомасын
--   шығарыңыз.
-- =====================================================================
