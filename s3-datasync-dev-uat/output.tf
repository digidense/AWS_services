output "datasync_task_arn" {
  description = "ARN of DataSync task from Dev to UAT"
  value       = aws_datasync_task.dev_to_uat.arn
}

output "dev_location_arn" {
  description = "DataSync location ARN for Dev S3"
  value       = aws_datasync_location_s3.dev.arn
}

output "uat_location_arn" {
  description = "DataSync location ARN for UAT S3"
  value       = aws_datasync_location_s3.uat.arn
}
