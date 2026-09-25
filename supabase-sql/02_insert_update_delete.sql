-- =====================================================================
--  2-САБАҚ · ДЕРЕК ҚОСУ, ӨЗГЕРТУ, ӨШІРУ (INSERT, UPDATE, DELETE)
-- =====================================================================
--  Не үйренесіз:
--    • insert: жаңа жол қосу (бір жол және бірнеше жол)
--    • returning: қосылған не өзгерген жолды бірден қайтару
--    • update: бар жолды өзгерту
--    • delete: жолды өшіру
--    • upsert (on conflict): "бар болса жаңарт, жоқ болса қос"
--
--  Қалай орындау: файлды толық көшіріп, бір рет Run басыңыз. Бұл файл
--  келесі сабақтарға керек деректерді енгізеді. Содан кейін түсініктемелерді
--  оқып, әр команда не істегенін Table Editor-дан қарап шығыңыз.
--
--  Файлды екінші рет орындамаңыз: unique қатесі шығады. Басынан бастау
--  керек болса: 99_tazalau.sql → 01 → 02.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 2.1. Бір жол қосу
-- ---------------------------------------------------------------------
insert into categories (slug, name)
values ('sofa', 'Дивандар');

-- id-ді жазбаймыз: identity бағанына Postgres нөмірді өзі береді.


-- ---------------------------------------------------------------------
-- 2.2. Бірнеше жолды бір командамен қосу
-- ---------------------------------------------------------------------
insert into categories (slug, name) values
  ('armchair', 'Креслолар'),
  ('table',    'Үстелдер'),
  ('dining',   'Асхана'),
  ('kitchen',  'Ас үй'),
  ('bedroom',  'Жатын бөлме'),
  ('decor',    'Декор');


-- ---------------------------------------------------------------------
-- 2.3. returning: қосылған жолдарды бірден қайтару
-- ---------------------------------------------------------------------
-- Supabase JS-тегі .insert(...).select() дәл осылай жұмыс істейді.
insert into stores (slug, name, address, phone, rating) values
  ('tobylgy', 'Tobylğy', null,                            '+77478399145', 4.9),
  ('zetta',   'Zetta',   'Мұстафа Шоқай к-сі, 49',        '+77716062001', 5.0),
  ('zeta',    'Zeta',    'Astana Plaza, Астана д-лы, 46', '+77051757799', 4.6),
  ('symbat',  'Сымбат',  'Қорқыт Ата к-сі, 82',           '+77475871239', 4.7)
returning id, slug, name, city;

-- city бағанын жазбадық, default 'Қызылорда' өзі тұрды.
-- Tobylğy онлайн дүкен, мекенжайы жоқ, сондықтан address = null.


