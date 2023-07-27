query "total_monthly_cost_by_account" {
    sql = <<-EOQ
        WITH cost as (
          SELECT linked_account_id, 
            unblended_cost_amount,
            period_end
          FROM aws_cost_by_account_monthly 
          WHERE estimated=true
          ORDER BY period_end desc
        ),
        account_name as (
          SELECT full_name, linked_account_id 
          FROM aws_account_contact
        )
        SELECT account_name.full_name, ROUND(CAST(cost.unblended_cost_amount as numeric), 2) as account_cost_$ 
        FROM cost
        FULL JOIN account_name 
          ON cost.linked_account_id=account_name.linked_account_id
        WHERE account_name.full_name != 'milkFloat'
        GROUP BY account_name.full_name, cost.unblended_cost_amount
        EOQ
}

query "next_month_prediction_based_on_previous_6_month_avg" {
    sql = <<-EOQ
      SELECT ROUND(SUM(CAST(unblended_cost_amount as numeric))/6, 2) as value,
      'Estimated Cost (Monthly)' as label
      FROM aws_cost_by_account_monthly 
      WHERE account_id != '584676501372' 
        and estimated = false
        and period_end <= date_trunc('month', current_date - interval '5' month)
    EOQ
}

query "aws_total_daily_account_cost" {
  sql = <<-EOQ
    SELECT ROUND(CAST(sum(unblended_cost_amount) as numeric), 2) as value,
    'Cost today for all accounts' as label
    FROM aws_cost_by_account_daily 
    WHERE period_start >= date_trunc('day', current_date - interval '1' day)
    AND linked_account_id != '584676501372'
  EOQ
}

query "get_recent_logins_last_3" {
  sql = <<-EOQ
  SELECT timestamp as "Most Recent Logins for Selected Account" 
  FROM aws_cloudwatch_log_event 
  WHERE log_group_name = $1
    AND filter = '{($.eventName = "ConsoleLogin")}' 
    AND timestamp >= now() - interval '7 day'
  ORDER BY timestamp desc LIMIT 3
  EOQ
  param "log" {}
}

query "aws_total_monthly_account_cost" {
  sql = <<-EOQ
    SELECT ROUND(CAST(sum(unblended_cost_amount) as numeric), 2) as value,
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
      ELSE 'north'
    END AS icon
    FROM aws_cost_by_account_monthly 
    WHERE period_start >= date_trunc('month', current_date - interval '0' month)
      AND linked_account_id != '584676501372'
    GROUP BY estimated
  EOQ
}

query "most_expensive_account" {
  sql = <<-EOQ
  WITH expensive_account as (
    SELECT account_id, unblended_cost_amount
      FROM aws_cost_by_account_monthly 
    WHERE period_start >= date_trunc('month', current_date - interval '0' month) 
      AND linked_account_id != '584676501372' and account_id != '584676501372'
    ORDER BY unblended_cost_amount desc
    LIMIT 1
  ), 
  account_name as (
          SELECT full_name, account_id from aws_account_contact
        )
  SELECT CONCAT('Most Expensive Account : $', ROUND(CAST(expensive_account.unblended_cost_amount as numeric), 2)) as label,
    account_name.full_name as value
    FROM expensive_account
    LEFT JOIN account_name 
          ON account_name.account_id=expensive_account.account_id
  EOQ
}

query "cheapest_account" {
  sql = <<-EOQ
  WITH cheapest_account as (
    SELECT account_id, unblended_cost_amount
      FROM aws_cost_by_account_monthly 
    WHERE period_start >= date_trunc('month', current_date - interval '0' month) 
      AND linked_account_id != '584676501372' and account_id != '584676501372'
    ORDER BY unblended_cost_amount asc
    LIMIT 1
  ), 
  account_name as (
    SELECT full_name, account_id from aws_account_contact
    )
  SELECT CONCAT('Cheapest Account : $', ROUND(CAST(cheapest_account.unblended_cost_amount as numeric), 2)) as label,
    account_name.full_name as value
    FROM cheapest_account
    LEFT JOIN account_name 
      ON account_name.account_id=cheapest_account.account_id
  EOQ
}

query "monthly_budget_account_costs" {
    sql = <<-EOQ
        WITH cost as (
            SELECT linked_account_id, 
            unblended_cost_amount,
            period_end
            FROM aws_cost_by_account_monthly 
            WHERE 
              estimated=true
            ORDER BY period_end desc
        ),
        account_name as (
          SELECT full_name, linked_account_id from aws_account_contact
        )
        SELECT account_name.full_name, ROUND(CAST(cost.unblended_cost_amount as numeric), 2) as account_cost, ROUND((CAST($1 as numeric) - CAST(cost.unblended_cost_amount as numeric)), 2) as account_budget FROM cost
        FULL JOIN account_name 
          ON cost.linked_account_id=account_name.linked_account_id
        WHERE account_name.full_name != 'milkFloat'
        GROUP BY account_name.full_name, cost.unblended_cost_amount
        EOQ
        param "budget" {}
}

query "days_completed_this_month" {
  sql = <<-EOQ
  SELECT 'Completed this Month' as label, 
  (current_date - period_start) as value 
  FROM aws_cost_by_account_monthly WHERE estimated = true 
  LIMIT 1 
  EOQ
}


dashboard "milkFloat_FinOps_Dashboard" {
  title = "milkFloat FinOps Dashboard"

  container {
    card {
      query = query.aws_total_daily_account_cost
      width = 3
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
    card {
          label = "Explore Cost breakdown by Account"
          value = "Click here"
          icon = "group"
          width = 3
          type = "info"
          href = "${dashboard.milkFloat_FinOps_Dashboard_Filter_By_Account.url_path}"
      }
  }
  container {
    card {
      width = 6
      sql = query.most_expensive_account.sql
      icon = "trending_up"
    }
    card {
      width = 6
      sql = query.cheapest_account.sql
      icon = "trending_down"
    }
  }
  container{
  container{
    width = 6
    chart {
        type  = "donut"
        title = "Current Month Cost per Account (Hover on segments for cost)"
        sql = query.total_monthly_cost_by_account.sql
        width = 12
    }
  }
  container{
    width = 6
    input "acc" {
      title = "Check Recent Account Logins:"
      width = 12
      query = query.get_account_log_group_name
      }
    table {
            query = query.get_recent_logins_last_3
            width = 12
            args = {
                "log" = self.input.acc.value 
            }
            }
  }
  }
  container {
  container {
    width = 4

    input "budget" {
      title = "Define Monthly Budget to Generate Visualisation ($):"
      width = 12
      type  = "text"
      placeholder = "e.g. '500'. [For Visualisation Only, Unrelated to AWS Budgets]"
      }
      card {
        width = 12
        sql = query.days_completed_this_month.sql
        icon = "pace"
        }
  }

  container {
    width = 8
    chart {
        type  = "bar"
        title = "Account Spend this Month"
        width = 12

        legend {
          display  = "auto"
          position = "top"
        }

        series account_cost {
          title = "Spent this Month"
          color = "blue"
        }
        series account_budget {
          title = "Remaining Budget this month"
          color = "green"
        }
        axes {
        x {
          title {
            value  = "Dollars ($)"
          }
          labels {
            display = "auto"
          }
        }
        }
        query = query.monthly_budget_account_costs
        args = {
                  "budget" = self.input.budget.value 
                  }
                  }
              }
              }
              }