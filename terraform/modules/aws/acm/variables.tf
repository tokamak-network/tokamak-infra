variable "parent_domain" {
  description = "Parent Domain"
  type        = string
}

variable "service_names" {
  description = "Service Names"
  type        = list(string)
}
