query "aws_account" {
  sql = <<-EOQ
    select
      full_name as label,
      account_id as value
    from
      aws_account_contact;
  EOQ
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
              value = "Cost"
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
  }
}