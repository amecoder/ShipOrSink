# =============================================================================
# RDS PostgreSQL Module - DB Instance + Subnet Group + Security Group
# =============================================================================
# 사용법: 이 파일을 프로젝트의 infra/modules/rds/ 에 복사하세요.
#
#   module "database" {
#     source            = "./infra/modules/rds"
#     instance_class    = "db.t3.medium"
#     allocated_storage = 20
#     db_name           = "myapp"
#     vpc_id            = module.vpc.vpc_id
#     subnet_ids        = module.vpc.private_subnet_ids
#     allowed_cidr_blocks = [module.vpc.vpc_cidr]
#     environment       = "production"
#     project_name      = "myapp"
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

variable "instance_class" {
  description = "RDS 인스턴스 클래스 (예: db.t3.medium, db.r6g.large)"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "초기 스토리지 크기(GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "자동 확장 최대 스토리지(GB). 0이면 자동 확장 비활성화"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "생성할 데이터베이스 이름"
  type        = string
}

variable "db_username" {
  description = "마스터 사용자 이름"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "마스터 비밀번호 (Secrets Manager 사용 권장)"
  type        = string
  sensitive   = true   # Terraform 출력에서 마스킹
}

variable "engine_version" {
  description = "PostgreSQL 엔진 버전"
  type        = string
  default     = "16.4"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "DB를 배치할 프라이빗 서브넷 ID 목록 (최소 2개 AZ)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "DB 접근을 허용할 CIDR 블록 (VPC CIDR 등)"
  type        = list(string)
}

variable "multi_az" {
  description = "Multi-AZ 배포 여부 (production은 true 권장)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "배포 환경 (dev, staging, production)"
  type        = string
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

# --- Locals ---

locals {
  common_tags = {
    Name        = "${var.project_name}-${var.environment}-rds"
    Environment = var.environment
    Team        = var.project_name
    ManagedBy   = "terraform"
  }

  # production 환경은 자동으로 Multi-AZ 활성화
  is_production = var.environment == "production"
  multi_az      = var.multi_az || local.is_production
}

# --- DB Subnet Group (서브넷 그룹) ---

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet"
  description = "${var.project_name} ${var.environment} DB subnet group"
  subnet_ids  = var.subnet_ids   # 프라이빗 서브넷에 배치

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet"
  })
}

# --- Security Group (보안 그룹) ---

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "RDS PostgreSQL security group for ${var.project_name}"

  # PostgreSQL 포트 인바운드 (허용된 CIDR만)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "PostgreSQL access from allowed CIDRs"
  }

  # 아웃바운드 규칙 없음 — DB 는 연결을 시작하지 않는다. AWS SG 는 egress 규칙이 없으면 전부 거부한다 (Trivy AWS-0104)

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# --- RDS Instance (데이터베이스 인스턴스) ---

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}"

  # 엔진 설정
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # 스토리지 설정
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage   # 자동 확장 한도
  storage_type          = "gp3"                       # 최신 범용 SSD
  storage_encrypted     = true                        # 저장 시 암호화 활성화

  # 데이터베이스 설정
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # 네트워크 설정
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false   # 퍼블릭 접근 차단 (프라이빗 전용)

  # 가용성 설정
  multi_az = local.multi_az   # production은 자동 활성화

  # 백업 설정
  backup_retention_period = local.is_production ? 30 : 7   # production: 30일, 기타: 7일
  backup_window           = "03:00-04:00"                  # UTC 기준 백업 시간
  maintenance_window      = "sun:04:00-sun:05:00"          # 유지보수 시간

  # 삭제 보호
  skip_final_snapshot       = !local.is_production          # production은 최종 스냅샷 필수
  final_snapshot_identifier = local.is_production ? "${var.project_name}-${var.environment}-final" : null
  deletion_protection       = local.is_production           # production은 삭제 보호 활성화

  # CloudWatch 로그 내보내기 — 감사·장애 분석용 (Semgrep aws-db-instance-no-logging)
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # 성능 인사이트 (모니터링)
  performance_insights_enabled          = true
  performance_insights_retention_period = local.is_production ? 731 : 7   # production: 2년, 기타: 7일

  # 마이너 버전 자동 업그레이드
  auto_minor_version_upgrade = true

  # 파라미터 그룹 (기본값 사용, 커스텀 필요 시 별도 리소스로 분리)
  parameter_group_name = "default.postgres16"

  tags = local.common_tags
}

# --- Outputs ---

output "endpoint" {
  description = "RDS 엔드포인트 (호스트:포트)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "address" {
  description = "RDS 호스트 주소"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "port" {
  description = "RDS 포트"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "데이터베이스 이름"
  value       = aws_db_instance.main.db_name
}

output "security_group_id" {
  description = "RDS 보안 그룹 ID"
  value       = aws_security_group.rds.id
}
