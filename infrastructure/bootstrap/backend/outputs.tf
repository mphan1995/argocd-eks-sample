output "tfstate_bucket_name" {
  description = "Terraform backend S3 bucket"
  value       = aws_s3_bucket.tfstate.id
}

output "tf_lock_table_name" {
  description = "Terraform state lock DynamoDB table"
  value       = aws_dynamodb_table.tf_locks.name
}
