select *
from {{ ref('silver_orders') }}
where total_amount < 0
