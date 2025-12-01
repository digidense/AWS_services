data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/lambda"
  output_path = "${path.root}/handler.zip"
}

resource "aws_lambda_function" "securityhub_export" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = var.lambda_function_name
  role          = var.lambda_role_arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  timeout       = 120
  memory_size   = 512

  environment {
    variables = {
      S3_BUCKET            = var.bucket_name
      SNS_TOPIC_ARN        = var.sns_topic_arn
      PRESIGNED_EXPIRATION = "86400"
    }
  }
}
