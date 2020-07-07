//  Copyright © Microsoft Corporation
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.


/*
.Synopsis
   Terraform Main Control
.DESCRIPTION
   This file holds the main control and resoures for bootstraping an OSDU Azure Devops Project.
*/

terraform {
  required_version = ">= 0.12"
  backend "azurerm" {
    key = "terraform.tfstate"
  }
}


#-------------------------------
# Providers
#-------------------------------
provider "azurerm" {
  version = "=2.16.0"
  features {}
}

provider "random" {
  version = "~>2.2"
}


#-------------------------------
# Application Variables  (variables.tf)
#-------------------------------
variable "prefix" {
  description = "(Required) An identifier used to construct the names of all resources in this template."
  type        = string
}

variable "resource_group_location" {
  description = "The Azure region where container registry resources in this template should be created."
  type        = string
}

variable "container_registry_sku" {
  description = "(Optional) The SKU name of the the container registry. Possible values are Basic, Standard and Premium."
  type        = string
  default     = "Standard"
}


#-------------------------------
# Private Variables  (common.tf)
#-------------------------------
locals {
  workspace               = replace(trimspace(lower(terraform.workspace)), "-", "")
  resource_group_name     = format("%s-%s-%s-rg", var.prefix, local.workspace, random_string.naming_scope.result)
  container_registry_name = format("%s%s%sacr", var.prefix, local.workspace, random_string.naming_scope.result)
}


#-------------------------------
# Common Resources  (common.tf)
#-------------------------------
resource "random_string" "naming_scope" {
  keepers = {
    # Generate a new id each time we switch to a new workspace or app id
    ws_name = replace(trimspace(lower(terraform.workspace)), "-", "")
    prefix  = replace(trimspace(lower(var.prefix)), "_", "-")
  }

  length  = 4
  special = false
  upper   = false
}


#-------------------------------
# Resource Group
#-------------------------------
resource "azurerm_resource_group" "container_rg" {
  name     = local.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_management_lock" "container_rg" {
  name       = "osdu_ir_rg_lock"
  scope      = azurerm_resource_group.storage_rg.id
  lock_level = "CanNotDelete"
}


#-------------------------------
# Container Registry
#-------------------------------
module "container_registry" {
  source = "../../../../modules/providers/azure/container-registry"

  container_registry_name = local.container_registry_name
  resource_group_name     = azurerm_resource_group.container_rg.name

  container_registry_sku           = var.container_registry_sku
  container_registry_admin_enabled = false
}

resource "azurerm_management_lock" "acr_lock" {
  name       = "osdu_acr_lock"
  scope      = module.container_registry.container_registry_id
  lock_level = "CanNotDelete"
}


#-------------------------------
# Output Variables  (output.tf)
#-------------------------------
output "container_registry_id" {
  description = "The resource identifier of the container registry."
  value       = module.container_registry.container_registry_id
}

output "container_registry_name" {
  description = "The name of the container registry."
  value       = module.container_registry.container_registry_name
}