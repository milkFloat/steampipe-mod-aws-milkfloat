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
            name as "Name", 
            account_id as "Account ID", 
            create_date as "Created Date",
            inline_policies as "Inline Policies",
        CASE 
        WHEN jsonb_array_length(inline_policies) > 10 THEN 'true' else 'false' end as "Excessive Permissions" 
        FROM aws_iam_user 
        ORDER BY "Excessive Permissions" desc
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