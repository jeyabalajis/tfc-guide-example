resource "aws_iam_role" "SageMakerNotebookExecutionRole" {
  name                = "sm-nbi-execution-role"
  managed_policy_arns = [aws_iam_policy.policy_one.arn]
}

resource "aws_iam_policy" "policy_one" {
  name = "policy-618033"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:CreateBucket",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketCors",
          "s3:PutBucketCors"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_sagemaker_notebook_instance" "smnbi_test" {
  name          = "my-notebook-instance-test"
  role_arn      = aws_iam_role.SageMakerNotebookExecutionRole.arn
  instance_type = "ml.t2.medium"

  tags = {
    Name            = "smbi-test-001"
    ITOwnerEmail    = "jeyabalaji_subramanian@cargill.com"
    ApplicationName = "test-instance"
    Environment     = "dev"
    Terraform       = "true"
  }
}
