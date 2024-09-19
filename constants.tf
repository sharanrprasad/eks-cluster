# Constant config values.
locals {
  environment = lower(var.ENVIRONMENT)
  environment_names = {
    dev = "dev"
    qa  = "qa"
    stg = "stg"
    prd = "prd"
  }
}