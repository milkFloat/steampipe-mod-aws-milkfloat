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
    GROUP BY
      aws_iam_user.name,
      aws_iam_user.account_id,
      aws_iam_user.create_date,
      aws_iam_user.inline_policies
    ORDER BY
      "Number of Excessive Permissions" DESC
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
        table {
            title = "Account Permissions"
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