query "deployed_services" {
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
        and dimension_type_1 = 'SERVICE'
        and dimension_type_2 = 'RECORD_TYPE'
        and dimension_1 != 'Tax'
        and dimension_2 not in ('Credit')
        and period_start >= date_trunc('month', current_date - interval '1' month)
        and period_start < date_trunc('month', current_date)
      GROUP BY
        1,2,3,4,5,unit,region),
      account_name as (
        SELECT full_name, linked_account_id 
        FROM aws_account_contact
        )
      SELECT service_name as "Service", account_name.full_name as "Account Provisioned to" 
      FROM costs_this_month
      FULL JOIN account_name 
        ON costs_this_month.account_id=account_name.linked_account_id
      WHERE account_name.full_name != 'milkFloat'
      GROUP BY service_name, account_name.full_name
        EOQ
}

query "security_hub_failings_overview" {
sql = <<-EOQ
        SELECT 'Sandboxes with Security Hub Failings' as label, COUNT(DISTINCT(aws_securityhub_finding.account_id)) as value,
        CASE
        when COUNT(DISTINCT(aws_securityhub_finding.account_id)) > 0 then 'alert'
        else 'ok'
        end as type
          FROM aws_securityhub_finding
        WHERE
          aws_securityhub_finding.account_id != '584676501372' AND
          record_state = 'ACTIVE' and
          compliance_status = 'FAILED'
    EOQ
}

query "iam_users" {
  sql = <<-EOQ
  select name, user_id, account_id, password_last_used from aws_iam_user
  EOQ
}

dashboard "milkFloat_ProductOwner_Dashboard" {
  title = "milkFloat Product Owner Dashboard"

  container {
    card {
      query = query.security_hub_failings_overview
      width = 3
      icon = "feedback"
      title = "Security Hub Failure Overview"
      href = "${dashboard.milkfloat_security_and_compliance_detail.url_path}"
    }
    card {
            query = query.cis_benchmark_percentage
            width = 3
            icon = "security"
            href = "${dashboard.milkfloat_security_and_compliance_detail.url_path}"
            title = "CIS 1.2"
    }
    card {
          label = "Explore Security Metrics Here"
          title = "Security Breakdown"
          value = "Click here"
          icon = "group"
          width = 3
          type = "info"
          href = "${dashboard.milkFloat_Security_Dashboard.url_path}"
    }
    card {
          label = "Explore Cost breakdown by Account"
          title = "Cost Breakdown"
          value = "Click here"
          icon = "group"
          width = 3
          type = "info"
          href = "${dashboard.milkFloat_FinOps_Dashboard_Filter_By_Account.url_path}"
      }
  }
  container {
    width = 4
  input "budget" {
      title = "Set Monthly Budget ($):"
      type  = "text"
      placeholder = "e.g. '500'"
      }
    table {
      query = query.deployed_services
      title = "Deployed Services"
      }
}
  container {
    width = 8
    chart {
        type  = "bar"
        title = "Account Spend this Month"
  
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
    table {
      query = query.iam_users
      title = "IAM Users Overview"
    }
} 
}