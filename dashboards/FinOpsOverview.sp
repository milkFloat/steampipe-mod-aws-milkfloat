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

query "aws_annual_forcasted_total_cost" {
    sql = <<-EOQ
      select SUM(ROUND(CAST(mean_value as numeric), 2)) as value,
      'Annual costs for all accounts (estimated)' as label
      from aws_cost_forecast_monthly
      WHERE account_id != '584676501372'
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
      sql = query.aws_annual_forcasted_total_cost.sql
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