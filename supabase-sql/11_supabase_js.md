# 11-сабақ · SQL-ден JavaScript-ке: Supabase клиенті

SQL Editor-да жазған сұрауларыңызды сайттан да жібере аласыз. Supabase әр кестеге,
view-ға және функцияға API жасап қояды, ал `supabase-js` кітапханасы сол API-мен
сөйлеседі. Бұл файлда 3–10-сабақтардағы сұраулар JavaScript-те қалай жазылатыны
көрсетілген.

## 1. Қосылу

Жоба мекенжайы (Project URL) мен кілтті Dashboard-тағы **Connect** батырмасынан
не **Project Settings → API Keys** бетінен аласыз. Сайтқа тек **anon** не
**publishable** кілтін қоясыз.

```html
<script type="module">
  import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'

  const supabase = createClient(
    'https://ЖОБА-ID.supabase.co',   // Project URL
    'PUBLISHABLE_НЕ_ANON_КІЛТ'       // сайтқа қоюға болатын ашық кілт
  )
</script>
```

npm арқылы: `npm install @supabase/supabase-js`, сосын
`import { createClient } from '@supabase/supabase-js'`.

> **service_role / secret кілтін браузерге ешқашан қоймаңыз.** Ол RLS-ті айналып
> өтеді, яғни кілтті тапқан адам бүкіл дерекқорды оқып, өшіре алады.
> Сайттағы деректі anon кілті емес, 9-сабақтағы RLS саясаттары қорғайды.

## 2. SQL → supabase-js сөздігі

Әр сұрау `const { data, error } = await ...` түрінде жазылады.

| SQL | supabase-js |
| --- | --- |
| `select name, price from products` | `supabase.from('products').select('name, price')` |
| `where color = 'Ақ'` | `.eq('color', 'Ақ')` |
| `where color <> 'Ақ'` | `.neq('color', 'Ақ')` |
| `where price < 500000` | `.lt('price', 500000)` (сондай-ақ `.lte`, `.gt`, `.gte`) |
| `where price between 300000 and 500000` | `.gte('price', 300000).lte('price', 500000)` |
| `where color in ('Ақ', 'Беж')` | `.in('color', ['Ақ', 'Беж'])` |
| `where color ilike '%емен%'` | `.ilike('color', '%емен%')` |
| `where old_price is null` | `.is('old_price', null)` |
| `where old_price is not null` | `.not('old_price', 'is', null)` |
| `where badge = 'hit' or badge = 'new'` | `.or('badge.eq.hit,badge.eq.new')` |
| `order by price desc` | `.order('price', { ascending: false })` |
| `limit 3` | `.limit(3)` |
| `limit 5 offset 5` | `.range(5, 9)` |
| `select count(*) from products` | `.select('*', { count: 'exact', head: true })` → `count` |
| `join categories` (6-сабақ) | `.select('name, color, categories(name)')` |
| view (8-сабақ) | `supabase.from('product_catalog').select('*')` |
| function (8-сабақ) | `supabase.rpc('products_in_price_range', { min_price: 300000, max_price: 500000 })` |
| `insert ... returning *` | `.insert({ ... }).select()` |
| `update ... where id = 1` | `.update({ ... }).eq('id', 1)` |
| `delete ... where id = 1` | `.delete().eq('id', 1)` |
| `insert ... on conflict (slug) do update` | `.upsert({ ... }, { onConflict: 'slug' })` |

Мысалдар:

```js
// 3-сабақ: қоймадағы 500 000-нан арзан тауарлар, арзанынан бастап
const { data, error } = await supabase
  .from('products')
  .select('name, color, price')
  .eq('in_stock', true)
  .lt('price', 500000)
  .order('price')

// 6-сабақ: тауар + санат атауы (join-ді Supabase сыртқы кілт арқылы өзі табады)
const { data: withCategory } = await supabase
  .from('products')
  .select('name, color, price, categories(name)')
// → [{ name: 'Кресло Aru', color: 'Беж', price: 340000, categories: { name: 'Креслолар' } }, ...]

// Тек 'sofa' санатындағылар: байланысқан кесте бойынша сүзу үшін !inner
const { data: sofas } = await supabase
  .from('products')
  .select('name, color, categories!inner(slug)')
  .eq('categories.slug', 'sofa')

// 4-сабақ: санау
const { count } = await supabase
  .from('products')
  .select('*', { count: 'exact', head: true })
  .eq('in_stock', true)
```

