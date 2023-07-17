query "sample_query" {
  sql = <<-EOQ
    select round(cast(sum(unblended_cost_amount) as numeric), 2) as value,
    'Cost today for all accounts' as label
    from aws_cost_by_account_daily 
    where period_start >= date_trunc('day', current_date - interval '1' day)
    and linked_account_id != '584676501372'
  EOQ
}

dashboard "milkFloat_Engineer_Dashboard" {
  title = "milkFloat Engineer Dashboard"

  container {
    card {
      query = query.sample_query
      width = 3
      icon = "attach_money"
    }
  }
  }