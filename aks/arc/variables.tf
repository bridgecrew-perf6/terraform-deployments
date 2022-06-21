variable "prefix" {
  description = "A prefix used for all resources in this example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be provisioned"
}

variable "subscription_id" {
  description = "The Azure Subscription ID in which all resources should be provisioned in"
}

variable "client_id" {
    description = "The client id of the service principal"
}

variable "client_secret" {
  description = "The client secret of the service principal"
}

variable "tenant_id" {
  description = "The Azure Tenant ID in which all resources should be provisioned in"
}

#variable "client_certificate_path" {
#    description = "The path to the client certificate used to authenticate"
#}
#
#variable "client_certificate_password" {
#  description = "The password for the client certificate used to authenticate"
#}
