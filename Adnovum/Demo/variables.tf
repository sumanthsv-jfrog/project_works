variable "jfrog_url" {
  description = "JFrog instance URL"
  type        = string
  sensitive   = false
}

variable "jfrog_access_token" {
  description = "JFrog access token"
  type        = string
  sensitive   = true
}
