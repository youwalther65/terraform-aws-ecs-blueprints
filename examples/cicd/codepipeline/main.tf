provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {

  # this will get the name of the local directory
  # name   = basename(path.cwd)
  name = var.service_name

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/${var.infra_repository_owner}/terraform-aws-ecs-blueprints"
  }
}

################################################################################
# Data Sources
################################################################################

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name == "" ? "${var.core_stack_name}-execution" : var.ecs_task_execution_role_name
}

data "aws_secretsmanager_secret" "github_token" {
  name = var.github_token_secret_name
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

################################################################################
# CodePipeline and CodeBuild for CI/CD
################################################################################

module "codebuild_ci_app" {
  source = "../../../modules/codebuild"

  # name           = "codebuild-${var.service_name}-app"
  service_role   = module.codebuild_ci_app.codebuild_role_arn
  buildspec_file = var.buildspec_file_app
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    environment_variables = [
      {
        name  = "REPO_URL"
        value = module.container_image_ecr.repository_url
        }, {
        name  = "FOLDER_PATH"
        value = var.app_folder_path
        }, {
        name  = "ECS_EXEC_ROLE_ARN"
        value = data.aws_iam_role.ecs_core_infra_exec_role.arn
      },
    ]
  }

  create_iam_role = true
  iam_role_name   = "${var.service_name}-codebuild-${random_id.app.hex}"
  ecr_repository  = module.container_image_ecr.repository_arn

  tags = local.tags
}

module "codepipeline_ci_cd_app" {
  source = "../../../modules/codepipeline"

  name         = "app-pipeline-${var.service_name}"
  service_role = module.codepipeline_ci_cd_app.codepipeline_role_arn
  s3_bucket    = module.codepipeline_s3_bucket
  sns_topic    = aws_sns_topic.codestar_notification.arn

  stage = [{
    name = "Source"
    action = [{
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      input_artifacts  = []
      output_artifacts = ["SourceArtifact"]
      configuration = {
        OAuthToken           = data.aws_secretsmanager_secret_version.github_token.secret_string
        Owner                = var.app_repository_owner
        Repo                 = var.app_repository_name
        Branch               = var.app_repository_branch
        PollForSourceChanges = false
      }
    }],
    }, {
    name = "Build"
    action = [{
      name             = "Build_app"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact_app"]
      configuration = {
        ProjectName = module.codebuild_ci_app.project_id["app_build"]
      }
    }],
  }]

  create_iam_role = true
  iam_role_name   = "${var.service_name}-pipeline-${random_id.app.hex}"

  tags = local.tags
}

module "codebuild_ci_infra" {
  source = "../../../modules/codebuild"

  # name           = "codebuild-${var.service_name}-infra"
  service_role   = module.codebuild_ci_infra.codebuild_role_arn
  buildspec_file = var.buildspec_file_tf
  s3_bucket      = module.codepipeline_s3_bucket

  environment = {
    privileged_mode = true
    environment_variables = [
      {
        name  = "TF_VERSION"
        value = var.tf_version
        }, {
        name  = "TF_ENV"
        value = var.infra_folder_path
        }, {
        name  = "TF_ACTION"
        value = "apply"
        }, {
        name  = "TF_LOG"
        value = "DEBUG"
      },
    ]
  }

  create_iam_role = true
  iam_role_name   = "${var.service_name}-codebuild-${random_id.infra.hex}"
  ecr_repository  = module.container_image_ecr.repository_arn

  tags = local.tags
}

module "codepipeline_ci_cd_infra" {
  source = "../../../modules/codepipeline"

  name         = "infra-pipeline-${var.service_name}"
  service_role = module.codepipeline_ci_cd_infra.codepipeline_role_arn
  s3_bucket    = module.codepipeline_s3_bucket
  sns_topic    = aws_sns_topic.codestar_notification.arn

