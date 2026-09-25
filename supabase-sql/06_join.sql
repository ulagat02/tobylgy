-- =====================================================================
--  6-САБАҚ · КЕСТЕЛЕРДІ БІРІКТІРУ (JOIN)
-- =====================================================================
--  Не үйренесіз:
--    • join (inner join): екі кестеде де сәйкесі бар жолдар
--    • бірнеше кестені қатар біріктіру
--    • join + group by: тапсырыс сомасы, дүкен түсімі
--    • left join: сәйкесі жоқ жолдарды да сақтау
--    • "ешқашан болмаған" нәрселерді табу (left join ... is null)
--
--  Қалай орындау: сұрауларды бір-бірден белгілеп орындаңыз.
--  Бұл сабақ деректі өзгертпейді.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 6.1. Алғашқы join: тауар + санат атауы
-- ---------------------------------------------------------------------
-- products кестесінде тек category_id бар. Санаттың атауы categories-те.
-- join екеуін on шарты бойынша "тігеді": p.category_id = c.id
select p.name, p.color, p.price, c.name as category
from products p
join categories c on c.id = p.category_id
order by c.name, p.price;

--   products p   — кестеге қысқа ат (alias) береміз: p.name = products.name
--   join         — inner join-нің қысқа жазылуы
--   on ...       — қай жолдар бір-біріне сәйкес келетінін айтады


-- ---------------------------------------------------------------------
-- 6.2. Үш кесте: тапсырыс + клиент + дүкен
-- ---------------------------------------------------------------------
select o.id, o.created_at, cu.full_name, s.name as store, o.status, o.payment
from orders o
join customers cu on cu.id = o.customer_id
join stores    s  on s.id  = o.store_id
order by o.created_at;


-- ---------------------------------------------------------------------
-- 6.3. Көпке-көп: тапсырыстың ішінде не бар?
-- ---------------------------------------------------------------------
-- orders → order_items → products: аралық кесте арқылы өтеміз.
select o.id as order_id,
       p.name, p.color,
       oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price as line_total
from orders o
join order_items oi on oi.order_id = o.id
join products    p  on p.id = oi.product_id
order by o.id, p.name;


-- ---------------------------------------------------------------------
-- 6.4. join + group by: әр тапсырыстың сомасы
-- ---------------------------------------------------------------------
select o.id, cu.full_name, o.status,
       sum(oi.quantity * oi.unit_price) as total
from orders o
join customers   cu on cu.id = o.customer_id
join order_items oi on oi.order_id = o.id
group by o.id, cu.full_name, o.status
order by total desc;


-- ---------------------------------------------------------------------
-- 6.5. Дүкендердің түсімі (бас тартылған тапсырыстарсыз)
-- ---------------------------------------------------------------------
select s.name as store,
       count(distinct o.id)             as orders,
       sum(oi.quantity * oi.unit_price) as revenue
from stores s
join orders      o  on o.store_id = s.id
join order_items oi on oi.order_id = o.id
where o.status <> 'cancelled'
group by s.id, s.name
order by revenue desc;

-- count(distinct o.id): бір тапсырыста бірнеше тауар болса, join оны
-- бірнеше жолға көбейтеді. distinct әр тапсырысты бір рет санайды.
-- Назар аударыңыз: Tobylğy мұнда жоқ, оның тапсырысы жоқ (6.7-ні қараңыз).


-- ---------------------------------------------------------------------
-- 6.6. left join: сәйкесі жоқ жолдарды да сақтау
-- ---------------------------------------------------------------------
-- inner join екі жақта да сәйкесі барларды ғана қалдырады. left join
-- сол жақтағы (from-дағы) кестенің БАРЛЫҚ жолын сақтайды, сәйкесі
-- болмаса оң жақтың бағандары NULL болады.

-- Әр клиенттің тапсырыс саны (тапсырысы жоқтар да шығады):
select cu.full_name, count(o.id) as orders
from customers cu
left join orders o on o.customer_id = cu.id
group by cu.id, cu.full_name
order by orders desc, cu.full_name;

-- count(o.id) деп жазамыз, count(*) емес: тапсырысы жоқ клиентте o.id
-- NULL болады да, 0 саналады. count(*) оны 1 деп санар еді.


