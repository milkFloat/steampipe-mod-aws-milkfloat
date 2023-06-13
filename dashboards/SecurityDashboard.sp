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
      and coalesce(last_authenticated, now() - '400 days' :: interval) < now() - (10 || ' days') :: interval;
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
      title = "Regional Activity Summary"
      width = 15
      sql = <<-EOQ
        SELECT
  t1."Region",
  t1."TableCount",
  t2."CertificateCount",
  t3."DynamoDBItemCount",
  t4."Snapshots",
  t5."EBSSnapshotVolumeSize (GB)",
  t6."ApiGatewayV2 API's",
  project_count."Codebuild Projects",
  trail_count."Regional Trails",
  codecommit_count."CodeCommit Repos",
  volume_count."EBS Volumes",
  volume_size."Total EBS Volume Size (GB)",
  instance_count."EC2 Instances",
  ecr_count."ECR Repositories",
  cluster_count."Clusters"
FROM
  (SELECT
    region as "Region",
    count(*) as "TableCount"
  FROM
    aws_dynamodb_table
  GROUP BY
    region) t1
JOIN
  (SELECT
    region as "Region",
    count(*) as "CertificateCount"
  FROM
    aws_acm_certificate
  GROUP BY
    region) t2
ON
  t1."Region" = t2."Region"
JOIN
  (SELECT
    region as "Region",
    sum(item_count) as "DynamoDBItemCount"
  FROM
    aws_dynamodb_table
  GROUP BY
    region) t3
ON
  t1."Region" = t3."Region"
JOIN
  (SELECT
    region as "Region",
    count(*) as "Snapshots"
  FROM
    aws_ebs_snapshot
  GROUP BY
    region) t4
ON
  t1."Region" = t4."Region"
JOIN
  (SELECT
    region as "Region",
    sum(volume_size) as "EBSSnapshotVolumeSize (GB)"
  FROM
    aws_ebs_snapshot
  GROUP BY
    region) t5
ON
  t1."Region" = t5."Region"
JOIN
  (SELECT
    region as "Region",
    count(*) as "ApiGatewayV2 API's"
  FROM
    aws_api_gatewayv2_api
  GROUP BY
    region) t6
ON
  t1."Region" = t6."Region"
JOIN
  (SELECT
    region AS "Region",
    COUNT(*) AS "Codebuild Projects"
  FROM
    aws_codebuild_project
  GROUP BY
    region
  ORDER BY
    region) AS project_count
ON t1."Region" = project_count."Region"
JOIN
  (SELECT
    COUNT(*) AS "Regional Trails"
  FROM
    aws_cloudtrail_trail
  WHERE
    region = home_region
    AND NOT is_multi_region_trail) AS trail_count
ON true
JOIN
  (SELECT
    region AS "Region",
    COUNT(*) AS "CodeCommit Repos"
  FROM
    aws_codecommit_repository
  GROUP BY
    region
  ORDER BY
    region) AS codecommit_count
ON t1."Region" = codecommit_count."Region"
JOIN
  (SELECT
    region AS "Region",
    COUNT(*) AS "EBS Volumes"
  FROM
    aws_ebs_volume
  GROUP BY
    region
  ORDER BY
    region) AS volume_count
ON t1."Region" = volume_count."Region"
JOIN
  (SELECT
    region AS "Region",
    SUM(size) AS "Total EBS Volume Size (GB)"
  FROM
    aws_ebs_volume
  GROUP BY
    region
  ORDER BY
    region) AS volume_size
ON t1."Region" = volume_size."Region"
JOIN
  (SELECT
    region AS "Region",
    COUNT(*) AS "EC2 Instances"
  FROM
    aws_ec2_instance
  GROUP BY
    region) AS instance_count
ON t1."Region" = instance_count."Region"
JOIN
  (SELECT
    region AS "Region",
    COUNT(*) AS "ECR Repositories"
  FROM
    aws_ecr_repository
  GROUP BY
    region
  ORDER BY
    region) AS ecr_count
ON t1."Region" = ecr_count."Region"
JOIN
  (SELECT
    region AS "Region",
    COUNT(*) AS "Clusters"
  FROM
    aws_ecs_cluster
  GROUP BY
    region
  ORDER BY
    region) AS cluster_count
ON t1."Region" = cluster_count."Region"
ORDER BY
  t1."Region";


      EOQ
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
        STRING_AGG(privilege_type, ', ') AS privilege_types
      FROM
        information_schema.table_privileges
      WHERE
        table_schema NOT IN ('information_schema', 'pg_catalog', 'aws')
        AND table_name <> 'table_name'
      GROUP BY
        table_schema,
        table_name,
        grantee
      EOQ
    }
  }
}