-- ---------------------------------------------------------------------
-- 2.4. Тауарлар: санат id-ін slug арқылы табу
-- ---------------------------------------------------------------------
-- category_id-ге санаттың нөмірі керек. Нөмірді жаттамай, оны ішкі
-- сұрау (subquery) арқылы табамыз:
--     (select id from categories where slug = 'armchair')  →  мысалы, 2
insert into products (category_id, name, color, price, old_price, in_stock, badge) values
  ((select id from categories where slug = 'armchair'), 'Кресло Aru',           'Беж',             340000, null,    true,  'hit'),
  ((select id from categories where slug = 'armchair'), 'Кресло Aru',           'Коньяк',          360000, null,    false, null),
  ((select id from categories where slug = 'armchair'), 'Кресло Aru',           'Графит',          340000, null,    true,  null),
  ((select id from categories where slug = 'sofa'),     'Диван Tamir',          'Ақ',             1450000, null,    true,  'hit'),
  ((select id from categories where slug = 'sofa'),     'Диван Tamir',          'Графит',         1450000, 1590000, false, null),
  ((select id from categories where slug = 'sofa'),     'Диван Tamir',          'Зәйтүн',         1490000, null,    true,  'new'),
  ((select id from categories where slug = 'table'),    'Кофе үстелдері Duo',   'Емен',            420000, null,    true,  null),
  ((select id from categories where slug = 'table'),    'Кофе үстелдері Duo',   'Жаңғақ',          440000, 490000,  true,  null),
  ((select id from categories where slug = 'dining'),   'Асхана жиынтығы Dala', 'Емен · беж',      890000, null,    true,  'hit'),
  ((select id from categories where slug = 'dining'),   'Асхана жиынтығы Dala', 'Жаңғақ · кэмел',  890000, 1010000, false, null),
  ((select id from categories where slug = 'dining'),   'Асхана жиынтығы Dala', 'Ақ емен',         920000, null,    false, 'new'),
  ((select id from categories where slug = 'kitchen'),  'Ас үй аралы Tas',      'Сұр мәрмәр',     1200000, null,    false, null),
  ((select id from categories where slug = 'kitchen'),  'Ас үй аралы Tas',      'Қара мәрмәр',    1250000, null,    true,  'new'),
  ((select id from categories where slug = 'bedroom'),  'Кереует Ai',           'Сұр велюр',       480000, null,    false, 'new'),
  ((select id from categories where slug = 'decor'),    'Төсек жинағы Tun',     'Көгілдір сұр',     32000, null,    true,  null),
  ((select id from categories where slug = 'decor'),    'Аспалы шам Ay',        'Ақ шар · жез',     45000, null,    true,  null);


-- ---------------------------------------------------------------------
-- 2.5. update: бар жолды өзгерту
-- ---------------------------------------------------------------------
-- where қай жолдарды өзгертетінімізді көрсетеді. 1-сабақта қосқан
-- description бағанын толтырамыз. Бір модельдің барлық түсі бірге жаңарады.
update products set description = 'Табиғи былғары, емен аяқ'                 where name = 'Кресло Aru';
update products set description = 'Мата, бук қаңқа, шезлонгпен'              where name = 'Диван Tamir';
update products set description = 'Тұтас емен, екі биіктік, жұп'             where name = 'Кофе үстелдері Duo';
update products set description = 'Ағаш үстел, жұмсақ орындықтар'            where name = 'Асхана жиынтығы Dala';
update products set description = 'Керамогранит бет, бар орындықтар'         where name = 'Ас үй аралы Tas';
update products set description = 'Жұмсақ бас жағы, велюр, көтергіш механизм' where name = 'Кереует Ai';
update products set description = 'Сатин, 100% мақта, екі кісілік'           where name = 'Төсек жинағы Tun';
update products set description = 'Күңгірт шыны шар, жез ілгіш'              where name = 'Аспалы шам Ay';

-- Бір командамен екі бағанды өзгертеміз. Ақ Tamir диванына жеңілдік:
-- 1 450 000 → 1 390 000, ал ескі баға old_price-қа көшеді.
update products
set old_price = price,
    price     = 1390000
where name = 'Диван Tamir' and color = 'Ақ'
returning name, color, old_price, price;

-- set ішіндегі price — өзгеруге дейінгі (ескі) мән. Сондықтан old_price
-- 1 450 000 болады, ал price жаңа мәнді алады.

-- ЕҢ ҚАУІПТІ ҚАТЕ: where жазылмаса, update пен delete БАРЛЫҚ жолға әсер етеді.
--   update products set price = 0;   ← барлық тауардың бағасы кетер еді
--   (біздің кестеде check (price > 0) бұған жол бермейді)
-- Жақсы әдет: алдымен сол where-мен select жазып, қай жолдар таңдалатынын
-- көріңіз, содан кейін ғана update не delete орындаңыз.


-- ---------------------------------------------------------------------
-- 2.6. delete: жолды өшіру
-- ---------------------------------------------------------------------
-- Сынақ үшін уақытша тауар қосамыз да, оны өшіреміз:
insert into products (category_id, name, color, price)
values ((select id from categories where slug = 'decor'), 'Сынақ тауары', 'Қызыл', 1000);

