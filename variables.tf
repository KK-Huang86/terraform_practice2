# AWS 區域
variable "aws_region" {
  description = "AWS 區域"
  type        = string
  default     = "ap-northeast-1"
}

# 環境名稱
variable "environment" {
  description = "環境名稱 (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment 必須是 dev, staging 或 prod"
  }
}

# S3 bucket 基礎名稱
variable "bucket_name" {
  description = "S3 bucket 基礎名稱（會自動加上 account ID）"
  type        = string
  default     = "invoice-receipts"
}

# S3 事件過濾前綴
variable "s3_filter_prefix" {
  description = "S3 事件過濾前綴（例如: invoices/）"
  type        = string
  default     = ""
}

# S3 事件過濾後綴
variable "s3_filter_suffix" {
  description = "S3 事件過濾後綴（例如: .jpg, .png）"
  type        = string
  default     = ""
}

# Lambda 執行超時時間
variable "lambda_timeout" {
  description = "Lambda 執行超時時間（秒）"
  type        = number
  default     = 10
}

# Lambda 記憶體大小
variable "lambda_memory_size" {
  description = "Lambda 記憶體大小（MB）"
  type        = number
  default     = 128
}

# Discord Webhook URL
variable "discord_webhook_url" {
  description = "Discord Webhook URL"
  type        = string
  sensitive   = true  # 標記為敏感資訊
}

# CloudWatch Logs 保留天數
variable "log_retention_days" {
  description = "CloudWatch Logs 保留天數"
  type        = number
  default     = 7
}