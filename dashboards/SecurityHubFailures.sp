query "security_hub_failings" {
    sql = <<-EOQ
        select aws_account_contact.full_name as "Account Name", aws_securityhub_finding.account_id as "Account Id", aws_securityhub_finding.title as "Rule Name",
        jsonb_path_query(aws_securityhub_finding.resources, '$[0].Id') as "Effected Resource ARN"
        from aws_securityhub_finding
        join aws_account_contact
            on aws_account_contact.linked_account_id = aws_securityhub_finding.account_id
        where updated_at > date_trunc('day', current_date) and
        aws_securityhub_finding.account_id != '584676501372' AND
        record_state = 'ACTIVE' and
        compliance_status = 'FAILED'
        order by updated_at desc
    EOQ
}

dashboard "milkfloat_security_hub_failures" {
    title = "Security Hub Failures"


    container {
        chart {
            type = "table"
            sql = query.security_hub_failings.sql
        }
    }
}