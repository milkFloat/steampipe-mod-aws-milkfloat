query "aws_total_daily_account_cost_by_account_id" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as value,
    'Cost today for this account' as label
    from aws_cost_by_account_daily 
    where period_start >= date_trunc('day', current_date - interval '1' day)
    and account_id = $1
  EOQ
  param "account_id" {}
}

query "aws_total_monthly_account_cost_by_account_id" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as value,
    'Monthly costs for this account' as label
    from aws_cost_by_account_monthly 
    where period_start >= date_trunc('month', current_date - interval '0' month)
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
            width = 2
            icon = "attach_money"
            args = {
                "account_id" = self.input.account_id.value 
            }
        }

        card {
            query = query.aws_total_monthly_account_cost_by_account_id
            width = 2
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