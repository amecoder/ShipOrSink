# =============================================================================
# ECS Fargate Service Module - Task Definition + Service + ALB Target Group
# =============================================================================
# 사용법: 이 파일을 프로젝트의 infra/modules/ecs-service/ 에 복사하세요.
#
#   module "api_service" {
#     source          = "./infra/modules/ecs-service"
#     service_name    = "api"
#     image           = "123456789.dkr.ecr.ap-northeast-2.amazonaws.com/myapp:v1.0.0"
#     cpu             = 512
#     memory          = 1024
#     desired_count   = 2
#     alb_security_group_id = aws_security_group.alb.id   # 인바운드는 ALB SG 만
#     egress_cidr_blocks    = []                          # 비우면 VPC CIDR 만 (ECR 은 VPC 엔드포인트 권장)
#     cluster_id      = aws_ecs_cluster.main.id
#     vpc_id          = module.vpc.vpc_id
#     subnet_ids      = module.vpc.private_subnet_ids
#     alb_listener_arn = aws_lb_listener.https.arn
#     environment     = "production"
#     project_name    = "myapp"
#   }
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# --- Variables (입력 변수) ---

variable "alb_security_group_id" {
  description = "ALB 보안 그룹 ID — 서비스 인바운드는 이 SG 에서만 허용한다"
  type        = string
}

variable "egress_cidr_blocks" {
  description = "서비스 아웃바운드 허용 CIDR. 비우면 VPC CIDR 만 허용 (ECR·외부 API 는 VPC 엔드포인트 또는 NAT + 명시 CIDR)"
  type        = list(string)
  default     = []
}

variable "log_kms_key_arn" {
  description = "CloudWatch 로그 그룹 암호화용 KMS CMK ARN (운영 환경 권장 — 미지정 시 AWS 관리 키)"
  type        = string
  default     = null
}

variable "service_name" {
  description = "ECS 서비스 이름 (예: api, worker, scheduler)"
  type        = string
}

variable "image" {
  description = "Docker 이미지 URI (latest 태그 금지, semver 또는 SHA 사용)"
  type        = string
}

variable "cpu" {
  description = "Task CPU 단위 (256=0.25 vCPU, 512=0.5, 1024=1, 2048=2, 4096=4)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Task 메모리(MiB) (512, 1024, 2048, 4096, 8192 등)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "실행할 Task 수 (최소 2 이상 권장 — 고가용성)"
  type        = number
  default     = 2
}

variable "container_port" {
  description = "컨테이너가 리슨하는 포트"
  type        = number
  default     = 8080
}

variable "cluster_id" {
  description = "ECS 클러스터 ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (보안 그룹 생성용)"
  type        = string
}

variable "subnet_ids" {
  description = "Task를 배치할 서브넷 ID 목록 (프라이빗 서브넷 권장)"
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "ALB 리스너 ARN (타겟 그룹 연결용)"
  type        = string
}

variable "health_check_path" {
  description = "헬스체크 엔드포인트 경로"
  type        = string
  default     = "/health"
}

variable "environment" {
  description = "배포 환경 (dev, staging, production)"
  type        = string
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment_variables" {
  description = "컨테이너 환경 변수 (키-값 맵)"
  type        = map(string)
  default     = {}
}

# --- Locals ---

locals {
  common_tags = {
    Name        = "${var.project_name}-${var.service_name}"
    Environment = var.environment
    Team        = var.project_name
    ManagedBy   = "terraform"
  }

  # 환경 변수를 ECS Task Definition 형식으로 변환
  env_vars = [for k, v in var.environment_variables : { name = k, value = v }]
}

# --- IAM (Task 실행 역할) ---

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "task_execution" {
  name = "${var.project_name}-${var.service_name}-task-exec-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- CloudWatch Log Group (로그 수집) ---

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.project_name}/${var.service_name}"
  retention_in_days = var.environment == "production" ? 90 : 14
  kms_key_id        = var.log_kms_key_arn   # CMK 로 로그 암호화 (Semgrep aws-cloudwatch-log-group-unencrypted)

  tags = local.common_tags
}

