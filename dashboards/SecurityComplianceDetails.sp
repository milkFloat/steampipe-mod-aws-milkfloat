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


query "fetch_unauthorised_api_calls" {
    sql = <<-EOQ
        select 
            account_id as "Account Id", 
            state_updated_timestamp as "Updated Timestamp",
            state_reason as "Reason"
        from aws_cloudwatch_alarm
        where title like 'Dev-BLEAGovBaseStandalone-DetectionUnauthorisedAPICallsAlarm%'
        and state_value = 'ALARM'
    EOQ
}

query "fetch_unauthorised_access" {
    sql = <<-EOQ
        select 
            account_id as "Account Id", 
            state_updated_timestamp as "Updated Timestamp",
            state_reason as "Reason"
        from aws_cloudwatch_alarm
        where title like 'Dev-BLEAGovBaseStandalone-DetectionUnauthorizedAttemptsAlarm%'
        and state_value = 'ALARM'
    EOQ
}

dashboard "milkfloat_security_and_compliance_detail" {
    title = "Security and Compliance"

    container {
        table {
            title = "Unauthorised API Calls"
            query = query.fetch_unauthorised_api_calls
        }
    }

    container {
        table {
            title = "Security Hub Failings"
            query = query.security_hub_failings
        }
    }

    container {
        table {
            query = query.fetch_unauthorised_access
            title = "Unauthorised Access"
        }
    }
}