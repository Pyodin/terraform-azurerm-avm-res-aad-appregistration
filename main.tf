# Application registration - lightweight foundational resource
data "azuread_client_config" "current" {}

locals {
  optional_claims = coalesce(var.optional_claims, {
    access_token = []
    id_token     = []
    saml2_token  = []
  })

  should_create_optional_claims_block = (
    length(local.optional_claims.access_token) > 0 ||
    length(local.optional_claims.id_token) > 0 ||
    length(local.optional_claims.saml2_token) > 0
  )
}

resource "azuread_application_registration" "this" {
  display_name     = var.name
  description      = var.description
  sign_in_audience = var.sign_in_audience
  notes            = var.notes

  homepage_url = var.homepage_url
  logout_url   = var.logout_url

  group_membership_claims                = length(var.group_membership_claims) > 0 ? var.group_membership_claims : null
  implicit_access_token_issuance_enabled = try(var.web_implicit_grant.access_token_issuance_enabled, false)
  implicit_id_token_issuance_enabled     = try(var.web_implicit_grant.id_token_issuance_enabled, false)
  requested_access_token_version         = var.requested_access_token_version

  timeouts {
    create = "10m"
    read   = "5m"
    update = "10m"
    delete = "5m"
  }
}

# Identifier URIs - separated from registration
resource "azuread_application_identifier_uri" "this" {
  application_id = azuread_application_registration.this.id
  identifier_uri = "api://${azuread_application_registration.this.client_id}"
}

# Application owners
resource "azuread_application_owner" "this" {
  for_each = var.application_owners

  application_id  = azuread_application_registration.this.id
  owner_object_id = each.key
}

# App roles - separated from registration
resource "azuread_application_app_role" "this" {
  for_each = var.app_roles

  application_id       = azuread_application_registration.this.id
  role_id              = random_uuid.app_role[each.key].result
  allowed_member_types = each.value.allowed_member_types
  description          = each.value.description
  display_name         = each.value.display_name
  value                = each.value.value
}

# OAuth2 permission scopes - separated from registration
resource "azuread_application_permission_scope" "this" {
  for_each = var.oauth2_permission_scopes

  application_id             = azuread_application_registration.this.id
  scope_id                   = random_uuid.oauth2_scope[each.key].result
  admin_consent_description  = each.value.admin_consent_description
  admin_consent_display_name = each.value.admin_consent_display_name
  user_consent_description   = each.value.user_consent_description
  user_consent_display_name  = each.value.user_consent_display_name
  type                       = try(each.value.type, "User")
  value                      = each.value.value
}

# Pre-authorized client applications - clients that skip the user consent prompt
resource "azuread_application_pre_authorized" "this" {
  for_each = var.pre_authorized_applications

  application_id = azuread_application_registration.this.id

  # Omitting authorized_client_id pre-authorizes this application against itself,
  # for a frontend and a backend sharing one registration.
  authorized_client_id = coalesce(each.value.authorized_client_id, azuread_application_registration.this.client_id)

  permission_ids = [
    for scope_key in each.value.scope_keys : random_uuid.oauth2_scope[scope_key].result
  ]

  # The scopes must exist on the application before they can be pre-authorized.
  depends_on = [azuread_application_permission_scope.this]

  lifecycle {
    precondition {
      condition = alltrue([
        for scope_key in each.value.scope_keys : contains(keys(var.oauth2_permission_scopes), scope_key)
      ])
      error_message = "scope_keys must reference existing keys in oauth2_permission_scopes."
    }
  }
}

