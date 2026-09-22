variable "name" {
  type        = string
  description = "The display name of the application registration"
}

variable "description" {
  type        = string
  description = "Description of the application registration"
  default     = null
}

variable "sign_in_audience" {
  type        = string
  description = "Audience for the app registration (for example AzureADMyOrg, AzureADMultipleOrgs)"
  default     = "AzureADMyOrg"

  validation {
    condition = contains([
      "AzureADMyOrg",
      "AzureADMultipleOrgs",
      "AzureADandPersonalMicrosoftAccount",
      "PersonalMicrosoftAccount"
    ], var.sign_in_audience)
    error_message = "sign_in_audience must be one of AzureADMyOrg, AzureADMultipleOrgs, AzureADandPersonalMicrosoftAccount, PersonalMicrosoftAccount."
  }
}

variable "application_owners" {
  type        = set(string)
  description = "Object IDs that own the application registration"
  default     = []
}

variable "group_membership_claims" {
  type        = set(string)
  description = "Optional group claims included in tokens"
  default     = []

  validation {
    condition = alltrue([
      for claim in var.group_membership_claims : contains([
        "None",
        "SecurityGroup",
        "DirectoryRole",
        "ApplicationGroup",
        "All"
      ], claim)
    ])
    error_message = "group_membership_claims values must be one of None, SecurityGroup, DirectoryRole, ApplicationGroup, All."
  }
}

variable "notes" {
  type        = string
  description = "User-specified operational notes for the application"
  default     = null
}

variable "federated_credentials" {
  type = map(object({
    name         = optional(string)
    display_name = optional(string)
    description  = optional(string)
    audiences    = optional(list(string), ["api://AzureADTokenExchange"])
    issuer       = optional(string)
    issuer_url   = optional(string)
    subject      = string
  }))
  description = "Map of federated identity credentials. Supports issuer or issuer_url and display_name or name for compatibility."
  default     = {}

  validation {
    condition = alltrue([
      for credential in values(var.federated_credentials) : (
        try(credential.issuer, null) != null || try(credential.issuer_url, null) != null
      )
    ])
    error_message = "Each federated credential must provide either issuer or issuer_url."
  }
}

variable "redirect_uris" {
  type        = list(string)
  description = "List of redirect URIs for the application"
  default     = []
}

variable "web_implicit_grant" {
  type = object({
    access_token_issuance_enabled = optional(bool, false)
    id_token_issuance_enabled     = optional(bool, false)
  })
  description = "Implicit grant settings for web applications"
  default     = null
}

variable "homepage_url" {
  type        = string
  description = "Homepage URL for web app SSO"
  default     = null
}

variable "logout_url" {
  type        = string
  description = "Logout URL for web app SSO"
  default     = null
}

variable "spa_redirect_uris" {
  type        = list(string)
  description = "Redirect URIs for SPA clients"
  default     = []
}

variable "public_client_redirect_uris" {
  type        = list(string)
  description = "Redirect URIs for public/native clients"
  default     = []
}

variable "requested_access_token_version" {
  type        = number
  description = "Requested access token version for API configuration"
  default     = null

  validation {
    condition     = var.requested_access_token_version == null || contains([1, 2], var.requested_access_token_version)
    error_message = "requested_access_token_version must be null, 1, or 2."
  }
}

variable "oauth2_permission_scopes" {
  type = map(object({
    admin_consent_description  = string
    admin_consent_display_name = string
    user_consent_description   = string
    user_consent_display_name  = string
    value                      = string
    type                       = optional(string, "User")
  }))
  description = "OAuth2 permission scopes exposed by this application"
  default     = {}

  validation {
    condition = alltrue([
      for scope in values(var.oauth2_permission_scopes) : contains(["User", "Admin"], scope.type)
    ])
    error_message = "oauth2_permission_scopes.type must be User or Admin."
  }
}

variable "pre_authorized_applications" {
  type = map(object({
    authorized_client_id = optional(string)
    scope_keys           = list(string)
  }))
  description = "Client applications allowed to obtain this application's scopes without a user consent prompt. scope_keys must reference entries in oauth2_permission_scopes. If authorized_client_id is omitted, this application's own client ID is used, which is the single-registration frontend plus backend case."
  default     = {}

  validation {
    condition = alltrue([
      for client in values(var.pre_authorized_applications) : alltrue([
        for scope_key in client.scope_keys : contains(keys(var.oauth2_permission_scopes), scope_key)
      ])
    ])
    error_message = "Each pre_authorized_applications.scope_keys entry must reference an existing key in oauth2_permission_scopes."
  }

  validation {
    condition = alltrue([
      for client in values(var.pre_authorized_applications) : length(client.scope_keys) > 0
    ])
    error_message = "Each pre_authorized_applications entry must list at least one scope key."
  }
}

variable "app_roles" {
  type = map(object({
    allowed_member_types = list(string)
    description          = string
    display_name         = string
    value                = string
  }))
  description = "App roles exposed by this application"
  default     = {}

  validation {
    condition = alltrue([
      for role in values(var.app_roles) : alltrue([
        for member_type in role.allowed_member_types : contains(["User", "Application"], member_type)
      ])
    ])
    error_message = "app_roles.allowed_member_types values must be User and/or Application."
  }
}

variable "api_access" {
  type = map(object({
    api_client_id = string
    role_ids      = optional(list(string), [])
    scope_ids     = optional(list(string), [])
  }))
  description = "API permissions this application requires. Keyed by a logical name. Use scope_ids for delegated (Scope) permissions and role_ids for application (Role) permissions."
  default     = {}
}

variable "optional_claims" {
  type = object({
    access_token = optional(list(object({
      name                  = string
      source                = optional(string)
      essential             = optional(bool)
      additional_properties = optional(list(string), [])
    })), [])
    id_token = optional(list(object({
      name                  = string
      source                = optional(string)
      essential             = optional(bool)
      additional_properties = optional(list(string), [])
    })), [])
    saml2_token = optional(list(object({
      name                  = string
      source                = optional(string)
      essential             = optional(bool)
      additional_properties = optional(list(string), [])
    })), [])
  })
  description = "Optional claims configuration for access, ID and SAML tokens"
  default     = null
}

variable "service_principal_owners" {
  type        = set(string)
  description = "Object IDs that own the service principal"
  default     = []
}

variable "service_principal_account_enabled" {
  type        = bool
  description = "Whether the service principal account is enabled"
  default     = true
}

variable "service_principal_app_role_assignment_required" {
  type        = bool
  description = "Whether users and apps need app role assignment to access the app"
  default     = false
}

variable "passwords" {
  type = map(object({
    display_name        = optional(string)
    start_date          = optional(string)
    end_date            = optional(string)
    rotate_when_changed = optional(map(string), {})
  }))
  description = "Application client secrets to create"
  default     = {}
}

variable "app_role_assignments" {
  type = map(object({
    app_role_key        = string
    resource_object_id  = optional(string)
    principal_object_id = optional(string)
  }))
  description = "App role assignments. app_role_key must reference an entry in app_roles. If resource_object_id is omitted, the created service principal is used. If principal_object_id is omitted, the created service principal is used."
  default     = {}

  validation {
    condition = alltrue([
      for assignment in values(var.app_role_assignments) : contains(keys(var.app_roles), assignment.app_role_key)
    ])
    error_message = "Each app_role_assignment.app_role_key must reference an existing key in app_roles."
  }
}
