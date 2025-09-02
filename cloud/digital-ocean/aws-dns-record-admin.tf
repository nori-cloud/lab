variable "aws_hosted_zone_id" {
  type = string
}

resource "aws_iam_user" "aws-dns-record-admin" {
  name = "aws-dns-record-admin"
}

resource "aws_iam_user_policy" "aws-dns-record-admin-policy" {
  name = "aws-dns-record-admin-policy"
  user = aws_iam_user.aws-dns-record-admin.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource": [
          "arn:aws:route53:::hostedzone/${var.aws_hosted_zone_id}"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "aws-dns-record-admin-access-key" {
  user = aws_iam_user.aws-dns-record-admin.name
}

resource "kubernetes_secret" "aws_credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.nori-space.metadata[0].name
  }

  data = {
    access-key-id     = aws_iam_access_key.aws-dns-record-admin-access-key.id
    secret-access-key = aws_iam_access_key.aws-dns-record-admin-access-key.secret
  }

  type = "Opaque"
}

resource "helm_release" "external-dns" {
  namespace = kubernetes_namespace.nori-space.metadata[0].name

  name = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart = "external-dns"
  version = "9.0.3"

  set = [
    {
      name = "provider"
      value = "aws"
    },
    {
      name = "aws.credentials.accessKey"
      value = aws_iam_access_key.aws-dns-record-admin-access-key.id
    },
    {
      name = "aws.credentials.secretKey"
      value = aws_iam_access_key.aws-dns-record-admin-access-key.secret
    },
    {
      name = "aws.region"
      value = var.aws_region
    }
  ]
}
