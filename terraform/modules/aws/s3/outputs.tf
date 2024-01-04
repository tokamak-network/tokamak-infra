output "bucket_id" {
  description = "id of the s3 bucket"

  value = aws_s3_bucket.s3.id
}

output "bucket_arn" {
  description = "arn of the s3 bucket"

  value = aws_s3_bucket.s3.arn
}
