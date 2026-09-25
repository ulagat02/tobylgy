-- =====================================================================
--  1-САБАҚ · КЕСТЕ ҚҰРУ (CREATE TABLE)
-- =====================================================================
--  Не үйренесіз:
--    • кесте, баған, жол деген не
--    • Postgres дерек түрлері: text, integer, boolean, timestamptz ...
--    • шектеулер: primary key, not null, unique, default, check
--    • сыртқы кілт (foreign key): екі кестені байланыстыру
--    • alter table: дайын кестені өзгерту
--    • Supabase-қа тән қадам: RLS қосу
--
--  Қалай орындау: Supabase → SQL Editor → New query → осы файлды толық
--  көшіріп қойыңыз → Run (Ctrl + Enter). Файлды бір рет орындайсыз.
--
--  Оқу үшін бөлек, бос Supabase жобасын ашыңыз. Файлды қайта орындасаңыз,
--  "already exists" (бұрыннан бар) қатесі шығады, бұл қалыпты жағдай.
--  Басынан бастау үшін 99_tazalau.sql файлын орындаңыз.
--
--  SQL жазудың 3 ережесі:
--    1) Әр команда нүктелі үтірмен ( ; ) аяқталады.
--    2) "--" белгісінен кейінгі мәтін — түсініктеме, Postgres оны оқымайды.
--    3) Кілт сөздерді (CREATE, SELECT ...) үлкен не кіші әріппен жазуға
--       болады. Бұл курста кіші әріппен жазамыз, Supabase құжаттарындағыдай.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1.1. Алғашқы кесте: categories (тауар санаттары)
-- ---------------------------------------------------------------------
-- Кесте Excel парағына ұқсайды: бағандары (columns) алдын ала анықталады,
-- ал жолдары (rows) — нақты жазбалар. Әр бағанның аты мен дерек түрі бар.

create table categories (
  id   bigint generated always as identity primary key,
  slug text not null unique,
  name text not null
);

-- Жол-жолымен:
--   id bigint generated always as identity
--        бүтін сан, әр жаңа жолға Postgres өзі береді: 1, 2, 3 ...
--   primary key
--        бастапқы кілт: жолдың бірегей нөмірі, ешқашан қайталанбайды
--   slug text not null unique
--        'sofa' сияқты қысқа латын атау (сілтемеге ыңғайлы).
--        not null — бос болмайды, unique — қайталанбайды
--   name text not null
--        адамға көрінетін атау: 'Дивандар'


-- ---------------------------------------------------------------------
-- 1.2. Postgres-тегі негізгі дерек түрлері
-- ---------------------------------------------------------------------
--   text          мәтін, ұзындығы шектелмейді          'Диван Tamir'
--   integer       бүтін сан (шамамен ±2 миллиард)      1450000
--   bigint        өте үлкен бүтін сан (id үшін)        9007199254740991
--   numeric(2,1)  дәл ондық сан: барлығы 2 цифр,       4.9
--                 біреуі үтірден кейін
--   boolean       иә / жоқ                             true, false
--   timestamptz   күн + уақыт + уақыт белдеуі          '2026-09-25 14:30+05'
--   date          тек күн                              '2026-09-25'
--   uuid          ұзын бірегей идентификатор           Supabase Auth қолданушысының id-і
--   jsonb         JSON дерек                           '{"size": "180x200"}'
--
-- Supabase кеңесі: уақыт үшін әрдайым timestamptz алыңыз (timestamp емес),
-- ол уақыт белдеуін ескереді.


-- ---------------------------------------------------------------------
-- 1.3. stores (дүкендер): default және check
-- ---------------------------------------------------------------------
create table stores (
  id         bigint generated always as identity primary key,
  slug       text not null unique,
  name       text not null,
  city       text not null default 'Қызылорда',
  address    text,
  phone      text,
  rating     numeric(2,1) check (rating between 0 and 5),
  created_at timestamptz not null default now()
);

--   default 'Қызылорда'  қала жазылмаса, осы мән өзі тұрады
--   address text         not null жоқ, демек бос (NULL) бола алады
--   check (...)          шарт: рейтинг тек 0 мен 5 аралығында
--   default now()        жол қосылған сәттегі уақыт өзі жазылады


-- ---------------------------------------------------------------------
-- 1.4. products (тауарлар): сыртқы кілт (foreign key)
-- ---------------------------------------------------------------------
-- Әр тауар бір санатқа жатады. Санаттың атауын әр тауарға қайта жазбай,
-- тек оның id-ін сақтаймыз. references — "бұл сан categories кестесінде
-- бар id болуы керек" деген ереже. Жоқ санатқа тауар қосу мүмкін емес.

