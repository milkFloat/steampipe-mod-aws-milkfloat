query "number_of_accounts" {
  sql = <<-EOQ
    SELECT 'Number of Active Sandboxes' as label , count(account_id) as value from aws_account
    WHERE account_id != '584676501372'
  EOQ
}

query "services_provisioned" {
  sql = <<-EOQ
  WITH
    services_this_month as (
      SELECT
        replace(lower(trim(dimension_1)), ' ', '-') as service,
        account_id
      FROM
        aws_cost_usage
      WHERE
        granularity = 'MONTHLY'
        and account_id != '584676501372'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_1 != 'Tax'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '1' month)
        and period_start < date_trunc('month', current_date)
      GROUP BY
        1,2) 
      SELECT service, count(service) as "Number of Provisions this Month in MilkCrate" from services_this_month group by services_this_month.service
      EOQ
}

query "provisioned_stack" {
  sql = <<-EOQ
  SELECT
    account_id, name, id, status, creation_time, resources
  FROM
    aws_cloudformation_stack;
  EOQ
}

dashboard "milkFloat_Engineer_Dashboard" {
  title = "milkFloat Engineer Dashboard"

  container {
    card {
      query = query.number_of_accounts
      width = 4
      icon = "folder_supervised"
    }
    card {
        label = "Explore Security Issues"
        value = "Click here"
        icon = "shield_lock"
        width = 4
        type = "info"
        href = "${dashboard.milkFloat_Security_Dashboard.url_path}"
    }
    card {
        label = "Explore Account Costs"
        value = "Click here"
        icon = "payments"
        width = 4
        type = "info"
        href = "${dashboard.milkFloat_FinOps_Dashboard.url_path}"
    }
  }
    table {
      title = "Count of Provisioned Services Across Accounts"
      width = 6
      query = query.services_provisioned
        }
    table {
      title = "Provisioned Stacks"
      width = 6
      query = query.provisioned_stack
        }
}