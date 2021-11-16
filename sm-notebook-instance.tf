resource "aws_iam_role" "SageMakerNotebookExecutionRole" {
  name                = "sm-nbi-execution-role"
  assume_role_policy  = data.aws_iam_policy_document.sm-nbi-assume-role-policy.json
  managed_policy_arns = [aws_iam_policy.policy_one.arn]
}

data "aws_iam_policy_document" "sm-nbi-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
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
  root_access   = "Disabled"
  direct_internet_access = "Disabled"

  tags = {
    Name            = "smbi-test-001"
    ITOwnerEmail    = "jeyabalaji_subramanian@cargill.com"
    ApplicationName = "test-instance"
    Environment     = "dev"
    Terraform       = "true"
  }
}

output "notebook_instance_url" {
  description = "Notebook Instance URL"
  value       = aws_sagemaker_notebook_instance.smnbi_test.url
  sensitive   = false
}
