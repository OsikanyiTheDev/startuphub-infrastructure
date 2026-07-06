variable "ssh_cidr" {
    description = "The CIDR block for SSH access."
    type        = list(string)
}

variable "http_cidr" {
    description = "The CIDR block for HTTP access."
    type        = list(string)
    default     = ["0.0.0.0/0"]
}