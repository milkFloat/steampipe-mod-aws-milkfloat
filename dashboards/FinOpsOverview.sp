dashboard "milkFloat_FinOps_Dashboard" {
    title = "milkFloat FinOps Dashboard"
    chart {
      type  = "line"
      title = "Next 30 Days Predicted Total Account Cost [$]"
      sql = <<-EOQ
      select to_char(period_end, 'DD-MM-YYYY') as date, ROUND(CAST(mean_value as numeric), 2) as cost from aws_cost_forecast_daily
      where account_id = '981481680619'
      order by period_end asc
      FETCH FIRST 30 ROWS ONLY
      EOQ
      width = 6
      }
    chart {
        type  = "donut"
        title = "Total Monthly Cost per Account (Current Month)"
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
        Select CONCAT('#',account_id), SUM(ROUND(CAST(cost_this_month as numeric), 2)) as account_cost_$ FROM cost GROUP BY account_id
        EOQ
        width = 6
        }
    }