delete from products
where name = 'Сынақ тауары'
returning id, name;


-- ---------------------------------------------------------------------
-- 2.7. upsert: бар болса жаңарт, жоқ болса қос (on conflict)
-- ---------------------------------------------------------------------
-- slug бірегей (unique). 'decor' бұрыннан бар, сондықтан жаңа жол
-- қосылмайды, тек атауы жаңарады:
insert into categories (slug, name)
values ('decor', 'Декор және жарық')
on conflict (slug) do update set name = excluded.name;

-- 'outdoor' әлі жоқ, сондықтан жаңа жол қосылады. Бұл санатта тауар
-- болмайды, 6-сабақта left join үйренгенде керек болады.
insert into categories (slug, name)
values ('outdoor', 'Бақ жиһазы')
on conflict (slug) do update set name = excluded.name;

-- excluded — қосылмақ болған жолдың мәндері.
-- Supabase JS:  supabase.from('categories').upsert({ slug: 'decor', name: '...' }, { onConflict: 'slug' })


-- ---------------------------------------------------------------------
-- 2.8. Шектеулер жұмыста: төмендегі командалар әдейі ҚАТЕ береді
-- ---------------------------------------------------------------------
-- Бұлар түсініктеме ішінде тұр, сондықтан файлмен бірге орындалмайды.
-- Әрқайсысын жаңа query бетіне көшіріңіз, белгілеп Ctrl + / басыңыз
-- ("--" белгілері алынады), сосын орындап, қате мәтінін оқыңыз:
--
--   insert into products (category_id, name, color, price)
--   values (999, 'Жоқ санат', 'Ақ', 1000);
--   → foreign key қатесі: id-і 999 санат жоқ
--
--   insert into products (category_id, name, color, price)
--   values ((select id from categories where slug = 'sofa'), 'Диван Tamir', 'Ақ', 1000);
--   → unique қатесі: 'Диван Tamir' + 'Ақ' бұрыннан бар
--
--   insert into stores (slug, name, rating) values ('test', 'Тест', 7);
--   → check қатесі: рейтинг 0 мен 5 аралығында болуы керек
--
--   insert into categories (slug) values ('test');
--   → not null қатесі: name бағаны міндетті


-- ---------------------------------------------------------------------
-- 2.9. Нәтиже
-- ---------------------------------------------------------------------
select id, name, color, price, old_price, in_stock, badge
from products
order by id;


-- =====================================================================
--  ТАПСЫРМАЛАР · шешімдері sheshimder.sql файлында
-- =====================================================================
-- Тапсырма 2-1. «Бақ жиһазы» (outdoor) санатына тауар қосыңыз:
--   атауы 'Бақ орындығы Samal', түсі 'Тик', бағасы 95000.
--   returning арқылы id мен created_at-ты шығарыңыз.
--
-- Тапсырма 2-2. Samal орындығының бағасын 10%-ға көтеріңіз.
--   Кеңес: price * 1.1 бөлшек сан береді, round(...) арқылы бүтіндеңіз.
--
-- Тапсырма 2-3. Samal-ға жеңілдік жасаңыз: қазіргі бағасы old_price-қа
--   көшсін, жаңа бағасы 89000 болсын (2.5-тегі Tamir мысалын қараңыз).
--
-- Тапсырма 2-4. Samal-ды тағы бір рет дәл сол түспен қосып көріңіз.
--   Қандай қате шықты? Қай шектеу жұмыс істеді?
--
-- Тапсырма 2-5. Samal-ды өшіріңіз, returning арқылы не өшкенін көріңіз.
--   Міндетті түрде өшіріңіз: келесі сабақтардағы сандар (16 тауар т.б.)
--   сәйкес келуі үшін.
--
-- Тапсырма 2-6. upsert арқылы 'decor' санатының атауын қайтадан
--   'Декор' деп өзгертіңіз.
-- =====================================================================
