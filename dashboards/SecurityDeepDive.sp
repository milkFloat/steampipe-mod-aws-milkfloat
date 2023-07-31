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
          u.name AS "User Name",
          aa.service_name AS "Service",
          aa.service_namespace AS "Service Namespace"
        FROM
          aws_iam_access_advisor AS aa
        JOIN
          aws_iam_user AS u ON aa.principal_arn = u.arn
        JOIN
          aws_account AS a ON u.account_id = a.account_id
        WHERE
          aa.last_authenticated IS NULL
        ORDER BY
          u.name;

  EOQ
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
            title = "Users with MFA Disabled"
            query = query.mfa_disabled_accounts
            width = 8
        }
    }
    container {
        card {
            query = query.number_of_accounts_with_excessive_permissions
            width = 3
        }
        table {
            title = "Account Permissions (Excessive - Not in use)"
            query = query.excessive_permission_accounts
            width = 8            
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