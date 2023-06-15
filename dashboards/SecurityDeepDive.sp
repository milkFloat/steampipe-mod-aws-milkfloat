query "mfa_disabled_accounts" {
    sql = <<-EOQ
        SELECT
            name as "Name",
            account_id as "Account ID", 
            create_date as "Created Date",
            mfa_enabled as "MFA Enabled"
        FROM aws_iam_user
        WHERE mfa_enabled = false
        EOQ
}

query "excessive_permission_accounts" {
  sql = <<-EOQ
    SELECT
      aws_iam_user.name as "Name",
      aws_iam_user.account_id as "Account ID",
      TO_CHAR(aws_iam_user.create_date, 'DD-MM-YYYY') as "Created Date",
      aws_iam_user.inline_policies as "Inline Policies",
      COUNT(*) as "Number of Excessive Permissions"
    FROM
      aws_iam_access_advisor,
      aws_iam_user
    WHERE
      principal_arn = arn
      and coalesce(last_authenticated, now() - '400 days' :: interval) < now() - ($1 || ' days') :: interval
    GROUP BY
      aws_iam_user.name,
      aws_iam_user.account_id,
      aws_iam_user.create_date,
      aws_iam_user.inline_policies
    ORDER BY
      "Number of Excessive Permissions" DESC
  EOQ

    param "threshold_in_days" {}
}

query "total_number_of_excessive_permissions" {
    sql = <<-EOQ
select
  count(*) as value,
  'Excessive Permissions Total' as label,
  case
    when count(*) = 0 then 'ok'
    else 'alert'
  end as type
from
  aws_iam_access_advisor,
  aws_iam_user
where
  principal_arn = arn
  and coalesce(last_authenticated, now() - '400 days' :: interval) < now() - ($1 || ' days') :: interval;
    EOQ
    param "threshold_in_days" {}
}



query "access_keys_older_than_90_days" {
    sql = <<-EOQ
        SELECT
          user_name,
          access_key_1_last_rotated,
          age(access_key_1_last_rotated) AS access_key_1_age,
          access_key_2_last_rotated,
          age(access_key_2_last_rotated) AS access_key_2_age
        FROM
          aws_iam_credential_report
        WHERE
          access_key_1_last_rotated <= (current_date - interval '90' day)
          OR access_key_2_last_rotated <= (current_date - interval '90' day)
        EOQ
}


dashboard "milkFloat_Security_Dashboard_Details" {
    title = "milkFloat Security Dashboard Details"
    container {
        card {
            query = query.number_of_accounts_with_mfa_disabled
            width = 3
        }
        table {
            title = "Accounts with MFA Disabled"
            query = query.mfa_disabled_accounts
            width = 8
        }
    }
    container {
        card {
            query = query.number_of_accounts_with_excessive_permissions
            width = 3
        }
        input "threshold_in_days" {
        title = "Last Authenticated Threshold"
        width = 2

            option "30" {
                label = "More than 30 days ago"
            }
            option "60" {
                label = "More than 60 days ago"
            }
            option "90" {
                label = "More than 90 days ago"
            }
            option "180" {
                label = "More than 180 days ago"
            }
            option "360" {
                label = "More than 360 days ago"
            }
        }
       
    }
    container{
         card {
            query = query.total_number_of_excessive_permissions
            width = 3

              args = {
                threshold_in_days = self.input.threshold_in_days.value
            }
        }
        table {
            title = "Account Permissions"
            query = query.excessive_permission_accounts
            width = 8

            args = {
                threshold_in_days = self.input.threshold_in_days.value
            }
            
        }
    }
    container {
        card {
            query = query.non_compliant_keys
            width = 3
        }
        table {
            title = "Non-Compliant Access Keys (+90 Days)"
            query = query.access_keys_older_than_90_days
            width = 8
        }
    }
    }