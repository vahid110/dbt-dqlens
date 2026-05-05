select
    id,
    name,
    email,
    phone,
    signup_source,
    created_at
from {{ source('public', 'customers') }}
