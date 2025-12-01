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
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"          # <--- lambda folder
  output_path = "${path.module}/handler.zip"
}

resource "aws_lambda_function" "securityhub_export" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = var.lambda_function_name      # ex: "securityhub-export"
  role          = module.iam.lambda_role_arn    # from IAM module
  handler       = "handler.lambda_handler"      # inside lambda/handler.py
  runtime       = "python3.9"
  timeout       = 120
  memory_size   = 512

  environment {
    variables = {
      S3_BUCKET            = module.s3.bucket_name
      SNS_TOPIC_ARN        = module.sns.topic_arn
      PRESIGNED_EXPIRATION = "86400"
    }
  }
}


########################
# EVENT RULES MODULE
########################
module "event_rules" {
  source               = "./modules/event_rules"
  lambda_function_arn  = aws_lambda_function.securityhub_export.arn
  lambda_function_name = aws_lambda_function.securityhub_export.function_name
}

