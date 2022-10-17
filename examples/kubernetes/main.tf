provider "aws" {
  region = var.aws_region
}

# data "aws_caller_identity" "current" {}

locals {

  # this will get the name of the local directory
  # name   = basename(path.cwd)
  name = var.service_name

  tags = {
    Blueprint = local.name
  }

  tag_val_vpc            = var.vpc_tag_value == "" ? var.core_stack_name : var.vpc_tag_value
  tag_val_private_subnet = var.private_subnets_tag_value == "" ? "${var.core_stack_name}-private-" : var.private_subnets_tag_value
  tag_val_public_subnet  = var.public_subnets_tag_value == "" ? "${var.core_stack_name}-public-" : var.public_subnets_tag_value

}

################################################################################
# Data Sources from ecs-blueprint-infra
################################################################################

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = [local.tag_val_vpc]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${local.tag_val_private_subnet}*"]
  }
}

data "aws_subnet" "private_cidr" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:${var.vpc_tag_key}"
    values = ["${local.tag_val_public_subnet}*"]
  }
}

data "aws_ecs_cluster" "core_infra" {
  cluster_name = var.ecs_cluster_name == "" ? var.core_stack_name : var.ecs_cluster_name
}

data "aws_iam_role" "ecs_core_infra_exec_role" {
  name = var.ecs_task_execution_role_name == "" ? "${var.core_stack_name}-execution" : var.ecs_task_execution_role_name
}

data "aws_service_discovery_dns_namespace" "sd_namespace" {
  name = "${var.namespace}.${data.aws_ecs_cluster.core_infra.cluster_name}.local"
  type = "DNS_PRIVATE"
}

################################################################################
# Load Balancer 
################################################################################

module "service_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-alb-sg"
  description = "Security group for client application"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = [for s in data.aws_subnet.private_cidr : s.cidr_block]

  tags = local.tags
}

module "service_alb" {
  count = var.service_type == "LoadBalancer"? 1 : 0
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 7.0"

  name = "${local.name}-alb"

  load_balancer_type = "application"

  vpc_id          = data.aws_vpc.vpc.id
  subnets         = data.aws_subnets.public.ids
  security_groups = [module.service_alb_security_group.security_group_id]

  http_tcp_listeners = [
    {
      port               = var.lb_ports[0]["listener_port"]
      protocol           = var.lb_ports[0]["protocol"]
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "${local.name}-tg"
      backend_protocol = var.lb_ports[0]["protocol"]
      backend_port     = var.lb_ports[0]["target_port"]
      target_type      = "ip"
      health_check = {
        path    = var.health_check_path
        port    = var.lb_ports[0]["target_port"]
        matcher = var.health_check_matcher
      }
    },
  ]

  tags = local.tags
}


module "service_task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-task-sg"
  description = "Security group for service task"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  egress_rules        = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 10000
      protocol    = "tcp"
      description = "User-service ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = local.tags
}

resource "aws_service_discovery_service" "sd_service" {
  name = local.name

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.sd_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

module "ecs_service_definition" {
  source = "../../modules/ecs-service"

  name                       = local.name
  desired_count              = var.desired_count
  ecs_cluster_id             = data.aws_ecs_cluster.core_infra.cluster_name
  cp_strategy_base           = var.cp_strategy_base
  cp_strategy_fg_weight      = var.cp_strategy_fg_weight
  cp_strategy_fg_spot_weight = var.cp_strategy_fg_spot_weight

  security_groups = [module.service_task_security_group.security_group_id]
  subnets         = data.aws_subnets.private.ids

  load_balancers = var.service_type == "LoadBalancer" ? [{target_group_arn = element(module.service_alb[0].target_group_arns, 0)}] : []

  service_registry_list = [{
    registry_arn = aws_service_discovery_service.sd_service.arn
  }]
  deployment_controller = "ECS"

  # Task Definition
  attach_task_role_policy       = false
  container_name                = var.main_app_container_definition["container_name"]
  image                         = var.main_app_container_definition["container_image"]
  container_port                = length(lookup(var.main_app_container_definition, "port_mappings", [])) > 0 ? var.main_app_container_definition["port_mappings"][0]["containerPort"] : 80
  map_environment               = lookup(var.main_app_container_definition,"map_environment",null)
  map_secrets                   = lookup(var.main_app_container_definition,"map_secrets",null)
  cpu                           = var.task_cpu
  memory                        = var.task_memory
 
  execution_role_arn            = data.aws_iam_role.ecs_core_infra_exec_role.arn
  
  sidecar_container_definitions = var.sidecar_container_definitions
  enable_execute_command        = true
  tags                          = merge(local.tags, var.deployment_tags, var.service_tags, var.task_tags)
}


################################################################################
# SSM Paramters created as String
################################################################################

resource "aws_ssm_parameter" "task_ssm_parameters" {
  count = length(var.ssm_parameters) 
  name  = var.ssm_parameters[count.index]["config_name"]
  type  = "String"
  value = var.ssm_parameters[count.index]["config_value"]
}

################################################################################
# SSM Partmeter created as SecureString to store sensitive secrets
################################################################################

resource "aws_ssm_parameter" "task_ssm_secrets" {
  count = length(var.ssm_secrets) 
  name  = var.ssm_secrets[count.index]["secret_name"]
  type  = "SecureString"
  value = base64decode(var.ssm_secrets[count.index]["secret_value"])
}