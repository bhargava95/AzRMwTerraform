# Main Terraform Configuration File

provider "azurerm" {
  features {}
}

# Web Application Firewall and Application Gateway
module "app_gateway" {
  source = "./modules/app-gateway"
 
provider "azurerm" {
  features {}
}

resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = "rg-shared-westeurope-01"
  location            = "westeurope"
  name                = "appgw-api"
}

module "application-gateway" {
  source  = "kumarvna/application-gateway/azurerm"
  version = "1.1.0"

  resource_group_name  = "rg-shared-westeurope-01"
  location             = "westeurope"
  virtual_network_name = "vnet-shared-hub-westeurope-001"
  subnet_name          = "snet-appgateway"
  app_gateway_name     = "testgateway"

 sku = {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration = {
    min_capacity = 1
    max_capacity = 15
  }

  backend_address_pools = [
    {
      name  = "appgw-testgateway-westeurope-bapool01"
      fqdns = ["example1.com", "example2.com"]
    },
    {
      name         = "appgw-testgateway-westeurope-bapool02"
      ip_addresses = ["1.2.3.4", "2.3.4.5"]
    }
  ]

   backend_http_settings = [
    {
      name                  = "appgw-testgateway-westeurope-be-http-set1"
      cookie_based_affinity = "Disabled"
      path                  = "/"
      enable_https          = true
      request_timeout       = 30
      # probe_name            = "appgw-testgateway-westeurope-probe1"
      # Remove this if `health_probes` object is not defined.
      connection_draining = {
        enable_connection_draining = true
        drain_timeout_sec          = 300

      }
    },
    {
      name                  = "appgw-testgateway-westeurope-be-http-set2"
      cookie_based_affinity = "Enabled"
      path                  = "/"
      enable_https          = false
      request_timeout       = 30
    }
  ]

  http_listeners = [
    {
      name                 = "appgw-testgateway-westeurope-be-htln01"
      ssl_certificate_name = "appgw-testgateway-westeurope-ssl01"
      host_name            = null
    }
  ]

   request_routing_rules = [
    {
      name                       = "appgw-testgateway-westeurope-be-rqrt"
      rule_type                  = "Basic"
      http_listener_name         = "appgw-testgateway-westeurope-be-htln01"
      backend_address_pool_name  = "appgw-testgateway-westeurope-bapool01"
      backend_http_settings_name = "appgw-testgateway-westeurope-be-http-set1"
    }
  ]

  ssl_certificates = [{
    name     = "appgw-testgateway-westeurope-ssl01"
    data     = "./keyBag.pfx"
    password = "P@$$w0rd123"
  }]

  waf_configuration = {
    firewall_mode            = "Detection"
    rule_set_version         = "3.1"
    file_upload_limit_mb     = 100
    max_request_body_size_kb = 128

    disabled_rule_group = [
      {
        rule_group_name = "REQUEST-930-APPLICATION-ATTACK-LFI"
        rules           = ["930100", "930110"]
      },
      {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rules           = ["920160"]
      }
    ]

    exclusion = [
      {
        match_variable          = "RequestCookieNames"
        selector                = "SomeCookie"
        selector_match_operator = "Equals"
      },
      {
        match_variable          = "RequestHeaderNames"
        selector                = "referer"
        selector_match_operator = "Equals"
      }
    ]
  }

  # A list with a single user managed identity id to be assigned to access Keyvault
  identity_ids = ["${azurerm_user_assigned_identity.example.id}"]
  log_analytics_workspace_name = "loganalytics-we-sharedtest2"

  # Adding TAG's to Azure resources
  tags = {
    ProjectName  = "demo-internal"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
}

}

# API Manager
module "api_manager" {
  source = "./modules/api-manager"
  resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_api_management" "example" {
  name                = "example-apim"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  publisher_name      = "My Company"
  publisher_email     = "company@terraform.io"

  sku_name = "Developer_1"
}
}

# Application on Linux server with Docker container managed by Kubernetes
module "kubernetes" {
  source = "./modules/kubernetes"
provider "kubernetes" {
  host                   = module.aks.host
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  }

  resource "azurerm_resource_group" "rg" {
  location = "eastus"
  name     = random_pet.name
  }
}

# SQL Managed Instances
module "sql_managed_instance" {
  source = "./modules/sql-managed-instance"
  version = "4.21.2"
  resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
  base_tags	= {
    "environment" = "dev"
    "costcenter"  = "it"
  }

  global_settings = {
    "diagnostic_storage_account_name" = "diagstorageaccount"
    "diagnostic_storage_account_sas_token" = "sastoken"
    "diagnostic_storage_account_key" = "storageaccountkey"
  }

  primary_server_id = "primaryserverid"

  resource_group_name = azurerm_resource_group.example.name
  subnet_id          = azurerm_subnet.example.id
 }
}

# Outputs from modules can be accessed as:
# output "some_output" {
#   value = module.module_name.output_name
# }
