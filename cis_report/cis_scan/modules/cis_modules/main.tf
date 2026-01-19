#################################################
# IAM Role for Lambda
#################################################
resource "aws_iam_role" "inspector_lambda_role" {
  name = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

#################################################
# IAM Policy for Inspector + S3 + Logs
#################################################
resource "aws_iam_policy" "inspector_lambda_policy" {
  name = var.lambda_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "inspector2:ListCisScans",
          "inspector2:ListFindings",
          "inspector2:GetCisScanReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

#################################################
# Attach Policy to Role
#################################################
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.inspector_lambda_role.name
  policy_arn = aws_iam_policy.inspector_lambda_policy.arn
}

#################################################
# Lambda Function
#################################################
resource "aws_lambda_function" "inspector_cis_lambda" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.inspector_lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300

  filename         = "${path.module}/${var.lambda_zip_file}"
  source_code_hash = filebase64sha256("${path.module}/${var.lambda_zip_file}")

  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name
    }
  }
}
