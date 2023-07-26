query "get_account_log_group_name" {
  sql = <<-EOQ
    WITH temp as (
      SELECT full_name, linked_account_id 
      FROM aws_account_contact
    )
    SELECT DISTINCT(temp.full_name) as label, 
      log_group_name as value
      FROM aws_cloudwatch_log_metric_filter
    FULL JOIN temp 
      ON temp.linked_account_id=aws_cloudwatch_log_metric_filter.account_id
    WHERE temp.full_name != 'milkFloat'
    EOQ
}

query "number_of_accounts" {
  sql = <<-EOQ
    SELECT 'Number of Active Sandboxes' as label , count(account_id) as value 
    FROM aws_account
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
      FROM aws_cost_usage
      WHERE
        granularity = 'MONTHLY'
        and account_id != '584676501372'
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_1 != 'Tax'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '1' month)
        and period_start < date_trunc('month', current_date)
      GROUP BY 1,2) 
      SELECT service, count(service) as "Number of Provisions this Month in MilkCrate" 
      FROM services_this_month 
      GROUP BY services_this_month.service
      EOQ
}

query "provisioned_stack" {
  sql = <<-EOQ
  SELECT account_id, name, id, status, creation_time, resources
  FROM aws_cloudformation_stack;
  EOQ
}

query "resource_details" {
  sql = <<-EOQ
  SELECT
    account_id as "Account ID",
    identifier as "Resource",
    properties ->> 'MemorySize' as "Memory Size",
    properties ->> 'Runtime' as "Runtime",
    region as "Region"
  FROM aws_cloudcontrol_resource 
  WHERE type_name = 'AWS::Lambda::Function';
  EOQ
}

query "get_recent_logins" {
  sql = <<-EOQ
  SELECT 
  timestamp as "Timestamp" FROM aws_cloudwatch_log_event 
  WHERE log_group_name = $1
    AND FILTER = '{($.eventName = "ConsoleLogin")}' AND timestamp >= now() - interval '7 day'
  EOQ
  param "log" {}
}

dashboard "milkFloat_Engineer_Dashboard" {
  title = "milkFloat Engineer Dashboard"

  container {
    card {
        label = "Explore Security Issues"
        value = "Click here"
        icon = "shield_lock"
        width = 4
        type = "info"
        href = "${dashboard.milkFloat_Security_Dashboard.url_path}"
    }
    card {
      query = query.number_of_accounts
      width = 4
      icon = "folder_supervised"
    }
    input "acc" {
    title = "Check Recent Account Logins:"
    width = 4
    query = query.get_account_log_group_name
    }
  }
  container {
    width = 8
  card {
        label = "Explore Compliance Details"
        value = "Click here"
        icon = "assured_workload"
        width = 6
        type = "info"
        href = "${dashboard.milkfloat_security_and_compliance_detail.url_path}"
    }
  card {
        label = "Explore Account Costs"
        value = "Click here"
        icon = "payments"
        width = 6
        type = "info"
        href = "${dashboard.milkFloat_FinOps_Dashboard.url_path}"
    }
    table {
      title = "Count of Provisioned Services Across Accounts"
      width = 12
      query = query.services_provisioned
        }
  }

  table {
            query = query.get_recent_logins
            title = "Console Logins Last 7 Days"
            width = 4
            args = {
                "log" = self.input.acc.value 
            }
  }
  
    table {
      title = "Provisioned Stacks"
      width = 12
      query = query.provisioned_stack
        }
    table {
      title = "Resource Overview"
      width = 12
      query = query.resource_details
    }
}