query "aws_total_daily_account_cost_by_account_id" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as "Estimated cost today for this account"
    from aws_cost_by_account_daily 
    where period_start >= date_trunc('day', current_date - interval '1' day)
    and account_id = $1
  EOQ
  param "account_id" {}
}

query "aws_total_monthly_account_cost_by_account_id" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as "Estimated monthly costs for this account"
    from aws_cost_by_account_monthly 
    where period_start >= date_trunc('month', current_date - interval '0' month)
    and account_id = $1
  EOQ
  param "account_id" {}
}

query "aws_60_days" {
  sql = <<-EOQ
  WITH temp as(
    WITH t1 as (
      SELECT to_char(period_end, 'DD-MM') as day, period_start, 
        ROUND(CAST(mean_value as numeric), 2) as cost 
        FROM aws_cost_forecast_daily
        WHERE account_id = $1
        ORDER BY period_end asc
        LIMIT 30
        ), 
      t2 as (
      SELECT TO_CHAR(period_start, 'DD-MM') as day, period_start, 
        ROUND(CAST(unblended_cost_amount as numeric), 2) as cost 
        FROM aws_cost_by_account_daily 
        WHERE account_id = $1
        ORDER BY period_start desc 
        LIMIT 30
        )
    SELECT * FROM t1 
    UNION 
    SELECT * from t2
    ORDER BY period_start asc
    )
  SELECT day, cost from temp
  EOQ
  param "account_id" {}
}


query "cost_by_service" {
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
        and dimension_1 != 'Tax'
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
        and dimension_1 != 'Tax'
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
        and dimension_1 != 'Tax'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '3' month)
        and period_start < date_trunc('month', current_date - interval '2' month)
      group by
        1,2,3,4,5,unit,region
    )
    SELECT 
      distinct coalesce(costs_this_month.service,costs_one_month_prior.service,costs_two_months_prior.service) as service,
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
    END AS "Cost 2 Months Ago ($)"
    FROM costs_this_month
    FULL OUTER JOIN costs_one_month_prior ON
      costs_this_month.service = costs_one_month_prior.service
    FULL OUTER JOIN costs_two_months_prior ON
      costs_this_month.service = costs_two_months_prior.service
    group by costs_this_month.cost_this_month, costs_one_month_prior.cost_1_month_ago, costs_two_months_prior.cost_2_months_ago, costs_this_month.service, costs_one_month_prior.service,
    costs_two_months_prior.service
    order by "Cost This Month ($)" desc
    LIMIT 10
    EOQ
    param "account_id" {}
}


dashboard "milkFloat_FinOps_Dashboard_Filter_By_Account" {
    title = "FinOps Dashboard - Filter By Account"

    container {
        input "account_id" {
            width = 2
            title = "Account Id"
            type  = "select"
            query = query.fetch_account_id_input
        }
    }


    container {
        card {
            query = query.aws_total_daily_account_cost_by_account_id
            width = 3
            icon = "attach_money"
            type = "info"
            args = {
                "account_id" = self.input.account_id.value 
            }
        }

        card {
            query = query.aws_total_monthly_account_cost_by_account_id
            width = 3
            icon = "attach_money"
            type = "info"
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
                            align = "end"
                        }      
                    }
                    y {
                        title {
                            value = "Cost ($)"
                        }
                    }
                }
                title = "Account Daily Usage (Used and Forecasted)"
                query = query.aws_60_days
                args = {
                    "account_id" = self.input.account_id.value
                }
            }
        }
        container {
            chart {
                type = "column"
                axes {
                    y {
                        title {
                            value = "Cost ($)"
                        }
                    }
                }
                grouping = "compare"
                title = "Cost Breakdown of Provisioned Services"
                query = query.cost_by_service
                args = {
                    "account_id" = self.input.account_id.value
                }
            }
        }
    }
}