`sum`, `avg` сияқты есептер API-де әдепкі бойынша өшірулі. Оларды view не функция
етіп жасайсыз (8-сабақтағы `order_summary`), сосын жай ғана оқисыз.

## 3. Толық мысал: Tobylğy каталогы Supabase-тен

Қазір `index.html` ішінде тауарлар `PRODUCTS` массивінде қолмен жазылған.
Supabase-пен оларды дерекқордан жүктеуге болады. Бұл бет 8-сабақтағы
`product_catalog` view-ын оқиды (9-сабақтағы саясаттар бойынша каталог бәріне ашық):

```html
<!doctype html>
<meta charset="utf-8">
<title>Tobylğy каталогы</title>
<ul id="list">Жүктелуде…</ul>

<script type="module">
  import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'

  const supabase = createClient('https://ЖОБА-ID.supabase.co', 'PUBLISHABLE_НЕ_ANON_КІЛТ')
  const list = document.getElementById('list')

  const { data, error } = await supabase
    .from('product_catalog')
    .select('name, color, price, in_stock, category')
    .order('price')

  if (error) {
    list.textContent = 'Қате: ' + error.message
  } else {
    list.replaceChildren(...data.map((p) => {
      const li = document.createElement('li')
      li.textContent = `${p.category} · ${p.name} (${p.color}) — ` +
        `${p.price.toLocaleString('ru-RU')} ₸` + (p.in_stock ? '' : ' · тапсырыспен')
      return li
    }))
  }
</script>
```

`innerHTML` орнына `textContent` қолданылған: дерекқордан келген мәтін HTML ретінде
орындалмайды.

## 4. Жүйеге кіру және RLS (9–10-сабақтар)

```js
// Тіркелу. 9-сабақтағы триггер profiles-ке жол қосады, full_name осы жерден алынады.
// Email растау қосулы болса (әдепкі), хаттағы сілтемені басқаннан кейін ғана кіре алады.
await supabase.auth.signUp({
  email: 'dana@example.com',
  password: 'Test-12345',
  options: { data: { full_name: 'Дана Қ.' } },
})

// Кіру
const { error } = await supabase.auth.signInWithPassword({
  email: 'aigerim@example.com',
  password: 'Test-12345',
})

// Таңдаулыға қосу: user_id жібермейміз, оны default auth.uid() қояды
await supabase.from('favorites').insert({ product_id: 1 })

// Менің таңдаулыларым: where жазбаймыз, басқалардың жазбасын RLS өзі жасырады
const { data: favorites } = await supabase
  .from('favorites')
  .select('created_at, products(name, color, price)')

// Менің тапсырыстарым (8-сабақтағы view, security_invoker арқасында тек өзімдікі)
const { data: myOrders } = await supabase
  .from('order_summary')
  .select('id, created_at, store, status, total')
  .order('created_at')

// Шығу
await supabase.auth.signOut()
```

Шыққаннан кейін дәл сол сұраулар бос массив қайтарады: қолданушы енді `anon`,
ал `favorites` пен `orders` кестелерінде anon үшін саясат жоқ.

## 5. Функцияны шақыру (rpc)

```js
// 8-сабақ: баға аралығындағы тауарлар. Нәтижені әрі қарай сүзіп, сұрыптауға болады.
const { data } = await supabase
  .rpc('products_in_price_range', { min_price: 300000, max_price: 500000 })
  .select('name, color, price')
  .order('price', { ascending: false })

// 9.7-де create_order-дан anon мен authenticated рұқсатын алып тастадық,
// сондықтан сайттан шақырсаңыз, қате қайтарады:
const { error } = await supabase.rpc('create_order', {
  customer_phone: '+77000000001',
  store_slug: 'zetta',
  items: [{ product_id: 16, quantity: 1 }],
})
// error.message → 'permission denied for function create_order'
```

Мұндай функцияны сервердегі кодтан (мысалы, Supabase Edge Function ішінен)
service_role кілтімен шақырасыз.
