resource "terraform_data" "pull_github_repo" {
  triggers_replace = [
    var.source_version
  ]

  provisioner "local-exec" {
    working_dir = path.module
    command = "git clone https://github.com/${var.git_user_name}/${var.git_repo_name}"
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/${var.git_repo_name}"
    command = "make zip && cp -f ${var.git_repo_name}.zip ../src"
  }
}

resource "terraform_data" "del_github_repo" {
  lifecycle {
    replace_triggered_by = [ 
      terraform_data.pull_github_repo,
    ]
  }

  provisioner "local-exec" {
    working_dir = path.module
    command = "rm -rf ${var.git_repo_name}"
  }
}

data "local_file" "zip_file" {
  filename = "${path.module}/src/${var.git_repo_name}.zip"
  depends_on = [ terraform_data.pull_github_repo ]
}

resource "aws_lambda_function" "lambda" {
  function_name = var.function_name
  filename = data.local_file.zip_file.filename

  runtime = "nodejs16.x"
  handler = "index.handler"

  source_code_hash = data.local_file.zip_file.content_base64sha256

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      ES_ENDPOINT = var.es_endpoint
      ES_BASIC_AUTH = var.es_basic_auth
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${var.function_name}-lambda-policy"

  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
  })
}

resource "aws_iam_role_policy_attachment" "policy_to_role" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${var.s3_bucket_id}"

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events = ["s3:ObjectCreated:*"]
    filter_suffix = ".log.gz"
  }

  depends_on = [ aws_lambda_permission.allow_bucket ]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = "${var.s3_bucket_arn}"
}