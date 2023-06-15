query "cis_benchmark_percentage" {
    sql = <<-EOQ
        with all_failed as (
            select count(id) as all_failed
            from (
                select id from aws_securityhub_finding where updated_at > date_trunc('day', current_date) and account_id != '584676501372' AND record_state = 'ACTIVE' and compliance_status = 'FAILED' order by updated_at desc
            ) t
        ),
        all_passes as (
            select count(id) as passed_count
            from (
                select id from aws_securityhub_finding where updated_at > date_trunc('day', current_date) and account_id != '584676501372' AND record_state = 'ACTIVE' and compliance_status = 'PASSED' order by updated_at desc
            ) t
        ),
        total_tests as (
            select (all_failed.all_failed + all_passes.passed_count) as total
            from all_failed, all_passes
        ),
        percentage_pass as (
            select round(cast(((cast(all_passes.passed_count as float)) / (cast(total_tests.total as float)) * 100) as numeric), 2) as pass_percent
            from total_tests, all_passes
        )
        select percentage_pass.pass_percent as value, 
        'CIS 1.2 Percentage Pass' as label,
        CASE
            WHEN percentage_pass.pass_percent < 95 THEN 'alert'
            ELSE 'ok'
        END as type
        from percentage_pass
    EOQ
}

query "number_of_accounts_with_excessive_permissions" {
    sql = <<-EOQ
        select
  count(*) as value,
  'Excessive Permissions' as label,
  case
    when count(*) = 0 then 'ok'
    else 'alert'
  end as type
from
  aws_iam_access_advisor,
  aws_iam_user
where
  principal_arn = arn
    EOQ
}

query "number_of_accounts_with_mfa_disabled" {
    sql = <<-EOQ
        WITH number_of_accounts_with_mfa_disabled as (
            SELECT 
                count(*) as accounts_mfa_disabled_count
            FROM aws_iam_user
            WHERE mfa_enabled = false
        )
        SELECT 
            'Number of accounts with MFA disabled' as label,
            number_of_accounts_with_mfa_disabled.accounts_mfa_disabled_count as value,
        CASE
            WHEN number_of_accounts_with_mfa_disabled.accounts_mfa_disabled_count > 0 then 'alert'
            ELSE 'ok'
        end as type
        FROM number_of_accounts_with_mfa_disabled
    EOQ
}

query "access_keys_summary" {
    sql = <<-EOQ
        SELECT 
            access_key_id as "Access Key ID",
            status as "Status",
            create_date as "Created Date",
            access_key_last_used_date as "Key Last Used",
            account_id as "Account"
        FROM aws_iam_access_key
        WHERE (user_name != '' OR user_name IS NOT NULL)
        ORDER BY "Status" asc
        EOQ
}

query "non_compliant_keys" {
    sql = <<-EOQ
    with number_of_accounts as 
    (SELECT
          Count (*) as number_of_keys
        FROM
          aws_iam_credential_report
        WHERE
          access_key_1_last_rotated <= (current_date - interval '90' day)
          OR access_key_2_last_rotated <= (current_date - interval '90' day)
    )
    SELECT 
        'Number of Non Compliant Keys' as label,
        number_of_accounts.number_of_keys as value
    FROM number_of_accounts
        EOQ
}

query "recent_logins" {
    sql = <<-EOQ
    WITH count_logins as (
    SELECT
        event_id AS "Event Id",
        timestamp AS "Timestamp",
        message_json->>'userIdentity' AS "User Identity"
    FROM
        aws_cloudwatch_log_event
    WHERE
        log_group_name = 'Dev-BLEAGovBaseStandalone-LoggingCloudTrailLogGroupEFC12822-Osc3j5K0guqc'
        AND filter = '{($.eventName = "ConsoleLogin")}'
        AND timestamp >= now() - interval '1 month'
    )
    SELECT 
        'Number of Logins' as label, 
        count(*) as value
    FROM count_logins
    EOQ
}


dashboard "milkFloat_Security_Dashboard2" {
    title = "milkFloat Security Dashboard2"

    container {
        card {
            query = query.cis_benchmark_percentage
            width = 2
            icon = "security"
            href = "${dashboard.milkfloat_security_hub_failures.url_path}"
        }
        card {
            query = query.number_of_accounts_with_excessive_permissions
            width = 2
            icon = "group"
            href = "${dashboard.milkFloat_Security_Dashboard_Details.url_path}"
        }
        card {
            query = query.number_of_accounts_with_mfa_disabled
            width = 2
            icon = "group"
            href = "${dashboard.milkFloat_Security_Dashboard_Details.url_path}"
        }
        card {
            query = query.non_compliant_keys
            width = 2
            icon = "key"
            href = "${dashboard.milkFloat_Security_Dashboard_Details.url_path}"
        }
        card {
            query = query.recent_logins
            width = 2
            icon = "login"
            href = "${dashboard.milkFloat_Security_Dashboard_Details.url_path}"
        }
    }
    table {
        title = "Overview of Access Keys"
        query = query.access_keys_summary
    }
}