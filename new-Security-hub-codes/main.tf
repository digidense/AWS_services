provider "aws" {
  region = var.region
}

# Module for Account B (central SecurityHub export)
module "account_b" {
  source               = "./modules/account_A"
  region               = var.region
  account_a_id         = var.account_a_id
  bucket_name          = var.bucket_name
  sns_email            = var.sns_email
  lambda_function_name = var.lambda_function_name
}

# Module for Account A (forward SecurityHub events)
module "account_a" {
  source                  = "./modules/account_B"
  region                  = var.region
  account_a_profile       = var.account_a_profile
  account_b_id            = var.account_b_id
  account_b_event_bus_arn = module.account_b.account_b_event_bus_arn
}
