output "application_id" {
  description = "The Terraform resource ID of the Azure AD application"
  value       = azuread_application_registration.this.id
}

output "client_id" {
  description = "The client ID of the application"
  value       = azuread_application_registration.this.client_id
}

output "object_id" {
  description = "The object ID of the application"
  value       = azuread_application_registration.this.object_id
}

output "service_principal_object_id" {
  description = "The object ID of the service principal"
  value       = azuread_service_principal.this.object_id
}

output "app_role_ids" {
  description = "Generated app role IDs by key"
  value = {
    for key, role in random_uuid.app_role : key => role.result
  }
}

output "oauth2_permission_scope_ids" {
  description = "Generated OAuth2 permission scope IDs by key"
  value = {
    for key, scope in random_uuid.oauth2_scope : key => scope.result
  }
}

output "federated_credential_ids" {
  description = "Created federated identity credential IDs"
  value = {
    for key, credential in azuread_application_federated_identity_credential.this : key => credential.id
  }
}

output "app_role_assignment_ids" {
  description = "Created app role assignment IDs"
  value = {
    for key, assignment in azuread_app_role_assignment.this : key => assignment.id
  }
}

output "identifier_uri_id" {
  description = "Created identifier URI resource ID"
  value       = azuread_application_identifier_uri.this.id
}

output "identifier_uri" {
  description = "The Application ID URI (identifier URI)"
  value       = azuread_application_identifier_uri.this.identifier_uri
}

output "password_values" {
  description = "Created application secret values by key"
  value = {
    for key, password in azuread_application_password.this : key => password.value
  }
  sensitive = true
}
