variable "AWS_ACCOUNT" {
  description = "The AWS account resources will be deployed to."
}

variable "AWS_REGION" {
  description = "The AWS region the resources will be deployed to."
  default     = "us-east-1"
}

variable "AWS_ROLE_ARN" {
  description = "The role Terraform uses to deploy the resources."
  default     = ""
}

variable "ENVIRONMENT" {
  description = "The target deployment environment, e.g. 'DEV', 'QA', 'UAT', or 'PRD'."
}