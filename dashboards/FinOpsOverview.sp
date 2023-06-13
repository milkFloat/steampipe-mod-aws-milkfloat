query "aws_account" {
  sql = <<-EOQ
    select
      full_name as label,
      account_id as value
    from
      aws_account_contact;
  EOQ
}

query "total_monthly_cost_by_account" {
    sql = <<-EOQ
        with cost as (
            select dimension_1 as service_name,
            account_id,
            sum(net_unblended_cost_amount) as cost_this_month
            from aws_cost_usage
            where
                granularity = 'MONTHLY'
                and dimension_type_1 = 'SERVICE'
                and dimension_type_2 = 'RECORD_TYPE'
                and dimension_2 not in ('Credit')
                and period_start >= date_trunc('month', current_date - interval '1' month)
                and period_start < date_trunc('month', current_date)
                group by account_id,1,2
        )
        select CONCAT('#',account_id), SUM(ROUND(CAST(cost_this_month as numeric), 2)) as account_cost_$ FROM cost GROUP BY account_id
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


query "aws_total_daily_account_cost" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as value,
    'Cost today for all accounts' as label
    from aws_cost_by_account_daily 
    where period_start >= date_trunc('day', current_date - interval '1' day)
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
          title = "Next 30 Days Predicted Total Account Cost [$]"
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
  }
}