resource "aws_s3_bucket" "s3" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_policy" "allow_access_from_another_object" {
  bucket = aws_s3_bucket.s3.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::600734575887:root"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}
