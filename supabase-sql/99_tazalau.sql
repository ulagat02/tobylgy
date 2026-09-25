-- =====================================================================
--  ТАЗАЛАУ · курс жасаған барлық нәрсені өшіру
-- =====================================================================
--  Қашан керек: курсты басынан бастағыңыз келсе не бір сабақ қатемен
--  орындалып, деректер шатасып кетсе. Осы файлды толық орындап, сосын
--  01-ден бастап қайта өтіңіз.
--
--  Тек курс жасаған кестелер, view, функция және триггерлер өшіріледі.
--  Сынақ қолданушыларын (aigerim@example.com т.б.) Authentication → Users
--  бетінен қолмен өшіріңіз.
-- =====================================================================

drop trigger if exists on_auth_user_created on auth.users;

drop view if exists
  public.customer_stats,
  public.order_summary,
  public.product_catalog;

drop table if exists
  public.favorites,
  public.profiles,
  public.reviews,
  public.order_items,
  public.orders,
  public.customers,
  public.products,
  public.stores,
  public.categories,
  public.suppliers
cascade;

drop function if exists
  public.handle_new_user,
  public.create_order,
  public.products_in_price_range,
  public.products_by_category,
  public.monthly_payment,
  public.order_total,
  public.set_updated_at,
  public.fill_unit_price;

-- Тексеру: public схемасында курстан ештеңе қалмауы керек
select table_name, table_type
from information_schema.tables
where table_schema = 'public'
order by table_name;
