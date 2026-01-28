output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "https_url" {
  value = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
}
