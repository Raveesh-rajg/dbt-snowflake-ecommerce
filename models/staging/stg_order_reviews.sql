{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'olist_order_reviews_dataset') }}
),

renamed as (
    select
        -- IDs
        review_id,
        order_id,

        -- Score
        review_score::integer as review_score,

        -- Text content (kept raw; light trim)
        trim(review_comment_title)   as review_comment_title,
        trim(review_comment_message) as review_comment_message,

        -- Timestamps (raw is VARCHAR, cast explicitly)
        review_creation_date::timestamp    as reviewed_at,
        review_answer_timestamp::timestamp as answered_at,

        -- Derived business fields
        case when review_score >= 4 then true else false end as is_positive_review,
        case when review_score <= 2 then true else false end as is_negative_review,

        -- Response time in hours (null if no answer)
        case
            when review_answer_timestamp is null then null
            else datediff('hour',
                          review_creation_date::timestamp,
                          review_answer_timestamp::timestamp)
        end as response_time_hours

    from source
)

select * from renamed