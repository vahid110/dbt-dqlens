-- A simple model that selects from the demo seed data.
-- In a real project this would be a transformation.

select
    id,
    customer_id,
    amount,
    status,
    email,
    created_at
from {{ source('public', 'orders') }}