# Optional claims - separated from registration
resource "azuread_application_optional_claims" "this" {
  count = local.should_create_optional_claims_block ? 1 : 0

  application_id = azuread_application_registration.this.id

  dynamic "access_token" {
    for_each = local.optional_claims.access_token
    content {
      name                  = access_token.value.name
      source                = try(access_token.value.source, null)
      essential             = try(access_token.value.essential, false)
      additional_properties = try(access_token.value.additional_properties, [])
    }
  }

  dynamic "id_token" {
    for_each = local.optional_claims.id_token
    content {
      name                  = id_token.value.name
      source                = try(id_token.value.source, null)
      essential             = try(id_token.value.essential, false)
      additional_properties = try(id_token.value.additional_properties, [])
    }
  }

  dynamic "saml2_token" {
    for_each = local.optional_claims.saml2_token
    content {
      name                  = saml2_token.value.name
      source                = try(saml2_token.value.source, null)
      essential             = try(saml2_token.value.essential, false)
      additional_properties = try(saml2_token.value.additional_properties, [])
    }
  }
}

# Web redirect URIs - separated from registration
resource "azuread_application_redirect_uris" "web" {
  count = length(var.redirect_uris) > 0 ? 1 : 0

  application_id = azuread_application_registration.this.id
  type           = "Web"
  redirect_uris  = var.redirect_uris
}

# Single-Page Application redirect URIs
resource "azuread_application_redirect_uris" "spa" {
  count = length(var.spa_redirect_uris) > 0 ? 1 : 0

  application_id = azuread_application_registration.this.id
  type           = "SPA"
  redirect_uris  = var.spa_redirect_uris
}

# Public/Native client redirect URIs
resource "azuread_application_redirect_uris" "public_client" {
  count = length(var.public_client_redirect_uris) > 0 ? 1 : 0

  application_id = azuread_application_registration.this.id
  type           = "PublicClient"
  redirect_uris  = var.public_client_redirect_uris
}

resource "random_uuid" "app_role" {
  for_each = var.app_roles
}

resource "random_uuid" "oauth2_scope" {
  for_each = var.oauth2_permission_scopes
}

# API permissions
resource "azuread_application_api_access" "this" {
  for_each = var.api_access

  application_id = azuread_application_registration.this.id
  api_client_id  = each.value.api_client_id

  role_ids  = each.value.role_ids
  scope_ids = each.value.scope_ids
}

# Application passwords
resource "azuread_application_password" "this" {
  for_each = var.passwords

  application_id      = azuread_application_registration.this.id
  display_name        = each.value.display_name
  start_date          = try(each.value.start_date, null)
  end_date            = each.value.end_date
  rotate_when_changed = each.value.rotate_when_changed
}

# Federated identity credentials
resource "azuread_application_federated_identity_credential" "this" {
  for_each = var.federated_credentials

  application_id = azuread_application_registration.this.id
  display_name   = coalesce(try(each.value.display_name, null), try(each.value.name, null), each.key)
  description    = try(each.value.description, null)
  audiences      = try(each.value.audiences, ["api://AzureADTokenExchange"])
  issuer         = coalesce(try(each.value.issuer, null), try(each.value.issuer_url, null))
  subject        = each.value.subject
}

# Enterprise application (service principal)
resource "azuread_service_principal" "this" {
  client_id                    = azuread_application_registration.this.client_id
  owners                       = toset(concat([data.azuread_client_config.current.object_id], tolist(var.service_principal_owners)))
  account_enabled              = var.service_principal_account_enabled
  app_role_assignment_required = var.service_principal_app_role_assignment_required

  timeouts {
    create = "10m"
    read   = "5m"
    update = "10m"
    delete = "5m"
  }

  depends_on = [azuread_application_registration.this]
}

# App role assignments
resource "azuread_app_role_assignment" "this" {
  for_each = var.app_role_assignments

  app_role_id         = azuread_application_app_role.this[each.value.app_role_key].role_id
  principal_object_id = coalesce(each.value.principal_object_id, azuread_service_principal.this.object_id)
  resource_object_id  = coalesce(each.value.resource_object_id, azuread_service_principal.this.object_id)

  depends_on = [
    azuread_application_app_role.this,
    azuread_service_principal.this
  ]

  lifecycle {
    precondition {
      condition     = contains(keys(var.app_roles), each.value.app_role_key)
      error_message = "app_role_key must reference an existing key in app_roles."
    }
  }
}

