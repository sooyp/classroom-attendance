data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Project     = "classroom-attendance"
    Environment = var.is_prod ? "prod" : "dev"
    ManagedBy   = "terraform"
    Criticality = var.is_prod ? "high" : "low"
  }
}
