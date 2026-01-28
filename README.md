# Classroom Attendance Service (Terraform on AWS)

This repo provisions AWS infrastructure for a **Classroom Attendance service** using the **default nginx welcome page** as the “application”.
The focus is on **high availability**, **low latency**, **simplicity**, **security**, **observability**, and **testability**.

The service is deployed in **eu-west-1 (Ireland)**.

---

## Directory Structure

infra
├── app
│   ├── alb.tf
│   ├── cloudfront.tf
│   ├── ecs.tf
│   ├── locals.tf
│   ├── network.tf
│   ├── outputs.tf
│   ├── security.tf
│   └── variables.tf
└── environments
    ├── dev
    │   ├── main.tf
    │   ├── providers.tf
    │   └── terraform.tfvars
    └── prod
        ├── main.tf
        ├── providers.tf
        └── terraform.tfvars

## High-level goals

**SLOs**

- **99.99% success rate**
- **99.99% of responses < 300ms**

**Design priorities**

- **Smaller amount of high-quality code** over lots of partially implemented features
- **Simple, reliable primitives** (managed AWS services, minimal moving parts)
- **Clear separation** between shared infrastructure and environment-specific configuration

---

## Infrastructure design (overview)

                   Internet Users
                        |
                        |  HTTPS (TLS at edge)
                        v
            +---------------------------+
            |   CloudFront (global)     |
            |  - redirects to HTTPS     |
            |  - caching disabled       |
            +-------------+-------------+
                          |
                          | HTTP (origin fetch)
                          v
              +------------------------+
              |  ALB (public subnets)  |
              |  Listener: :80         |
              |  TargetGroup: :80      |
              +-----------+------------+
                          |
                          | HTTP :80 (SG allows only ALB -> ECS)
                          v
        +-------------------------------------------+
        |            VPC (10.20.0.0/16)             |
        |                                           |
        |  AZ-a                      AZ-b           |
        |  ---------                 ---------      |
        |  Public Subnet             Public Subnet   |
        |   - ALB ENI                - ALB ENI       |
        |   - NAT GW (one AZ)                        |
        |                                           |
        |  Private Subnet            Private Subnet  |
        |   - ECS Task (nginx)       - ECS Task      |
        |   - no public IP           - no public IP  |
        +-------------------------------------------+
                          |
                          | logs
                          v
                 CloudWatch Logs (/ecs/<name>)


“Traffic enters via CloudFront for HTTPS and edge reliability. CloudFront forwards to an ALB in public subnets. The ALB routes to ECS Fargate tasks running nginx in private subnets across two AZs. Security groups enforce ALB→ECS only. Logs go to CloudWatch. This is intentionally simple and production-aligned, with CloudFront improving tail latency and availability while keeping the origin stack minimal.”


## Core components

- **CloudFront** provides the public **HTTPS** endpoint and improves tail latency by terminating TLS at the edge and using AWS backbone routing.
- **ALB** routes requests to the ECS service.
- **ECS Fargate** runs nginx without managing any servers.
- **VPC** spans two Availability Zones with:
  - **Public subnets** for ALB + NAT
  - **Private subnets** for ECS tasks
- **CloudWatch Logs** collects container logs via awslogs.

---

## Why these decisions were made

### Why CloudFront?

- Provides an **HTTPS endpoint immediately** without needing to manage a custom domain + ACM validation in the timebox.
- Helps with the latency SLO by terminating TLS and leveraging the AWS global edge + backbone.
- Provides a clean upgrade path to multi-region later (CloudFront origin failover).

### Why a single region (multi-AZ)?

- For the exercise scope, **multi-AZ within a region** provides strong availability with minimal complexity.
- True 99.99 across regional outages typically requires **multi-region**, but that increases complexity significantly.
- This design keeps multi-region “in mind” by fronting the service with CloudFront, making failover easier later.

### Why ECS Fargate?

- No instance management, patching, or autoscaling groups.
- Easy to run a simple containerised workload (nginx) reliably.
- Keeps infrastructure simple and production-aligned.

### Why private subnets for tasks?

- Reduces attack surface: tasks have **no public IP**.
- Only the ALB security group can reach the tasks.

### Why no canary / synthetic scripts?

- The exercise explicitly values **small, high-quality** implementations.
- Browser-based canaries (Puppeteer) can be flaky/noisy, which is not ideal under interview time constraints.
- Observability is addressed via **CloudFront + ALB metrics** and container logs.
- A canary is a natural future enhancement, but intentionally omitted here to keep the solution robust and simple.

---

## SLO measurement approach (pragmatic)

### Success rate (99.99%)

Primary signals:

- **CloudFront edge 5xx** (user-facing)
- **ALB 5xx** (origin-facing)

These are based on **real traffic**, not synthetic tests.

### Latency (99.99% < 300ms)

Primary signals:

- **ALB TargetResponseTime** (origin responsiveness)
- CloudFront edge performance characteristics (TLS + edge routing)

In a production implementation, this would be complemented with:

- Load tests (k6) to validate percentile performance
- Optional Synthetics canary for continuous external checks

---

## Network Design

Used a /16 VPC to give enough address space for clean subnetting and future growth. It allows me to carve out multiple /20 subnets per AZ without worrying about IP exhaustion, while keeping the design simple.”

---

## Repository structure

infra/
  app/                      # Shared infrastructure blueprint (all reusable code)
    variables.tf            # Inputs for the shared module
    locals.tf               # Derived values (AZs) + common tags
    network.tf              # VPC, subnets, routes, NAT
    security.tf             # Security groups (ALB, ECS)
    alb.tf                  # ALB, target group, listener
    ecs.tf                  # ECS cluster, task def, service, logs
    cloudfront.tf           # CloudFront HTTPS distribution
    outputs.tf              # Public endpoints to test/demo

  environments/             # Thin environment wrappers (env-specific values only)
    dev/
      providers.tf          # AWS provider config for dev
      main.tf               # Calls ../../app module
      terraform.tfvars      # dev values (name, desired_count, etc.)
    prod/
      providers.tf          # AWS provider config for prod
      main.tf               # Calls ../../app module
      terraform.tfvars      # prod values (name, desired_count, etc.)
