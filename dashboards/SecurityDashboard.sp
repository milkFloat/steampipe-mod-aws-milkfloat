dashboard "milkfloat_security_dashboard" {
  title = "milkFloat Security Dashboard"

  container {
    card {
      width = 4
      sql = <<-EOQ
        SELECT
          CONCAT('MFA Status - [', name, ']') AS label,
          CASE
            WHEN mfa_enabled THEN 'Enabled'
            ELSE 'Disabled'
          END AS value,
          CASE
            WHEN mfa_enabled THEN 'ok'
            ELSE 'alert'
          END AS type
        FROM
          aws_iam_user
      EOQ
    }

    card {
      width = 4
      sql = <<-EOQ
        SELECT
          CONCAT('Excessive Permissions - [', name, ']') AS label,
          CASE
            WHEN jsonb_array_length(inline_policies) > 10 THEN 'Excessive'
            ELSE 'Non Excessive'
          END AS value,
          CASE
            WHEN jsonb_array_length(inline_policies) > 10 THEN 'alert'
            ELSE 'ok'
          END AS type
        FROM
          aws_iam_user
      EOQ
    }

    card {
  sql = <<-EOQ
    SELECT
      'Logging Status' AS label,
      CASE
        WHEN COUNT(*) > 0 THEN 'Logging Stopped'
        ELSE 'Logging Active'
      END AS value,
      CASE
        WHEN COUNT(*) > 0 THEN 'alert'
        ELSE 'ok'
      END AS type
    FROM
      aws_cloudwatch_log_event
    WHERE
      log_group_name = 'Dev-BLEAGovBaseStandalone-LoggingCloudTrailLogGroupEFC12822-Osc3j5K0guqc'
      AND filter = '{($.eventName = "StopLogging")}'
      AND timestamp >= now() - interval '1 month'
  EOQ
  width = 4
}



    table {
      title = "APIs not configured with private endpoints"
      width = 6
      sql = <<-EOQ
        SELECT
          name,
          api_id,
          api_key_source,
          endpoint_configuration_types,
          endpoint_configuration_vpc_endpoint_ids
        FROM
          aws_api_gateway_rest_api
        WHERE
          NOT endpoint_configuration_types ? 'PRIVATE'
      EOQ
    }

    table {
      title = "APIs with policy statements granting external OR anonymous access"
      width = 6
      sql = <<-EOQ
        SELECT
          title,
          p AS principal,
          a AS action,
          s ->> 'Effect' AS effect,
          s -> 'Condition' AS conditions
        FROM
          aws_api_gateway_rest_api,
          jsonb_array_elements(policy_std -> 'Statement') AS s,
          jsonb_array_elements_text(s -> 'Principal' -> 'AWS') AS p,
          jsonb_array_elements_text(s -> 'Action') AS a
        WHERE
          p = '*' AND s ->> 'Effect' = 'Allow'
        UNION ALL
        SELECT
          name,
          p AS principal,
          a AS action,
          s ->> 'Effect' AS effect,
          s -> 'Condition' AS conditions
        FROM
          aws_api_gateway_rest_api,
          jsonb_array_elements(policy_std -> 'Statement') AS s,
          jsonb_array_elements_text(s -> 'Principal' -> 'AWS') AS p,
          string_to_array(p, ':') AS pa,
          jsonb_array_elements_text(s -> 'Action') AS a
        WHERE
          s ->> 'Effect' = 'Allow'
          AND (pa[5] != account_id OR p = '*')
      EOQ
    }

    table {
      title = "Access Key Report"
      width = 6
      sql = <<-EOQ
        SELECT
          *
        FROM
          aws_iam_access_key
        WHERE
          status = 'Active'
          AND (user_name != '' OR user_name IS NOT NULL)
      EOQ
    }

    table {
      title = "Access keys older than 90 days"
      width = 6
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
        ORDER BY
          user_name
      EOQ
    }

    table {
      title = "Recent Logins (Past Month)"
      width = 6
      sql = <<-EOQ
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
        LIMIT 10
      EOQ
    }

    table {
      title = "Password Changes (Past Month)"
      width = 6
      sql = <<-EOQ
        SELECT
          event_id AS "Event Id",
          timestamp AS "Timestamp",
          message_json->>'userIdentity' AS "User Identity"
        FROM
          aws_cloudwatch_log_event
        WHERE
          log_group_name = 'Dev-BLEAGovBaseStandalone-LoggingCloudTrailLogGroupEFC12822-Osc3j5K0guqc'
          AND filter = '{($.eventName = "ChangePassword")}'
          AND timestamp >= now() - interval '1 month'
      EOQ
    }

    table {
      title = "New Users (Past Month)"
      width = 6
      sql = <<-EOQ
        SELECT
          event_id AS "Event Id",
          timestamp AS "Timestamp",
          message_json->>'userIdentity' AS "User Identity"
        FROM
          aws_cloudwatch_log_event
        WHERE
          log_group_name = 'Dev-BLEAGovBaseStandalone-LoggingCloudTrailLogGroupEFC12822-Osc3j5K0guqc'
          AND filter = '{($.eventName = "CreateUser")}'
          AND timestamp >= now() - interval '1 month'
      EOQ
    }

    table {
      title = "Deleted Users (Past Month)"
      width = 6
      sql = <<-EOQ
        SELECT
          event_id AS "Event Id",
          timestamp AS "Timestamp",
          message_json->>'userIdentity' AS "User Identity"
        FROM
          aws_cloudwatch_log_event
        WHERE
          log_group_name = 'Dev-BLEAGovBaseStandalone-LoggingCloudTrailLogGroupEFC12822-Osc3j5K0guqc'
          AND filter = '{($.eventName = "DeleteUser")}'
          AND timestamp >= now() - interval '1 month'
      EOQ
    }

    table {
      title = "Recent Errors Report"
      width = 15
      sql = <<-EOQ
        SELECT
          timestamp,
          message_json->>'eventName' AS "Event Name",
          message_json->>'sourceIPAddress' AS "Source IP Address",
          message_json->>'userAgent' AS "User Agent",
          message_json->>'errorMessage' AS "Error Message",
          message_json->>'requestID' AS "Request ID",
          message_json->>'errorCode' AS "Error Code"
        FROM
          aws_cloudwatch_log_event
        WHERE
          message_json->>'errorMessage' IS NOT NULL
          AND log_group_name = 'Dev-BLEAGovBaseStandalone-LoggingCloudTrailLogGroupEFC12822-Osc3j5K0guqc'
        LIMIT 10
      EOQ
    }

    card {
      width = 10
      title = "AWS Schema Access"
      sql = <<-EOQ
        SELECT
          DISTINCT grantee
        FROM
          information_schema.table_privileges
        WHERE
          table_schema = 'aws'
      EOQ
      type = "table"
    }

    card {
      width = 2
      sql = <<-EOQ
        SELECT
          COUNT(*) AS "(AWS Only) Datasets"
        FROM
          information_schema.tables
        WHERE
          table_schema = 'aws'
      EOQ
      icon = "hashtag"
    }

    

    input "schema_input" {
      width = 4
      sql = <<-EOQ
        SELECT
          table_schema AS label,
          table_schema AS value
        FROM
          information_schema.tables
        WHERE
          table_schema = 'aws'
        GROUP BY
          table_schema
      EOQ
    }

    flow {
      title = "Datasets (aws_schema only)"
      node {
        sql = <<-EOQ
          SELECT
            table_schema AS id,
            table_schema AS title
          FROM
            information_schema.tables
          WHERE
            table_schema = $1
        EOQ
        args = [self.input.schema_input.value]
      }
      node {
        sql = <<-EOQ
          SELECT
            table_name AS id,
            table_name AS title
          FROM
            information_schema.tables
          WHERE
            table_schema = $1
        EOQ
        args = [self.input.schema_input.value]
      }
      edge {
        sql = <<-EOQ
          SELECT
            table_schema AS from_id,
            table_name AS to_id
          FROM
            information_schema.tables
          WHERE
            table_schema = $1
        EOQ
        args = [self.input.schema_input.value]
      }
    }

    table {
      title = "Datasets and Access (Non-AWS)"
      width = 15
      sql = <<-EOQ
        SELECT
          table_schema,
          table_name,
          grantee,
          privilege_type
        FROM
          information_schema.table_privileges
        WHERE
          table_schema NOT IN ('information_schema', 'pg_catalog', 'aws')
          AND table_name <> 'table_name'
        LIMIT 10
      EOQ
    }
  }
}
