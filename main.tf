
# ============================================
# 讀取 AWS Account ID（避免 bucket 名稱衝突）
# ============================================
data "aws_caller_identity" "current" {}
# 作用：自動取得你的 AWS Account ID
# 結果：例如 123456789012

# ============================================
# 打包 Lambda 代碼成 zip
# ============================================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"           # lambda 程式碼來源
  output_path = "${path.module}/build/lambda.zip" # 輸出：build/lambda.zip
}
# 作用：把 lambda/handler.py 打包成 lambda.zip
# Lambda 只接受 zip 格式

# ============================================
# 本地變數（集中管理命名）
# ============================================
locals {
  # S3 bucket 名稱加上 Account ID（確保全球唯一）
  bucket_name = "${var.bucket_name}-${data.aws_caller_identity.current.account_id}"
  # 結果：invoice-receipts-123456789012
  
  # Lambda 函數名稱加上環境
  lambda_name = "invoice-notify-discord-${var.environment}"
  # 結果：invoice-notify-discord-dev
  
  # IAM Role 名稱
  iam_role_name = "invoice-notify-lambda-role-${var.environment}"
  
  # CloudWatch Log Group 名稱
  log_group_name = "/aws/lambda/invoice-notify-discord-${var.environment}"
  
  # 統一的 tags（所有資源共用）
  common_tags = {
    Project     = "InvoiceNotification"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================
# 建立 S3 Bucket
# ============================================
resource "aws_s3_bucket" "invoice" {
  bucket = local.bucket_name
  tags   = merge(local.common_tags, {
    Name = local.bucket_name
  })
}

# ============================================
# 阻擋 S3 Public Access（安全性）
# ============================================
resource "aws_s3_bucket_public_access_block" "invoice" {
  bucket = aws_s3_bucket.invoice.id
  
  block_public_acls       = true  # 阻擋公開的 ACL
  block_public_policy     = true  # 阻擋公開的 Policy
  ignore_public_acls      = true  # 忽略現有的公開 ACL
  restrict_public_buckets = true  # 限制 bucket 變公開
}
# 作用：確保 bucket 永遠是私有的（單據不應該公開）

# ============================================
# 建立 Lambda 的 IAM Role（身份證）
# ============================================
resource "aws_iam_role" "lambda_role" {
  name = local.iam_role_name
  
  # assume_role_policy = 誰可以使用這個 Role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"  # 只有 Lambda 服務可以用
      }
      Action = "sts:AssumeRole"
    }]
  })
  
  tags = local.common_tags
}
# 作用：建立 Lambda 的身份（就像員工證）

# ============================================
# 附加權限 1：允許寫 CloudWatch Logs
# ============================================
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
# 作用：讓 Lambda 可以寫日誌到 CloudWatch
# 使用 AWS 官方的 Policy（不用自己寫）

# ============================================
# 附加權限 2：允許讀取 S3（自定義，更安全）
# ============================================
resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "lambda-s3-access"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",        # 讀取檔案
        "s3:GetObjectVersion"  # 讀取檔案版本
      ]
      Resource = "${aws_s3_bucket.invoice.arn}/*"
      # 只能讀這個 bucket，不能讀其他 bucket，並且能夠操控該 bucket 的資源（若沒有 /* 代表只能操控單獨的 bucket）
    }]
  })
}
# 作用：讓 Lambda 可以讀取 S3 的檔案資訊

# ============================================
# 建立 CloudWatch Log Group（控制保留期限）
# ============================================
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days  # 保留 7 天
  tags              = local.common_tags
}
# 作用：手動建立 Log Group 可以控制保留天數
# 不建立的話，logs 會永久保留（浪費錢）

# ============================================
# 建立 Lambda Function
# ============================================
resource "aws_lambda_function" "notify" {
  function_name    = local.lambda_name
  role             = aws_iam_role.lambda_role.arn  # 使用上面建的 Role
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"      # 檔名.函數名
  
  # Lambda 代碼
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # source_code_hash 用來偵測代碼變更
  # 如果 handler.py 改了，Terraform 會自動更新 Lambda
  
  # 資源設定
  timeout     = var.lambda_timeout      # 10 秒
  memory_size = var.lambda_memory_size  # 128 MB
  
  # 環境變數（傳給 Lambda 程式碼）
  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
      ENVIRONMENT         = var.environment
    }
  }
  
  tags = merge(local.common_tags, {
    Name = local.lambda_name
  })
  
  # 確保這些資源先建立好
  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}
# 作用：建立 Lambda 函數

# ============================================
# 允許 S3 觸發 Lambda（
# ============================================
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify.function_name
  principal     = "s3.amazonaws.com"                # S3 服務可以呼叫
  source_arn    = aws_s3_bucket.invoice.arn         # 只有這個 bucket
}
# 作用：允許 S3 觸發 Lambda
# 就像門禁卡：只有這個 bucket 有權限按門鈴

# ============================================
# 設定 S3 Event Notification（觸發器）
# ============================================
resource "aws_s3_bucket_notification" "on_upload" {
  bucket = aws_s3_bucket.invoice.id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.notify.arn
    events              = ["s3:ObjectCreated:*"]  # 任何建立檔案的動作
    
    # 可選：只處理特定檔案
    filter_prefix = var.s3_filter_prefix  # 例如：invoices/
    filter_suffix = var.s3_filter_suffix  # 例如：.png
  }
  
  # 確保 Lambda Permission 先建立好
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
# 作用：設定「S3 上傳檔案 → 觸發 Lambda」
# 對應 Console 的「Add Trigger」