create table products (
  id          bigint generated always as identity primary key,
  category_id bigint not null references categories (id),
  name        text not null,
  color       text not null,
  price       integer not null check (price > 0),
  old_price   integer,
  in_stock    boolean not null default true,
  badge       text check (badge in ('hit', 'new')),
  created_at  timestamptz not null default now(),
  unique (name, color),
  check (old_price > price)
);

--   price      баға, теңгемен. Тиын қолданбаймыз, сондықтан integer.
--   old_price  жеңілдікке дейінгі баға. Жеңілдік жоқ болса — NULL.
--   in_stock   true — қоймада бар, false — тапсырыспен (10–14 күн).
--   badge      сайттағы белгі: 'hit' (Хит) не 'new' (Жаңа), болмаса NULL.
--   unique (name, color)       бір модельдің бір түсі бір-ақ рет жазылады.
--   check (old_price > price)  ескі баға жаңасынан қымбат болуы керек.
--     old_price NULL болса, шарт тексерілмейді: NULL — "мәні белгісіз".


-- ---------------------------------------------------------------------
-- 1.5. Кестеге түсініктеме (Supabase Table Editor-да көрінеді)
-- ---------------------------------------------------------------------
comment on table categories is 'Тауар санаттары';
comment on table stores     is 'Дүкендер';
comment on table products   is 'Тауарлар: әр түсі жеке жол';


-- ---------------------------------------------------------------------
-- 1.6. Supabase-қа тән қадам: Row Level Security (RLS)
-- ---------------------------------------------------------------------
-- Supabase public схемасындағы кестелерді сайт пен қосымшаға API арқылы
-- ашады. RLS қосылмаған кестені anon кілті бар кез келген адам оқып,
-- өзгерте алады. Сондықтан ереже: public-те кесте құрдыңыз ба, бірден
-- RLS қосыңыз.
--
-- RLS қосулы, бірақ рұқсат беретін саясат (policy) әлі жоқ болса, API
-- ештеңе қайтармайды. SQL Editor бәрін көреді, себебі ол postgres
-- рөлімен жұмыс істейді. Саясаттарды 9-сабақта жазамыз.

alter table categories enable row level security;
alter table stores     enable row level security;
alter table products   enable row level security;


-- ---------------------------------------------------------------------
-- 1.7. alter table: дайын кестені өзгерту
-- ---------------------------------------------------------------------
alter table products add column description text;         -- жаңа баған қосу
alter table products add column weight_kg integer;         -- тағы бір баған
alter table products rename column weight_kg to weight;    -- атын өзгерту
alter table products drop column weight;                   -- бағанды өшіру

-- Кестені толық өшіру: drop table products;
-- Абай болыңыз: кесте ішіндегі деректерімен бірге жойылады.


-- ---------------------------------------------------------------------
-- 1.8. Тексеру: не құрылды?
-- ---------------------------------------------------------------------
-- information_schema — Postgres-тің өзі туралы ақпарат сақтайтын схема.
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('categories', 'stores', 'products')
order by table_name, ordinal_position;

-- Supabase-та: сол жақ мәзірдегі Table Editor-ды ашыңыз, үш кесте тұр.


-- =====================================================================
--  ТАПСЫРМАЛАР · өзіңіз жазыңыз, шешімдері sheshimder.sql файлында
-- =====================================================================
-- Тапсырма 1-1. products кестесіне warranty_months (кепілдік, ай)
--   бағанын қосыңыз: бүтін сан, міндетті (not null), әдепкі мәні 24,
--   теріс сан болмасын.
--
-- Тапсырма 1-2. suppliers (жеткізушілер) кестесін құрыңыз:
--     id          identity, бастапқы кілт
--     name        мәтін, міндетті
--     phone       мәтін, қайталанбайды
--     country     мәтін, әдепкі мәні 'Қазақстан'
--     created_at  уақыт, әдепкі мәні now()
--   RLS қосуды ұмытпаңыз.
--
-- Тапсырма 1-3. information_schema.columns арқылы тек products кестесінің
--   бағандарын шығарыңыз: атауы, түрі, бос бола ала ма.
--
-- Тапсырма 1-4. Ойланыңыз: price бағанына неге text емес, integer алдық?
-- =====================================================================