  stage = [{
    name = "Source"
    action = [{
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      input_artifacts  = []
      output_artifacts = ["SourceArtifact"]
      configuration = {
        OAuthToken           = data.aws_secretsmanager_secret_version.github_token.secret_string
        Owner                = var.infra_repository_owner
        Repo                 = var.infra_repository_name
        Branch               = var.infra_repository_branch
        PollForSourceChanges = false
      }
    }],
    }, {
    # name = "Terraform_TFlint"
    # action = [{
    #   name             = "${var.infra_repository_name}-TF_Tflint"
    #   category         = "Build"
    #   owner            = "AWS"
    #   provider         = "CodeBuild"
    #   version          = "1"
    #   input_artifacts  = ["SourceArtifact"]
    #   output_artifacts = ["tflint"]
    #   namespace        = "TFLINT"
    #   configuration = {
    #     ProjectName = module.codebuild_ci_infra.project_id["terraform_tflint"]
    #     EnvironmentVariables = jsonencode([
    #       {
    #         name  = "TF_BACKEND_CONFIG_PREFIX",
    #         value = var.tf_backend_config_prefix,
    #         type  = "PLAINTEXT"
    #       }, {
    #         name  = "ENV",
    #         value = var.env,
    #         type  = "PLAINTEXT"
    #       }, {
    #         name  = "TEAM",
    #         value = var.team,
    #         type  = "PLAINTEXT"
    #       }
    #     ])
    #   }
    # }],
    # }, {
    name = "Terraform_Checkov"
    action = [{
      run_order        = "1"
      name             = "${var.infra_repository_name}-TF_Checkov"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["checkov"]
      namespace        = "CHECKOV"
      configuration = {
        ProjectName = module.codebuild_ci_infra.project_id["terraform_checkov"]
      }
    }, {
      run_order        = "2"
      name             = "${var.infra_repository_name}-TF_Checkov_Approval"
      category         = "Approval"
      owner            = "AWS"
      provider         = "Manual"
      version          = "1"
      configuration = {
        CustomData         = "checkov: #{CHECKOV.failures}, #{CHECKOV.tests}"
        ExternalEntityLink = "#{CHECKOV.review_link}"
      }
    }],
    }, {
    name = "Terraform_Build"
    action = [{
      run_order        = "1"
      name             = "${var.infra_repository_name}-TF_Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["plan"]
      namespace        = "TF"
      configuration = {
        ProjectName = module.codebuild_ci_infra.project_id["terraform_plan"]
      }
    }, {
      run_order        = "2"
      name             = "${var.infra_repository_name}-TF_Apply_Approval"
      category         = "Approval"
      owner            = "AWS"
      provider         = "Manual"
      version          = "1"
      configuration = {
        CustomData         = "Please review and approve the terraform plan"
        ExternalEntityLink = "https://#{TF.pipeline_region}.console.aws.amazon.com/codesuite/codebuild/${data.aws_caller_identity.current.account_id}/projects/#{TF.build_id}/build/#{TF.build_id}%3A#{TF.build_tag}/?region=#{TF.pipeline_region}"
      }
    }, {
      run_order        = "3"
      name             = "${var.infra_repository_name}-TF_Apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["plan"]
      output_artifacts = ["apply"]
      configuration = {
        ProjectName = module.codebuild_ci_infra.project_id["terraform_apply"]
      }
    }],
  }]

  create_iam_role = true
  iam_role_name   = "${var.service_name}-pipeline-${random_id.infra.hex}"

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "container_image_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.4"

  repository_name = var.container_name

  repository_force_delete           = true
  create_lifecycle_policy           = false
  repository_read_access_arns       = [data.aws_iam_role.ecs_core_infra_exec_role.arn, module.codepipeline_ci_cd_infra.codepipeline_role_arn]
  repository_read_write_access_arns = [module.codepipeline_ci_cd_app.codepipeline_role_arn]

  tags = local.tags
}

module "codepipeline_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "codepipeline-${var.aws_region}-${random_id.app.hex}"
  acl    = "private"

  force_destroy = true // for demo purposes only

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_sns_topic" "codestar_notification" {
  name = local.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteAccess"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${local.name}"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

resource "random_id" "app" {
  byte_length = "2"
}

resource "random_id" "infra" {
  byte_length = "2"
}