mod "local" {
  title = "milkFloat"
  require {
    mod "github.com/turbot/steampipe-mod-aws-compliance" {
      version = "latest"
    }
    mod "github.com/turbot/steampipe-mod-aws-insights" {
      version = "latest"
    }
    mod "github.com/turbot/steampipe-mod-aws-perimeter" {
      version = "latest"
    }
    mod "github.com/turbot/steampipe-mod-aws-thrifty" {
      version = "latest"
    }
  }
}
