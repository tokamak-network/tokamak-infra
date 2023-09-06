module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_private_access = false
  cluster_endpoint_public_access  = true

  vpc_id     = var.vpc_id
  subnet_ids = setunion(var.private_subnet_ids, var.public_subnet_ids)

  fargate_profiles = {
    default = {
      name       = "default"
      subnet_ids = var.private_subnet_ids
      selectors = [
        {
          namespace = "*"
        }
      ]
    }
  }
}

data "aws_iam_policy_document" "aws_fargate_logging_policy" {
  statement {
    sid = "1"

    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "aws_fargate_logging_policy" {
  name   = "aws_fargate_logging_policy_${var.cluster_name}"
  path   = "/"
  policy = data.aws_iam_policy_document.aws_fargate_logging_policy.json
}

resource "aws_iam_role_policy_attachment" "aws_fargate_logging_policy_attach_role" {
  role       = module.eks.fargate_profiles["default"].iam_role_name
  policy_arn = aws_iam_policy.aws_fargate_logging_policy.arn
}