-- ---------------------------------------------------------------------
-- 6.7. "Ешқашан болмаған": left join + is null
-- ---------------------------------------------------------------------
-- Тапсырыс бермеген клиенттер:
select cu.full_name, cu.city
from customers cu
left join orders o on o.customer_id = cu.id
where o.id is null;

-- Тапсырысы жоқ дүкендер:
select s.name
from stores s
left join orders o on o.store_id = s.id
where o.id is null;

-- Тауары жоқ санаттар (2-сабақта қосқан 'Бақ жиһазы'):
select c.name, count(p.id) as products
from categories c
left join products p on p.category_id = c.id
group by c.id, c.name
order by products, c.name;


-- ---------------------------------------------------------------------
-- 6.8. Әр тауардың рейтингі (пікірі жоқтары да)
-- ---------------------------------------------------------------------
select p.name, p.color,
       round(avg(r.rating), 1) as avg_rating,
       count(r.id)             as reviews
from products p
left join reviews r on r.product_id = p.id
group by p.id, p.name, p.color
order by avg_rating desc nulls last, reviews desc;

-- nulls last: пікірі жоқ тауарлардың рейтингі NULL, оларды соңына қоямыз.


-- ---------------------------------------------------------------------
-- 6.9. join шартында қосымша сүзгі: on ... and ...
-- ---------------------------------------------------------------------
-- Әр клиенттің ЖЕТКІЗІЛГЕН тапсырыс саны. Шарт where-де емес, on-да тұр,
-- сондықтан жеткізілген тапсырысы жоқ клиенттер де 0-мен қалады:
select cu.full_name, count(o.id) as delivered
from customers cu
left join orders o on o.customer_id = cu.id and o.status = 'delivered'
group by cu.id, cu.full_name
order by delivered desc, cu.full_name;

-- Салыстырыңыз: шартты where-ге көшірсек, left join inner join-ге
-- айналып кетеді (NULL жолдар where-ден өтпейді):
--   ... left join orders o on o.customer_id = cu.id
--   where o.status = 'delivered' ...


-- ---------------------------------------------------------------------
-- 6.10. Supabase JS-те join қалай жазылады
-- ---------------------------------------------------------------------
-- Supabase сыртқы кілттерді өзі біледі. Байланысқан кестені select
-- ішінде атайсыз:
--   supabase.from('products').select('name, color, price, categories(name)')
--   → [{ name: 'Кресло Aru', color: 'Беж', price: 340000,
--        categories: { name: 'Креслолар' } }, ...]
--
-- Тапсырыс, оның клиенті және құрамы бір сұраумен:
--   supabase.from('orders')
--     .select('id, status, customers(full_name), order_items(quantity, products(name, color))')
--
-- inner join керек болса (тек сәйкесі барлар): categories!inner(name)


-- =====================================================================
--  ТАПСЫРМАЛАР · шешімдері sheshimder.sql файлында
-- =====================================================================
-- Тапсырма 6-1. Әр клиент барлығы қанша ақша жұмсады? Бас тартылған
--   тапсырыстарды есептемеңіз. Көбінен бастап.
--
-- Тапсырма 6-2. Ешқашан тапсырыс берілмеген тауарлар (order_items-та
--   бірде-бір рет кездеспеген).
--
-- Тапсырма 6-3. Әр санаттың атауы, ондағы тауар саны және орташа бағасы.
--   Тауары жоқ санат та шығатын болсын.
--
-- Тапсырма 6-4. Айгерім С. сатып алған барлық тауар: тапсырыс күні,
--   тауар атауы, түсі, саны, бағасы.
--
-- Тапсырма 6-5. Бөліп төлеумен (installment) неше дана қай тауар сатылды?
--   Бас тартылғандарды есептемеңіз.
--
-- Тапсырма 6-6. Пікірлер: клиенттің аты, тауар атауы мен түсі, рейтингі,
--   пікір мәтіні. Ең жаңасы бірінші.
--
-- Тапсырма 6-7. Қай қаланың клиенттері қанша тапсырыс берді? Тапсырыс
--   бермеген қалалар да 0-мен шықсын.
-- =====================================================================
