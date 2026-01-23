--1.Müşteri Odaklı Sorular:
Olist’ın  en değerli müşterileri kimlerdir?
WITH clv AS (
  SELECT
    c.customer_unique_id,
   ROUND(SUM(oi.price + oi.freight_value),2) AS lifetime_value
  FROM `Olist.olist_customers_dataset` c
  JOIN `Olist.olist_orders_dataset` o ON c.customer_id = o.customer_id
  JOIN `Olist.olist_order_items_dataset` oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
) SELECT *
FROM clv
QUALIFY lifetime_value >= PERCENTILE_CONT(lifetime_value, 0.9) OVER ()
ORDER BY lifetime_value desc
LIMIT 10

Olist’te ortalama müşteri yaşam boyu değeri (CLV) nedir?
SELECT
  c.customer_unique_id,
  COUNT(DISTINCT o.order_id) AS total_orders,
  ROUND(SUM(oi.price + oi.freight_value), 2) AS lifetime_value
FROM `Olist.olist_customers_dataset` c
JOIN `Olist.olist_orders_dataset` o
  ON c.customer_id = o.customer_id
JOIN `Olist.olist_order_items_dataset` oi
  ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;

select * from `durable-tracer-481309-q4.

Müşteriler ne sıklıkla tekrar satın alma yapıyor?
WITH customer_orders AS (
  SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count
  FROM `Olist.olist_customers_dataset` c
  JOIN `Olist.olist_orders_dataset` o
    ON c.customer_id = o.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
)

SELECT
  order_count,
  COUNT(*) AS customer_count
FROM customer_orders
GROUP BY order_count
ORDER BY order_count;

--2.Ürün ve Satış İçgörüleri:
Olist’in en çok satan ürün kategorisi hangileridir?

SELECT
  count(*) as total_units_sold,
  oid.product_id,
  pdn.string_field_1 as category_name,
FROM
  `Olist.olist_order_items_dataset` oid 
  INNER JOIN `Olist.olist_orders_dataset` od on oid.order_id=od.order_id
  INNER JOIN `Olist.olist_product_dataset` pd on oid.product_id=pd.product_id
  INNER JOIN `Olist.olist_product_category_name_translation` pdn on pd.product_category_name=pdn.string_field_0
  where od.order_status='delivered'
GROUP BY
  oid.product_id, category_name
  order by total_units_sold desc
  LIMIT 10

Olist’teki genel gelir trendleri nelerdir?

WITH monthly_revenue AS (
  SELECT
    EXTRACT(YEAR FROM od.order_purchase_timestamp) AS yil,
    EXTRACT(MONTH FROM od.order_purchase_timestamp) AS ay,
    SUM(odt.price) AS monthly_total
  FROM `Olist.olist_orders_dataset` od
  JOIN `Olist.olist_order_items_dataset` odt
    ON od.order_id = odt.order_id
  WHERE od.order_status = 'delivered'
  GROUP BY yil, ay
)
SELECT CONCAT(yil,'-',ay) as year_month,
  yil,
  ay,
  ROUND(monthly_total, 2) AS monthly_total,
  ROUND(
    SUM(monthly_total) OVER (
      PARTITION BY yil
      ORDER BY ay
    ),
    2
  ) AS running_total
FROM monthly_revenue
ORDER BY yil,ay;

Hangi ürün kategorileri gelire en fazla katkıda bulunmaktadır?

SELECT
  t.string_field_1 AS category,
  ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue,
  COUNT(DISTINCT order_id) as total_order
FROM `Olist.olist_order_items_dataset` oi
JOIN `Olist.olist_product_dataset` p
  ON oi.product_id = p.product_id
JOIN `Olist.olist_product_category_name_translation` t
  ON p.product_category_name = t.string_field_0
GROUP BY category
ORDER BY total_revenue DESC;

--3.Operasyonel Verimlilik:
3.1 Olist’te ortalama sipariş teslimat süresi nedir?
SELECT
  ROUND(AVG(DATE_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY)), 2)
  AS avg_delivery_days
FROM `Olist.olist_orders_dataset`
WHERE order_status = 'delivered';

3.2 Belirli satıcılar veya bölgeler teslimat gecikmeleri yaşıyor mu?
3.2.1 rota bazlı gecikme oranları
SELECT CONCAT(s.seller_state,'-',c.customer_state),
  COUNT(DISTINCT o.order_id) AS total_orders,
  ROUND(
    COUNTIF(
      o.order_delivered_customer_date > o.order_estimated_delivery_date
    ) / COUNT(DISTINCT o.order_id) * 100,
    2
  ) AS delay_rate_pct
FROM `Olist.olist_orders_dataset` o
JOIN `Olist.olist_order_items_dataset` oi
  ON o.order_id = oi.order_id
JOIN `Olist.olist_sellers_dataset` s
  ON oi.seller_id = s.seller_id
JOIN `Olist.olist_customers_dataset` c
  ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY s.seller_state, c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 30
ORDER BY delay_rate_pct DESC;

3.2.2alıcı bazlı gecikme yaşayan bölgeler
SELECT
  c.customer_state AS customer_region,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNTIF(
    o.order_delivered_customer_date > o.order_estimated_delivery_date
  ) AS delayed_orders,
  ROUND(
    COUNTIF(
      o.order_delivered_customer_date > o.order_estimated_delivery_date
    ) / COUNT(DISTINCT o.order_id) * 100,
    2
  ) AS delay_rate_pct,
  ROUND(
    AVG(
      DATE_DIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        DAY
      )
    ),
    2
  ) AS avg_delay_days
FROM `Olist.olist_orders_dataset` o
JOIN `Olist.olist_customers_dataset` c
  ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY customer_region
HAVING COUNT(DISTINCT o.order_id) >= 50
ORDER BY delay_rate_pct DESC;

3.2.3 satıcı bazlı gecikme yaşayan bölgeler
SELECT
  s.seller_state AS seller_region,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNTIF(
    o.order_delivered_customer_date > o.order_estimated_delivery_date
  ) AS delayed_orders,
  ROUND(
    COUNTIF(
      o.order_delivered_customer_date > o.order_estimated_delivery_date
    ) / COUNT(DISTINCT o.order_id) * 100,
    2
  ) AS delay_rate_pct,
  ROUND(
    AVG(
      DATE_DIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        DAY
      )
    ),
    2
  ) AS avg_delay_days
FROM `Olist.olist_orders_dataset` o
JOIN `Olist.olist_order_items_dataset` oi
  ON o.order_id = oi.order_id
JOIN `Olist.olist_sellers_dataset` s
  ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY seller_region
HAVING COUNT(DISTINCT o.order_id) >= 50
ORDER BY delay_rate_pct DESC;

3.3 Sipariş durumu müşteri memnuniyetini nasıl etkiliyor?
SELECT
  o.order_status,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNT(r.review_score) AS reviewed_orders,
  ROUND(AVG(r.review_score), 2) AS avg_review_score,
  ROUND(
    COUNTIF(r.review_score <= 2) / COUNT(r.review_score) * 100,
    2
  ) AS low_score_rate_pct
FROM `Olist.olist_orders_dataset` o
LEFT JOIN `Olist.olist_order_reviews_dataset` r
  ON o.order_id = r.order_id
GROUP BY o.order_status
HAVING COUNT(r.review_score) >= 50
ORDER BY avg_review_score DESC;

3.4 Teslim edilmiş ama geç gelen siparişler müşteriyi nasıl etkiliyor?
SELECT
  CASE
    WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
      THEN 'Delivered - Delayed'
    ELSE 'Delivered - On Time'
  END AS delivery_performance,
  COUNT(*) AS total_orders,
  ROUND(AVG(r.review_score), 2) AS avg_review_score,
  ROUND(
    COUNTIF(r.review_score IN (1, 2)) / COUNT(*) * 100,
    2
  ) AS low_score_rate_pct
FROM `Olist.olist_orders_dataset` o
JOIN `Olist.olist_order_reviews_dataset` r
  ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY delivery_performance;

DELETE FROM `Olist.olist_orders_dataset`
WHERE order_id IN (
    SELECT
    order_id
    FROM `Olist.olist_orders_dataset`
    GROUP BY order_id
    HAVING COUNT(*) > 1
);

select * from `Olist.olist_customers_dataset` where customer_city is null

select * from `Olist.olist_order_items_dataset` where price<0

--kategori numaraları olmayan ürünler
select * from `Olist.olist_product_dataset`
where product_category_name is null

select * from `Olist.olist_order_payments_dataset`

    