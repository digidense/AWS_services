output "dest_bucket_arn" {
  value = aws_s3_bucket.bucket02-aurorat.arn
}

output "dest_bucket_name" {
  value = aws_s3_bucket.bucket02-aurorat.bucket
}
