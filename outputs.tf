output "s3_bucket_name" {
  description = "S3 bucket 名稱"
  value       = aws_s3_bucket.invoice.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.invoice.arn
}

output "lambda_function_name" {
  description = "Lambda function 名稱"
  value       = aws_lambda_function.notify.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.notify.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group 名稱"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
# 作用：terraform apply 完成後顯示這些資訊