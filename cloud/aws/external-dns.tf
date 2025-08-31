data "aws_iam_policy_document" "external_dns" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "external_dns" {
  name        = "external-dns-policy-${local.name}"
  description = "IAM policy for External DNS to manage Route53 records"
  policy      = data.aws_iam_policy_document.external_dns.json

  tags = {
    Name = "external-dns-policy-${local.name}"
    Type = "External DNS Policy"
  }
}

resource "aws_iam_role" "external_dns" {
  name = "external-dns-role-${local.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name = "external-dns-role-${local.name}"
    Type = "External DNS IAM Role"
  }
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}
