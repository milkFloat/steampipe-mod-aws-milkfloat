dashboard "milkFloat_FinOps_Dashboard" {
    title = "milkFloat FinOps Dashboard"
    card {
        sql = <<-EOQ
        select sum(net_unblended_cost_amount) as current_month_total from aws_cost_usage
        where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '1' month)
        and period_start < date_trunc('month', current_date)
        EOQ
    icon  = "text:$"
    width = 2
    title = "This Month Total Cost"
    type = "info"
    }
    chart {
        type  = "bar"
        title = "Top 3 Percentage Cost Increases by Service Since Last Month"
        axes {
        x {
        title {
            value  = "Percentage Cost Change from Previous Month to Current Month (%)"
            }
        }
        y {
        labels {
            display = "always"
            }
            }
        }

        sql = <<-EOQ
        with costs_this_month as (
        select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        ROUND(CAST(net_unblended_cost_amount as numeric), 3) as cost_this_month
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '1' month)
        and period_start < date_trunc('month', current_date)
      group by
        aws_cost_usage.dimension_1, aws_cost_usage.net_unblended_cost_amount),
        costs_one_month_prior as (
      select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        ROUND(CAST(net_unblended_cost_amount as numeric), 3) as cost_last_month
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '2' month)
        and period_start < date_trunc('month', current_date - interval '1' month)
      group by
        aws_cost_usage.dimension_1, aws_cost_usage.net_unblended_cost_amount)
    SELECT costs_this_month.service_name,
    ROUND(NULLIF(costs_this_month.cost_this_month,0) * 100.0 / NULLIF(costs_one_month_prior.cost_last_month,0), 1) AS percent_change
    FROM costs_this_month
    FULL JOIN costs_one_month_prior
        ON costs_this_month.service_name = costs_one_month_prior.service_name    
    ORDER BY percent_change LIMIT 3
    EOQ
  width = 9
}
    table {
    title = "Breakdown of Costs by Service ($)"
    sql = <<-EOQ
    with
    costs_this_month as (
      select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        partition,
        account_id,
        _ctx,
        net_unblended_cost_unit as unit,
        sum(net_unblended_cost_amount) as cost_this_month,
        region
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '1' month)
        and period_start < date_trunc('month', current_date)
      group by
        1,2,3,4,5,unit,region
    ),
     costs_one_month_prior as (
      select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        partition,
        account_id,
        _ctx,
        net_unblended_cost_unit as unit,
        sum(net_unblended_cost_amount) as cost_1_month_ago,
        region
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '2' month)
        and period_start < date_trunc('month', current_date - interval '1' month)
      group by
        1,2,3,4,5,unit,region
    ),
     costs_two_months_prior as (
      select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        partition,
        account_id,
        _ctx,
        net_unblended_cost_unit as unit,
        sum(net_unblended_cost_amount) as cost_2_months_ago,
        region
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '3' month)
        and period_start < date_trunc('month', current_date - interval '2' month)
      group by
        1,2,3,4,5,unit,region
    ),
     costs_three_months_prior as (
      select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        partition,
        account_id,
        _ctx,
        net_unblended_cost_unit as unit,
        sum(net_unblended_cost_amount) as cost_3_months_ago,
        region
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '4' month)
        and period_start < date_trunc('month', current_date - interval '3' month)
      group by
        1,2,3,4,5,unit,region
    ),
     costs_four_months_prior as (
      select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        partition,
        account_id,
        _ctx,
        net_unblended_cost_unit as unit,
        sum(net_unblended_cost_amount) as cost_4_months_ago,
        region
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '5' month)
        and period_start < date_trunc('month', current_date - interval '4' month)
      group by
        1,2,3,4,5,unit,region
    ),
     costs_five_months_prior as (
      select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        partition,
        account_id,
        _ctx,
        net_unblended_cost_unit as unit,
        sum(net_unblended_cost_amount) as cost_5_months_ago,
        region
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '6' month)
        and period_start < date_trunc('month', current_date - interval '5' month)
      group by
        1,2,3,4,5,unit,region
    ),
     costs_six_months_prior as (
      select
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        partition,
        account_id,
        _ctx,
        net_unblended_cost_unit as unit,
        sum(net_unblended_cost_amount) as cost_6_months_ago,
        region
      from
        aws_cost_usage
      where
        granularity = 'MONTHLY'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '7' month)
        and period_start < date_trunc('month', current_date - interval '6' month)
      group by
        1,2,3,4,5,unit,region
    )
    SELECT 
      distinct coalesce(costs_this_month.service,costs_one_month_prior.service,costs_two_months_prior.service,costs_three_months_prior.service,costs_four_months_prior.service, costs_five_months_prior.service, costs_six_months_prior.service) as service,
    CASE
      WHEN ROUND(CAST(costs_this_month.cost_this_month as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_this_month.cost_this_month as numeric), 2)
    END AS cost_this_month,
    CASE
      WHEN ROUND(CAST(costs_one_month_prior.cost_1_month_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_one_month_prior.cost_1_month_ago as numeric), 2)
    END AS cost_1_month_ago,
    CASE 
      WHEN ROUND(CAST(costs_two_months_prior.cost_2_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_two_months_prior.cost_2_months_ago as numeric), 2)
    END AS cost_2_months_ago,
    CASE
      WHEN ROUND(CAST(costs_three_months_prior.cost_3_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_three_months_prior.cost_3_months_ago as numeric), 2)
    END AS cost_3_months_ago,
    CASE
      WHEN ROUND(CAST(costs_four_months_prior.cost_4_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_four_months_prior.cost_4_months_ago as numeric), 2)
    END AS cost_4_months_ago,
    CASE
      WHEN ROUND(CAST(costs_five_months_prior.cost_5_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_five_months_prior.cost_5_months_ago as numeric), 2)
    END AS cost_5_months_ago,
    CASE
      WHEN ROUND(CAST(costs_six_months_prior.cost_6_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_six_months_prior.cost_6_months_ago as numeric), 2)
    END AS cost_6_months_ago
    FROM costs_this_month
    FULL OUTER JOIN costs_one_month_prior ON
      costs_this_month.service = costs_one_month_prior.service
    FULL OUTER JOIN costs_two_months_prior ON
      costs_this_month.service = costs_two_months_prior.service
    FULL OUTER JOIN costs_three_months_prior ON
      costs_this_month.service = costs_three_months_prior.service
    FULL OUTER JOIN costs_four_months_prior ON 
      costs_this_month.service = costs_four_months_prior.service
    FULL OUTER JOIN costs_five_months_prior ON
      costs_this_month.service = costs_five_months_prior.service
    FULL OUTER JOIN costs_six_months_prior ON
      costs_this_month.service = costs_six_months_prior.service
    group by costs_this_month.cost_this_month, costs_one_month_prior.cost_1_month_ago, costs_two_months_prior.cost_2_months_ago, costs_three_months_prior.cost_3_months_ago, costs_four_months_prior.cost_4_months_ago, costs_five_months_prior.cost_5_months_ago, costs_six_months_prior.cost_6_months_ago, costs_this_month.service, costs_one_month_prior.service,
    costs_two_months_prior.service, costs_three_months_prior.service, costs_four_months_prior.service, costs_five_months_prior.service, costs_six_months_prior.service
    EOQ
    }
    }