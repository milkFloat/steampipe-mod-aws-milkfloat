query "aws_account" {
  sql = <<-EOQ
    select
      full_name as label,
      account_id as value
    from
      aws_account_contact
    where full_name != 'milkFloat'
  EOQ
}

query "total_monthly_cost_by_account" {
    sql = <<-EOQ
        with cost as (
            select linked_account_id, 
            unblended_cost_amount,
            period_end
            from aws_cost_by_account_monthly 
            WHERE 
              estimated=true
            ORDER BY period_end desc
        ),
        account_name as (
          select full_name, linked_account_id from aws_account_contact
        )
        SELECT account_name.full_name, SUM(ROUND(CAST(cost.unblended_cost_amount as numeric), 2)) as account_cost_$ FROM cost
        FULL JOIN account_name 
          ON cost.linked_account_id=account_name.linked_account_id
        WHERE account_name.full_name != 'milkFloat'
        GROUP BY account_name.full_name
        EOQ
        }

query "forcasted_30_days" {
    sql = <<-EOQ
        select to_char(period_end, 'DD-MM') as date, 
        ROUND(CAST(mean_value as numeric), 2) as cost 
        from aws_cost_forecast_daily
        where account_id = $1
        order by period_end asc
        LIMIT 30
    EOQ
    param "account_id" {}
}

query "next_month_prediction_based_on_previous_6_month_avg" {
    sql = <<-EOQ
      select ROUND(SUM(CAST(unblended_cost_amount as numeric))/6, 2) as value,
      'Next Month Cost Based on 6 month Rolling Average (estimated)' as label
      from aws_cost_by_account_monthly 
      where account_id != '584676501372' 
        and estimated = false
        and period_end <= date_trunc('month', current_date - interval '5' month)
    EOQ
}

query "aws_total_daily_account_cost" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as value,
    'Cost today for all accounts' as label
    from aws_cost_by_account_daily 
    where period_start >= date_trunc('day', current_date - interval '1' day)
    and linked_account_id != '584676501372'
  EOQ
}

query "aws_total_monthly_account_cost" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as value,
    CASE
      WHEN estimated = true then 'info'
      ELSE 'plain'
    END AS type,
    CASE
      WHEN estimated = true then 'Monthly costs for all accounts (estimated)'
      ELSE 'Monthly costs for all accounts'
    END AS label,
    CASE
      WHEN round(cast(sum(unblended_cost_amount) as numeric), 2) < 500 then 'south'
      else 'north'
    END AS icon
    from aws_cost_by_account_monthly 
    where period_start >= date_trunc('month', current_date - interval '0' month)
    and linked_account_id != '584676501372'
    group by estimated
  EOQ
}

query "aws_total_monthly_account_cost_by_account_id" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as value,
    'Monthly costs for a single account' as label
    from aws_cost_by_account_monthly 
    where period_start >= date_trunc('month', current_date - interval '0' month)
    and account_id = $1
  EOQ
  param "account_id" {}
}

query "aws_total_daily_account_cost_by_account_id" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as value,
    'Cost today for a single account' as label
    from aws_cost_by_account_daily 
    where period_start >= date_trunc('day', current_date - interval '1' day)
    and account_id = $1
  EOQ
  param "account_id" {}
}


query "aws_last_30_days_daily_cost_for_account" {
  sql = <<-EOQ
    select to_char(period_start, 'DD-MM') as day, 
    round(cast(unblended_cost_amount as numeric), 2) as cost 
    from aws_cost_by_account_daily 
    where account_id = $1 
    order by period_start desc 
    limit 30
  EOQ
  param "account_id" {}
}

query "WIP" {
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
        and account_id = $1 
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
        and account_id = $1 
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
        and account_id = $1 
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
        and account_id = $1 
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
        and account_id = $1 
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
        and account_id = $1 
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
        and account_id = $1 
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
    END AS "Cost This Month ($)",
    CASE
      WHEN ROUND(CAST(costs_one_month_prior.cost_1_month_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_one_month_prior.cost_1_month_ago as numeric), 2)
    END AS "Cost 1 Months Ago ($)",
    CASE 
      WHEN ROUND(CAST(costs_two_months_prior.cost_2_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_two_months_prior.cost_2_months_ago as numeric), 2)
    END AS "Cost 2 Months Ago ($)",
    CASE
      WHEN ROUND(CAST(costs_three_months_prior.cost_3_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_three_months_prior.cost_3_months_ago as numeric), 2)
    END AS "Cost 3 Months Ago ($)",
    CASE
      WHEN ROUND(CAST(costs_four_months_prior.cost_4_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_four_months_prior.cost_4_months_ago as numeric), 2)
    END AS "Cost 4 Months Ago ($)",
    CASE
      WHEN ROUND(CAST(costs_five_months_prior.cost_5_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_five_months_prior.cost_5_months_ago as numeric), 2)
    END AS "Cost 5 Months Ago ($)",
    CASE
      WHEN ROUND(CAST(costs_six_months_prior.cost_6_months_ago as numeric), 2) IS NULL THEN '0'
      ELSE ROUND(CAST(costs_six_months_prior.cost_6_months_ago as numeric), 2)
    END AS "Cost 6 Months Ago ($)"
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
    order by "Cost This Month ($)" desc
    LIMIT 10
    EOQ
    param "account_id" {}
    }



dashboard "milkFloat_FinOps_Dashboard" {
    title = "milkFloat FinOps Dashboard"

  container {
    card {
      query = query.aws_total_daily_account_cost
      width = 2
      icon = "attach_money"
    }

    card {
      query = query.aws_total_monthly_account_cost
      width = 3
    }

    card {
      width = 3
      sql = query.next_month_prediction_based_on_previous_6_month_avg.sql
      icon = "attach_money"
      }

    chart {
        type  = "donut"
        title = "Total Monthly Cost per Account (Current Month)"
        sql = query.total_monthly_cost_by_account.sql
        width = 6
    }
  }

  input "account_id" {
      title = "Filter by account"
      type  = "select"
      width = 2
      sql  = query.aws_account.sql
    }

  container {
    card {
      query = query.aws_total_daily_account_cost_by_account_id
      width = 2
      icon = "attach_money"
      args = {
        "account_id" = self.input.account_id.value 
      }
    }

    card {
      query = query.aws_total_monthly_account_cost_by_account_id
      width = 3
      icon = "attach_money"
      args = {
        "account_id" = self.input.account_id.value 
      }
    }

    container {
      chart {
        type = "line"
        axes {
          x {
            title {
              value = "Day"
            }
          }
          y {
            title {
              value = "Cost ($)"
            }
          }
        }
        title = "Account Last 30 Days Daily Usage"
        query = query.aws_last_30_days_daily_cost_for_account
        args = {
          "account_id" = self.input.account_id.value
        }
      }
    }

    container {
        chart {
          type  = "line"
          title = "Next 30 Days Predicted Total Account Cost"
          query = query.forcasted_30_days
          axes {
            x {
              title {
                value = "Day"
              }
            }
            y {
              title {
                value = "Cost ($)"
              }
            }
          }
          args = {
              "account_id" = self.input.account_id.value
          }
      }
    }
    container {
      table {
        title = "Cost Breakdown of Provisioned Services"
        query = query.WIP
        args = {
              "account_id" = self.input.account_id.value
        }
    }
    }
  }
}