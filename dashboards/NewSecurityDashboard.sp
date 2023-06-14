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
        with number_of_excessive_accounts as (
            SELECT 
            count(*) as excessive_accounts
            FROM
            aws_iam_user
            WHERE jsonb_array_length(inline_policies) > 10
        )
        SELECT 'Number of accounts with excessive permissions' as label,
        number_of_excessive_accounts.excessive_accounts as value,
        CASE
            WHEN number_of_excessive_accounts.excessive_accounts > 0 THEN 'alert'
        ELSE 'ok'
        END as type
        from number_of_excessive_accounts
    EOQ
}

query "number_of_accounts_with_mfa_disabled" {
    sql = <<-EOQ
        with number_of_accounts_with_mfa_disabled as (
            select count(*) as accounts_mfa_disabled_count
            from aws_iam_user
            where mfa_enabled = false
        )
        select 'Number of accounts with MFA disabled' as label,
            number_of_accounts_with_mfa_disabled.accounts_mfa_disabled_count as value,
        case
            when number_of_accounts_with_mfa_disabled.accounts_mfa_disabled_count > 0 then 'alert'
            else 'ok'
        end as type
        from number_of_accounts_with_mfa_disabled
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
        }
        card {
            query = query.number_of_accounts_with_mfa_disabled
            width = 2
            icon = "group"
        }
    }
}