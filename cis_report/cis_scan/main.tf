module "inspector_lambda" {
  source = "./modules/cis_modules"

  s3_bucket_name       = "my-bucket-987668"
  lambda_zip_file      = "lambda_function.zip"
  lambda_function_name = "inspector-cis-report-lambda"
}