# --- Task Definition (태스크 정의) ---

resource "aws_ecs_task_definition" "service" {
  family                   = "${var.project_name}-${var.service_name}"
  network_mode             = "awsvpc"           # Fargate 필수
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = var.service_name
    image     = var.image                       # latest 태그 금지 — semver 또는 SHA 사용
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = local.env_vars

    # 헬스체크 설정 (ECS 레벨)
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
      interval    = 30     # 검사 간격(초)
      timeout     = 5      # 응답 대기(초)
      retries     = 3      # 실패 허용 횟수
      startPeriod = 60     # 시작 유예 시간(초)
    }

    # 로그 설정 (CloudWatch)
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = var.service_name
      }
    }
  }])

  tags = local.common_tags
}

# --- Security Group (보안 그룹) ---

data "aws_vpc" "this" {
  id = var.vpc_id
}

locals {
  # 기본은 VPC 안으로만 — 인터넷 egress 가 필요하면 egress_cidr_blocks 로 명시한다 (Trivy AWS-0104)
  service_egress_cidrs = length(var.egress_cidr_blocks) > 0 ? var.egress_cidr_blocks : [data.aws_vpc.this.cidr_block]
}

resource "aws_security_group" "service" {
  name_prefix = "${var.project_name}-${var.service_name}-"
  vpc_id      = var.vpc_id
  description = "ECS ${var.service_name} service security group"

  # ALB 보안 그룹에서 오는 인바운드만 허용 (CIDR 이 아니라 SG 참조)
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    description     = "Allow traffic from ALB security group"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.service_egress_cidrs
    description = "Outbound to VPC (or explicit egress_cidr_blocks)"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# --- ALB Target Group (로드밸런서 대상 그룹) ---

resource "aws_lb_target_group" "service" {
  name        = "${var.project_name}-${var.service_name}-${var.environment}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"   # Fargate는 IP 타겟 타입 사용

  # ALB 헬스체크 설정
  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30        # 검사 간격(초)
    timeout             = 5         # 응답 대기(초)
    healthy_threshold   = 2         # 정상 판단 횟수
    unhealthy_threshold = 3         # 비정상 판단 횟수
  }

  # 기존 연결 종료 대기 시간
  deregistration_delay = 30

  tags = local.common_tags
}

# --- ECS Service (서비스) ---

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # 네트워크 설정 (프라이빗 서브넷에 배치)
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false   # 프라이빗 서브넷이므로 퍼블릭 IP 불필요
  }

  # 로드밸런서 연결
  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  # 롤링 배포 설정
  deployment_maximum_percent         = 200   # 배포 중 최대 Task 수 (2배까지 허용)
  deployment_minimum_healthy_percent = 100   # 배포 중 최소 정상 Task 수 (무중단 배포)

  # Circuit Breaker (배포 실패 시 자동 롤백)
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [desired_count]   # Auto Scaling이 관리하므로 무시
  }
}

# --- Auto Scaling (오토 스케일링) ---

resource "aws_appautoscaling_target" "service" {
  max_capacity       = var.desired_count * 4   # 최대 4배까지 확장
  min_capacity       = var.desired_count
  resource_id        = "service/${var.cluster_id}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU 기반 스케일링 (평균 CPU 70% 유지)
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0   # CPU 70% 목표
    scale_in_cooldown  = 300    # 축소 대기 시간(초)
    scale_out_cooldown = 60     # 확장 대기 시간(초)
  }
}

# 메모리 기반 스케일링 (평균 메모리 75% 유지)
resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 75.0   # 메모리 75% 목표
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# --- Outputs ---

output "service_name" {
  description = "ECS 서비스 이름"
  value       = aws_ecs_service.service.name
}

output "task_definition_arn" {
  description = "Task Definition ARN"
  value       = aws_ecs_task_definition.service.arn
}

output "target_group_arn" {
  description = "ALB Target Group ARN"
  value       = aws_lb_target_group.service.arn
}

output "security_group_id" {
  description = "서비스 보안 그룹 ID"
  value       = aws_security_group.service.id
}

output "log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.service.name
}
