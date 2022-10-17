variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "core_stack_name" {
  description = "The name of core infrastructure stack that you created using core-infra module"
  type        = string
  default     = "ecs-blueprint-infra"
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
  # if left blank then {core_stack_name}-public- will be used
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
  description = "The name of the task execution role"
  type        = string
  default     = ""
}


################################################################################
# Servie definition parameters
################################################################################

variable "service_name" {
  description = "The service name"
  type        = string
}

variable "service_type" {
  description = "Service type LoadBalancer, ClusterIP, Ingress"
  type = string
  default = "ClusterIP"
}

variable "lb_ports" {
  description = "load balancer port settings for listener and target"
  type = list(object({
    listener_port = string
    protocol = string
    target_port = string 
  }))
  default = null 
}

# target health check
variable "health_check_path" {
  description = "The health check path"
  type        = string
  default     = "/"
}

# variable "health_check_protocol" {
#   description = "The health check protocol"
#   type        = string
#   default     = "http"
# }

variable "health_check_matcher" {
  description = "The health check passing codes"
  type        = string
  default     = "200-299"
}

variable "namespace" {
  description = "The service discovery namespace"
  type        = string
  default     = "default"
}

variable "desired_count" {
  description = "The number of task replicas for service"
  type        = number
  default     = 1
}

variable "service_tags" {
  description = "Tags to attach to service"
  type        = map(string)
  default = null
}

variable "deployment_tags" {
  description = "Deployment tags to attach to service"
  type        = map(string)
  default = null
}

variable "deployment_minimum_healthy_percent" {
  description = "The minimum number of tasks, specified as a percentage of the Amazon ECS service's DesiredCount value, that must continue to run and remain healthy during a deployment."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of task able to be deployed"
  type        = number
  default     = 200
}

################################################################################
# Task definition parameters
################################################################################
variable "task_cpu" {
  description = "The task vCPU size"
  type        = number
}

variable "task_memory" {
  description = "The task memory size"
  type        = string
}

variable "task_tags" {
  description = "Tags to attach to task"
  type        = map(string)
  default = null
}

# Main app container defintion is required
variable "main_app_container_definition" {
  description = ""
  type        = object({
    container_name = string
    container_image = string
    port_mappings = list(object({
      containerPort = number
      protocol      = string
      }))
    map_environment = map(string)
    map_secrets = map(string) 
  })
}

# Provide a list of map objects
# Each map object has container definition parameters
# The required parameters are container_name, container_image, port_mappings
# [
#  {
#    "container_name":"monitoring-agent",
#    "container_image": "img-repo-url"},
#    "port_mappings" : [{ containerPort = 9090, hostPort =9090, protocol = tcp}]
#  }
# ]
# see modules/ecs-container-definition for full set of parameters
# map_environment and map_secrets are common to add in container definition
variable "sidecar_container_definitions" {
  description = "List of container definitions to add to the task"
  type        = list(any)
  default     = []
}

################################################################################
# Capacity provider strategy setting
# to distribute tasks between Fargate
# Fargate Spot
################################################################################

variable "cp_strategy_base" {
  description = "Base number of tasks to create on Fargate on-demand"
  type        = number
  default     = 1
}

variable "cp_strategy_fg_weight" {
  description = "Relative number of tasks to put in Fargate"
  type        = number
  default     = 1
}

variable "cp_strategy_fg_spot_weight" {
  description = "Relative number of tasks to put in Fargate Spot"
  type        = number
  default     = 0
}

################################################################################
# SSM Parameter list
# these are stored as simple String type
################################################################################

variable "ssm_parameters" {
  description = "list of ssm parameters to create"
  type = list(map(string))
  default     = []
}

################################################################################
# SSM Parameter list
# these are stored as SecureString encrypted by AWS managed key
################################################################################

variable "ssm_secrets" {
  description = "list of ssm parameters to create as SecureString type"
  type = list(map(string))
  default     = []
}


