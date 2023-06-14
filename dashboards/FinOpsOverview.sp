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

query "aws_annual_forcasted_total_cost" {
    sql = <<-EOQ
      select SUM(ROUND(CAST(mean_value as numeric), 2)) as value,
      'Annual costs for all accounts (estimated)' as label
      from aws_cost_forecast_monthly
      WHERE account_id != '584676501372'
      AND period_start >= current_date
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


  container {
    card {
      label = "Filter by Account Id"
      icon = "group"
       width = 2
       href  = "${dashboard.milkFloat_FinOps_Dashboard_Filter_By_Account.url_path}"
       type = "info"
       value = ""
    }
  }
}