module "app" {
  source = "../../app"

  aws_region    = var.aws_region
  name          = var.name
  desired_count = var.desired_count
  is_prod       = var.is_prod
}
