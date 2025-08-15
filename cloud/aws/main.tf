resource "aws_s3_bucket" "test" {
  bucket = "test-bucket-${random_string.random.result}"
}

resource "random_string" "random" {
  length  = 8
  special = false
}
