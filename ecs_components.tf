data "aws_iam_policy_document" "mlflow-ecs-tasks-trust-assumerole-policy" {
  version = "2012-10-17"
  statement {
    actions = [
    "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
      "ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mlflow_fargate_task_execution_role" {
  name                  = "mlflow_fargate_task_execution_role"
  force_detach_policies = true

  assume_role_policy = data.aws_iam_policy_document.mlflow-ecs-tasks-trust-assumerole-policy.json

  managed_policy_arns = [
    aws_iam_policy.ecs_allow_s3_actions.arn,
    aws_iam_policy.ecs_allow_secrets_actions.arn,
    aws_iam_policy.ecs_allow_ecs_actions.arn
  ]
}

data "aws_iam_policy_document" "ecs_allow_s3_actions_policy_document" {
  version = "2012-10-17"
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetBucketCors",
      "s3:PutBucketCors"
    ]
    resources = [
    "*"]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "ecs_allow_s3_actions" {
  name   = "ecs_allow_s3_actions"
  policy = data.aws_iam_policy_document.ecs_allow_s3_actions_policy_document.json
}

data "aws_iam_policy_document" "ecs_allow_secrets_actions_policy_document" {
  version = "2012-10-17"
  statement {
    actions = [
      "secretsmanager:GetRandomPassword",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:UntagResource",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:TagResource"
    ]
    resources = [
    "*"]
    effect = "Allow"
  }
}

# this policy allows secrets manager related permissions to ecs task execution role
resource "aws_iam_policy" "ecs_allow_secrets_actions" {
  name   = "ecs_allow_secrets_actions"
  policy = data.aws_iam_policy_document.ecs_allow_secrets_actions_policy_document.json
}

data "aws_iam_policy_document" "ecs_allow_ecs_actions_policy_document" {
  version = "2012-10-17"
  statement {
    actions = [
      "ecs:*",
      "ec2:*",
      "cloudwatch:*",
      "application-autoscaling:*",
      "autoscaling:*",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfiles",
      "iam:ListRoles",
      "lambda:ListFunctions",
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:FilterLogEvents",
      "servicediscovery:CreatePrivateDnsNamespace",
      "servicediscovery:CreateService",
      "servicediscovery:DeleteService",
      "servicediscovery:GetNamespace",
      "servicediscovery:GetOperation",
      "servicediscovery:GetService",
      "servicediscovery:ListNamespaces",
      "servicediscovery:ListServices",
      "servicediscovery:UpdateService",
      "sns:ListTopics"
    ]
    effect = "Allow"
    resources = [
    "*"]
  }
}

resource "aws_iam_policy" "ecs_allow_ecs_actions" {
  name   = "ecs_allow_ecs_actions"
  policy = data.aws_iam_policy_document.ecs_allow_ecs_actions_policy_document.json
}

resource "aws_cloudwatch_log_group" "mlflow_ecs_task_cw_log_group" {
  name = "/ecs/mlflow_ecs_task_cw_log_group"
}

resource "aws_ecs_cluster" "mlflow_fargate_cluster" {
  name = "mlflow_fargate_cluster"

  capacity_providers = [
    "FARGATE",
  "FARGATE_SPOT"]

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

}

resource "aws_ecs_service" "mlflow-fargate-service" {
  name = "mlflow-fargate-service"


  cluster         = aws_ecs_cluster.mlflow_fargate_cluster.id
  task_definition = aws_ecs_task_definition.mlflow_fargate_task.arn
  desired_count   = 1

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent = 200

  force_new_deployment               = true
  enable_ecs_managed_tags            = true
  enable_execute_command             = false

  launch_type = "FARGATE"

  network_configuration {
    subnets = [
    "subnet-0f9c53b51c9a3700f",
    "subnet-01f7be53e286cfa40"
  ]
    security_groups = [
    aws_security_group.mlflow_ecs_fargate_service_sg.id]
    assign_public_ip = false
  }
  platform_version    = "LATEST"
  scheduling_strategy = "REPLICA"

  load_balancer {
    target_group_arn = aws_lb_target_group.mlflow_ecs_task_target_group.arn
    container_name   = "mlflow-docker"
    container_port   = 5000
  }
}

resource "aws_ecs_task_definition" "mlflow_fargate_task" {
  family = aws_ecs_cluster.mlflow_fargate_cluster.name

  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"

  task_role_arn =   aws_iam_role.mlflow_fargate_task_execution_role.arn
  execution_role_arn = aws_iam_role.mlflow_fargate_task_execution_role.arn
  memory             = 8192
  cpu                = 4096

  container_definitions = templatefile("./mlflow/containerDefs.json", {
    MLFLOW_DOCKER_IMAGE   = "docker.binrepo.cglcloud.in/mlops-mlflow-base-image:1.0.6"
    CLOUD_WATCH_LOG_GROUP = aws_cloudwatch_log_group.mlflow_ecs_task_cw_log_group.name
    BUCKET                = "TESTBUCKET"
    USERNAME              = "TESTUSER"
    HOST                  = "TESTHOST"
    PORT                  = "5000"
    DATABASE              = "DB"
    PASSWORD              = "DBPWD"
  })
}

resource "aws_security_group" "mlflow_ecs_fargate_service_sg" {
  name        = "mlflow_ecs_fargate_service_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-0ccfae2ee14d362e9"

}

# Expose Fargate service security group to ALB Security Group(s)
resource "aws_security_group_rule" "mlflow_ecs_fargate_service_sg_ingress" {
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mlflow_ecs_fargate_service_sg.id
  type                     = "ingress"
  source_security_group_id = aws_security_group.mlflow_ecs_fargate_service_sg.id
}

resource "aws_security_group_rule" "mlflow_ecs_fargate_service_sg_egress" {
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.mlflow_ecs_fargate_service_sg.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb_target_group" "mlflow_ecs_task_target_group" {
  name        = "mlflow-ecs-task-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-0ccfae2ee14d362e9"
}

resource "aws_alb" "mlflow-ecs-alb" {
  name               = "mlflow-ecs-alb"
  internal           = true
  load_balancer_type = "application"

  subnets         = [
    "subnet-0f9c53b51c9a3700f",
    "subnet-01f7be53e286cfa40"
  ]
  security_groups = [aws_security_group.mlflow_alb_sg.id]

}

resource "aws_lb_listener" "mlflow-ecs-lb-listener" {
  load_balancer_arn = aws_alb.mlflow-ecs-alb.arn
  port              = "80"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mlflow_ecs_task_target_group.arn
  }
}

resource "aws_security_group" "mlflow_alb_sg" {
  name        = "mlflow_alb_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-0ccfae2ee14d362e9"

}

# Expose ALB to only Notebook Instance Security Group
resource "aws_security_group_rule" "mlflow_alb_sg_ingress" {
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mlflow_alb_sg.id
  type                     = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "mlflow_alb_sg_egress" {
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.mlflow_alb_sg.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}