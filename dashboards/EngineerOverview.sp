query "number_of_accounts" {
  sql = <<-EOQ
    SELECT 'Number of Sandboxes' as label , count(account_id) as value from aws_account
    WHERE account_id != '584676501372'
  EOQ
}

query "services_provisioned" {
  sql = <<-EOQ
  WITH
    costs_this_month as (
      SELECT
        dimension_1 as service_name,
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        partition,
        account_id,
        _ctx,
        net_unblended_cost_unit as unit,
        sum(net_unblended_cost_amount) as cost_this_month,
        region
      FROM
        aws_cost_usage
      WHERE
        granularity = 'MONTHLY'
        and account_id = $1
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_1 != 'Tax'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '1' month)
        and period_start < date_trunc('month', current_date)
      GROUP BY
        1,2,3,4,5,unit,region) 
      SELECT service from costs_this_month
      EOQ
      param "account_id" {}
}

dashboard "milkFloat_Engineer_Dashboard" {
  title = "milkFloat Engineer Dashboard"

  container {
    card {
      query = query.number_of_accounts
      width = 3
      icon = "folder_supervised"
    }
    card {
        label = "Explore Security Issues"
        value = "Click here"
        icon = "shield_lock"
        width = 3
        type = "info"
        href = "${dashboard.milkFloat_Security_Dashboard.url_path}"
    }
  }
  container {
        input "account_id" {
            width = 4
            title = "Select Account for Engineering breakdown"
            type  = "select"
            query = query.fetch_account_id_input
        } 
        table {
      title = "Provisioned Services for Selected Account"
      width = 7
      query = query.services_provisioned
      args = {
            "account_id" = self.input.account_id.value
            }
        }
  }
}