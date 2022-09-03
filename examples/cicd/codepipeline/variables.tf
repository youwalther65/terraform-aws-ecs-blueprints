variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "core_stack_name" {
  description = "The name of core infrastructure stack that you created using core-infra module"
  type        = string
}

variable "vpc_tag_key" {
  description = "The tag key of the VPC and subnets"
  type        = string
  default     = "Name"
}

variable "vpc_tag_value" {
  # if left blank then {core_stack_name} will be used
  description = "The tag value of the VPC and subnets"
  type        = string
  default     = ""
}

variable "public_subnets_tag_value" {
  # if left blank then {core_stack_name}-public- will be used
  description = "The value tag of the public subnets"
  type        = string
  default     = ""
}

variable "private_subnets_tag_value" {
  # if left blank then {core_stack_name}-private- will be used
  description = "The value tag of the private subnets"
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  # if left blank then {core_stack_name} will be used
  description = "The ID of the ECS cluster"
  type        = string
  default     = ""
}

variable "ecs_task_execution_role_name" {
  # if left blank then {core_stack_name}-execution will be used
  description = "The ARN of the task execution role"
  type        = string
  default     = ""
}

# Application variables
variable "buildspec_file_app" {
  description   = "The location of the buildspec file"
  default       = {
    "app_build" = "buildspec.yml"
  }
}

variable "app_folder_path" {
  description = "The location of the application code and Dockerfile files"
  type        = string
  default     = "./application-code/ecsdemo-frontend/."
}

variable "infra_folder_path" {
  description = "The location of the Terraform code for the environment"
  type        = string
  default     = "./examples/lb-service/."
}

variable "app_repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "app_repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "terraform-aws-ecs-blueprints"
}

variable "app_repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "infra_repository_owner" {
  description = "The name of the owner of the Github repository"
  type        = string
}

variable "infra_repository_name" {
  description = "The name of the Github repository"
  type        = string
  default     = "terraform-aws-ecs-blueprints"
}

variable "infra_repository_branch" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
  default     = "main"
}

variable "github_token_secret_name" {
  description = "The name of branch the Github repository, which is going to trigger a new CodePipeline excecution"
  type        = string
}

# application related input parameters
variable "service_name" {
  description = "The service name"
  type        = string
  default     = "ecsdemo-frontend"
}

variable "container_name" {
  description = "The container name to use in service task definition"
  type        = string
  default     = "ecsdemo-frontend"
}

variable "tf_version" {
  description = "Terraform Version for infrastructure deployment"
  type = string
  default = "1.2.8"
}

variable "buildspec_file_tf" {
  description = "Build spec file name for the pipeline"
  default = {
    "terraform_plan"    = "buildspec-tf-plan.yml",
    "terraform_apply"   = "buildspec-tf-apply.yml",
    "terraform_checkov" = "buildspec-tf-checkov.yml",
    "terraform_tflint"  = "buildspec-tf-tflint.yml"
  }
}

# variable "namespace" {
#   description = "Codepipeline Namespace for Environment mapping"
#   type = string
# }