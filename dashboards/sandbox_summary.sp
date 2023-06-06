dashboard "milkfloat_placeholder_dashboard" {

  title = "milkFloat Placeholder Dashboard"
  container {
    card {
      sql = <<-EOQ
        select
          count(*) as "Total Buckets"
        from
          aws_s3_bucket
      EOQ
      width = 2
    }
    chart {
    type = "pie"
    title = "AWS S3 Buckets by Region"

    sql = <<-EOQ
      select
          region as Region,
          count(*) as Total
      from
          aws_s3_bucket
      group by
          region
      order by
          Total desc
    EOQ
    }
  }
}