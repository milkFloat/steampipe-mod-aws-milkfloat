dashboard "milkfloat_engineer_dashboard" {
  title = "milkFloat Engineer Dashboard"

     table {
      title = "Account Details"
      width = 14
      sql = <<-EOQ
     SELECT
        aws_account.account_id AS "Account ID",
        aws_account.account_aliases ->> 0 AS "Alias",
        aws_account.organization_id AS "Organization ID",
        aws_account.organization_master_account_email AS "Organization Master Account Email",
        aws_account.organization_master_account_id AS "Organization Master Account ID",
        aws_account.arn AS "ARN",
        policy_data.policy_type,
        policy_data.policy_status
     FROM
        aws_account
    LEFT JOIN
    (SELECT
        organization_id,
        policy ->> 'Type' AS policy_type,
        policy ->> 'Status' AS policy_status
    FROM
        aws_account
    CROSS JOIN
        jsonb_array_elements(organization_available_policy_types) AS policy) AS policy_data
    ON
        aws_account.organization_id = policy_data.organization_id;

      EOQ
    }
 
}
