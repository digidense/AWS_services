########################
# S3 MODULE
########################
module "s3" {
  source      = "./modules/s3"
  bucket_name = var.bucket_name
}

########################
# SNS MODULE
########################
module "sns" {
  source    = "./modules/sns"
  sns_email = var.sns_email
}

########################
# IAM MODULE (for Lambda)
########################
module "iam" {
  source            = "./modules/iam"
  bucket_arn        = module.s3.bucket_arn
  sns_topic_arn     = module.sns.topic_arn
}

########################
# LAMBDA MODULE
########################
module "lambda" {
  source              = "./modules/lambda"
  lambda_function_name = var.lambda_function_name
  bucket_name         = module.s3.bucket_name
  sns_topic_arn       = module.sns.topic_arn
  lambda_role_arn     = module.iam.lambda_role_arn
}

########################
# EVENT RULES MODULE
########################
module "event_rules" {
  source              = "./modules/event_rules"
  lambda_function_arn = module.lambda.lambda_arn
  lambda_function_name = module.lambda.lambda_name
}
