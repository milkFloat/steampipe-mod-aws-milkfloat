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
        'Percentage Pass' as label,
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
  count(distinct principal_arn) as value,
  'Users With Excessive Permissions' as label,
  case
    when count(principal_arn) = 0 then 'ok'
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
                count(mfa_enabled) as accounts_mfa_disabled_count
            FROM aws_iam_user
            WHERE mfa_enabled = false
        )
        SELECT 
            'Number of Users with MFA disabled' as label,
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
          Count (access_key_1_last_rotated) as number_of_keys
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

query "DetectionUnauthorisedAPICallsAlarm" {
    sql = <<-EOQ
        select count(name),
        case
            when count(name) > 0 then 'alert'
            else 'ok'
        end as type
        from aws_cloudwatch_alarm 
        where title like 'Dev-BLEAGovBaseStandalone-DetectionUnauthorisedAPICallsAlarm%'
        and state_value = 'ALARM'
    EOQ
}

query "DetectionUnauthorizedAttemptsAlarm" {
    sql = <<-EOQ
        select count(name),
        case
            when count(name) > 0 then 'alert'
            else 'ok'
        end as type
        from aws_cloudwatch_alarm 
        where title like 'Dev-BLEAGovBaseStandalone-DetectionUnauthorizedAttemptsAlarm%'
        and state_value = 'ALARM'
    EOQ
}


dashboard "milkFloat_Security_Dashboard" {
    title = "milkFloat Security Dashboard"

    container {
        text {
            value = <<-EOM
                ### Security Compliance and Alerts
            EOM
        }
        card {
            query = query.cis_benchmark_percentage
            width = 2
            icon = "security"
            href = "${dashboard.milkfloat_security_and_compliance_detail.url_path}"
            title = "CIS 1.2"
        }
        card {
            query = query.DetectionUnauthorisedAPICallsAlarm
            width = 2
            icon = "security"
            href = "${dashboard.milkfloat_security_and_compliance_detail.url_path}"
            title = "Unauthorised API Calls"
        }
        card {
            query = query.DetectionUnauthorizedAttemptsAlarm
            width = 2
            icon = "security"
            href = "${dashboard.milkfloat_security_and_compliance_detail.url_path}"
            title = "Unauthorised Attempts"
        }
    }
    container {
        text {
            value = <<-EOM
                ### Account Security
            EOM
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
    }
    table {
        title = "Overview of Access Keys"
        query = query.access_keys_summary
    }
}