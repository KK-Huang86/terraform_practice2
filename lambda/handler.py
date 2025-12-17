import json
import os
import urllib.request
import urllib.error
from urllib.parse import unquote_plus
from datetime import datetime

# 從環境變數讀取 Webhook URL
WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "unknown")


def lambda_handler(event, context):
    """
    處理 S3 上傳事件，發送通知到 Discord
    """
    try:
        # 驗證 webhook URL
        if not WEBHOOK_URL:
            return {
                "statusCode": 500,
                "body": json.dumps({"error": "DISCORD_WEBHOOK_URL not configured"})
            }
        
        # 解析 S3 事件
        if "Records" not in event or len(event["Records"]) == 0:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Invalid event format"})
            }
        
        print(event)
        record = event["Records"][0]
        print(record)
        s3 = record.get("s3", {})
        bucket_name = s3.get("bucket", {}).get("name", "unknown")
        object_key = unquote_plus(s3.get("object", {}).get("key", ""))
        object_size = s3.get("object", {}).get("size", 0)
        
        # 格式化檔案大小
        if object_size < 1024:
            size_str = f"{object_size} B"
        elif object_size < 1024 * 1024:
            size_str = f"{object_size / 1024:.2f} KB"
        else:
            size_str = f"{object_size / (1024 * 1024):.2f} MB"
        
        # 取得檔案類型
        file_extension = object_key.split('.')[-1].upper() if '.' in object_key else "unknown"
        
        # 目前時間
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # 準備 Discord 訊息（使用 Embed 格式）
        payload = {
            "content": "新單據上傳通知",
            "embeds": [{
                "title": "📋 檔案資訊",
                "color": 5763719,  # 綠色
                "fields": [
                    {
                        "name": "儲存位置_S3",
                        "value": f"{bucket_name}",
                        "inline": False
                    },
                    {
                        "name": "檔案名稱",
                        "value": f"{object_key}",
                        "inline": False
                    },
                    {
                        "name": "檔案大小",
                        "value": size_str,
                        "inline": True
                    },
                    {
                        "name": "檔案類型",
                        "value": file_extension,
                        "inline": True
                    },
                    {
                        "name": "上傳時間",
                        "value": current_time,
                        "inline": True
                    },
                    {
                        "name": "環境",
                        "value": ENVIRONMENT.upper(),
                        "inline": True
                    }
                ],
                "footer": {
                    "text": "會計系統自動通知"
                },
                "timestamp": datetime.utcnow().isoformat()
            }]
        }
        
        # 發送到 Discord
        request_data = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            WEBHOOK_URL,
            data=request_data,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "AWS-Lambda-Invoice-Notifier"
            },
            method="POST"
        )
        
        # 發送請求
        with urllib.request.urlopen(request, timeout=5) as response:
            response_status = response.status
            print(f"✅ Discord 通知成功")
            print(f"   - Bucket: {bucket_name}")
            print(f"   - File: {object_key}")
            print(f"   - Size: {size_str}")
            print(f"   - Discord Response: {response_status}")
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "通知已發送",
                "bucket": bucket_name,
                "file": object_key,
                "size": size_str
            })
        }
        
    except KeyError as e:
        error_msg = f"事件格式錯誤: {str(e)}"
        print(f"❌ {error_msg}")
        return {
            "statusCode": 400,
            "body": json.dumps({"error": error_msg})
        }
        
    except urllib.error.HTTPError as e:
        error_msg = f"Discord API HTTP 錯誤: {e.code} - {e.reason}"
        print(f"❌ {error_msg}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": error_msg})
        }
        
    except urllib.error.URLError as e:
        error_msg = f"Discord API 連線錯誤: {str(e.reason)}"
        print(f"❌ {error_msg}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": error_msg})
        }
        
    except Exception as e:
        error_msg = f"未預期的錯誤: {str(e)}"
        print(f"❌ {error_msg}")
        import traceback
        print(traceback.format_exc())
        return {
            "statusCode": 500,
            "body": json.dumps({"error": error_msg})
        }
