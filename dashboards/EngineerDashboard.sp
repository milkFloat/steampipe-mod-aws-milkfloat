dashboard "milkfloat_engineer_dashboard" {
  title = "milkFloat Engineer Dashboard"

     table {
      title = "Region Activity"
      width = 14
      sql = <<-EOQ
       SELECT
  t.region AS "Region",
  t.tables AS "Tables",
  c.Certificates AS "Certificates",
  d.Count AS "DynamoDB Count",
  s.Snapshots AS "Snapshots",
  s.GB AS "Snapshot GB",
  g.APIs AS "API Gateway APIs",
  tr.RegionalTrails AS "Regional Trails",
  tr.MultiRegionalTrails AS "Multi-Regional Trails",
  proj.Projects AS "Projects",
  repo.Repositories AS "Repositories",
  pipe.Pipelines AS "Pipelines",
  vol.Volumes AS "EBS Volumes",
  vol.GB AS "EBS Volume GB",
  ec2.Instances AS "EC2 Instances",
  ecr.Repositories AS "ECR Repositories",
  ecs.Clusters AS "ECS Clusters"
FROM
  (SELECT
    region,
    COUNT(*) AS "tables"
  FROM
    aws_dynamodb_table
  GROUP BY
    region) AS t
  JOIN (SELECT
    region,
    COUNT(*) AS "Certificates"
  FROM
    aws_acm_certificate
  GROUP BY
    region) AS c ON t.region = c.region
  JOIN (SELECT
    region,
    SUM(item_count) AS "Count"
  FROM
    aws_dynamodb_table
  GROUP BY
    region) AS d ON t.region = d.region
  JOIN (SELECT
    region,
    COUNT(*) AS "Snapshots",
    SUM(volume_size) AS "GB"
  FROM
    aws_ebs_snapshot
  GROUP BY
    region) AS s ON t.region = s.region
  JOIN (SELECT
    region,
    COUNT(*) AS "APIs"
  FROM
    aws_api_gatewayv2_api
  GROUP BY
    region) AS g ON t.region = g.region
  JOIN (SELECT
    region,
    COUNT(*) AS "RegionalTrails"
  FROM
    aws_cloudtrail_trail
  WHERE
    region = home_region
    AND NOT is_multi_region_trail
  GROUP BY
    region) AS tr ON t.region = tr.region
  JOIN (SELECT
    region,
    CASE
      WHEN is_multi_region_trail THEN 'Multi-Regional Trails'
      ELSE 'Regional Trails'
    END AS status,
    COUNT(*) AS "MultiRegionalTrails"
  FROM
    aws_cloudtrail_trail
  WHERE
    region = home_region
  GROUP BY
    region,
    status) AS tr ON t.region = tr.region
  JOIN (SELECT
    region,
    COUNT(*) AS "Projects"
  FROM
    aws_codebuild_project
  GROUP BY
    region) AS proj ON t.region = proj.region
  JOIN (SELECT
    region,
    COUNT(*) AS "Repositories"
  FROM
    aws_codecommit_repository
  GROUP BY
    region) AS repo ON t.region = repo.region
  JOIN (SELECT
    region,
    COUNT(*) AS "Pipelines"
  FROM
    aws_codepipeline_pipeline
  GROUP BY
    region) AS pipe ON t.region = pipe.region
  JOIN (SELECT
    region,
    COUNT(*) AS "Volumes"
  FROM
    aws_ebs_volume
  GROUP BY
    region) AS vol ON t.region = vol.region
  JOIN (SELECT
    region,
    SUM(size) AS "GB"
  FROM
    aws_ebs_volume
  GROUP BY
    region) AS vol ON t.region = vol.region
  JOIN (SELECT
    region,
    COUNT(i.*) AS Instances
  FROM
    aws_ec2_instance AS i
  GROUP BY
    region) AS ec2 ON t.region = ec2.region
  JOIN (SELECT
    region,
    COUNT(*) AS "ECR Repositories"
  FROM
    aws_ecr_repository
  GROUP BY
    region) AS ecr ON t.region = ecr.region
  JOIN (SELECT
    region,
    COUNT(*) AS "Clusters"
  FROM
    aws_ecs_cluster
  GROUP BY
    region) AS ecs ON t.region = ecs.region
ORDER BY
  t.region;

      EOQ
    }
 
}
