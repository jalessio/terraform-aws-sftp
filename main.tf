data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = var.iam_role_name
  description        = var.iam_role_description
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags               = var.tags
}

data "aws_iam_policy_document" "role_policy" {
  statement {
    actions = [
      "logs:DescribeLogStreams",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      format("arn:aws:logs:%s:%s:*", data.aws_region.current.name, data.aws_caller_identity.current.account_id)
    ]
  }
}

resource "aws_iam_role_policy" "main" {
  name   = var.iam_role_name
  role   = aws_iam_role.main.name
  policy = data.aws_iam_policy_document.role_policy.json
}

resource "aws_transfer_server" "main" {

  identity_provider_type = "SERVICE_MANAGED"

  logging_role = aws_iam_role.main.arn

  endpoint_type = "PUBLIC"

  tags = merge({
    Name       = var.name
    Automation = "Terraform"
  }, var.tags)
}

resource "aws_route53_record" "main" {
  count   = length(var.domain_name) > 0 && length(var.zone_id) > 0 ? 1 : 0
  name    = var.domain_name
  zone_id = var.zone_id
  type    = "CNAME"
  ttl     = "300"
  records = [
    aws_transfer_server.main.endpoint
  ]
}
