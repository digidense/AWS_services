########################################
# S3 Buckets
########################################

output "dev_bucket_arn" {
  description = "ARN of the DEV S3 bucket"
  value       = aws_s3_bucket.dev_bucket.arn
}

output "uat_bucket_arn" {
  description = "ARN of the UAT S3 bucket"
  value       = aws_s3_bucket.uat_bucket.arn
}

########################################
# DataSync Locations
########################################

output "datasync_source_location_arn_uat" {
  description = "ARN of the UAT S3 DataSync source location"
  value       = aws_datasync_location_s3.source_uat.arn
}

output "datasync_destination_location_arn_dev" {
  description = "ARN of the DEV S3 DataSync destination location"
  value       = aws_datasync_location_s3.dest_dev.arn
}

########################################
# CloudWatch Logs
########################################

output "datasync_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for the DataSync task"
  value       = aws_cloudwatch_log_group.datasync_log_group.arn
}

########################################
# DataSync Task
########################################

output "datasync_task_arn_uat_to_dev" {
  description = "ARN of the DataSync task from UAT to DEV"
  value       = aws_datasync_task.uat_to_dev.arn
}
