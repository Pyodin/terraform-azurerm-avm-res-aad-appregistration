# app-registration

One Entra ID application registration and its service principal. Everything else is
optional: exposed scopes, app roles, pre-authorized clients, API permissions, redirect
URIs, optional claims, secrets and federated credentials.

The module manages a single application. Wrap it in `for_each` to manage several.

## Minimal

```hcl
module "app" {
  source = "../../modules/app-registration"

  name = "app-example"
}
```

## Restricting who can use an application

Set `service_principal_app_role_assignment_required` and only assigned users and groups
can sign in. An app role gives the assignment something to target, which is what makes
the grant declarative instead of a click in the portal.

This is how `platform/identity` gates the point-to-site VPN: the Microsoft-registered
Azure VPN Client belongs to Microsoft and carries no assignments, so the gateway points
at an application of our own instead.

```hcl
module "vpn_audience" {
  source = "../../../modules/app-registration"

  name = "app-vpn-hub-prod-frc-001"

  service_principal_app_role_assignment_required = true

  oauth2_permission_scopes = {
    p2s_vpn = {
      admin_consent_description  = "Connect to the point-to-site VPN gateway"
      admin_consent_display_name = "Connect to the P2S VPN"
      user_consent_description   = "Connect to the point-to-site VPN gateway"
      user_consent_display_name  = "Connect to the P2S VPN"
      value                      = "p2s-vpn"
      type                       = "Admin"
    }
  }

  # Pre-authorized clients obtain the scope without a consent prompt.
  pre_authorized_applications = {
    azure_vpn_client = {
      authorized_client_id = "c632b3df-fb67-4d84-bdcf-b95ad541b5c8"
      scope_keys           = ["p2s_vpn"]
    }
  }

  app_roles = {
    vpn_user = {
      allowed_member_types = ["User"]
      description          = "Members may connect to the VPN."
      display_name         = "VPN User"
      value                = "VpnUser"
    }
  }

  app_role_assignments = {
    for group_object_id in local.vpn_user_group_object_ids : group_object_id => {
      app_role_key        = "vpn_user"
      principal_object_id = group_object_id
    }
  }
}
```

Omit `authorized_client_id` to pre-authorize the application against its own client ID,
which is the case where a frontend and a backend share one registration.

## Workload identity

Federated credentials replace a secret with a trust relationship, so a pod gets Entra ID
tokens with nothing stored in the cluster.

```hcl
module "workload" {
  source = "../../modules/app-registration"

  name = "app-demo-api"

  federated_credentials = {
    demo = {
      issuer  = module.kubernetes_cluster.oidc_issuer_url
      subject = "system:serviceaccount:demo:demo-sa"
    }
  }
}
```

## Notes

- The Application ID URI is always set to `api://<client_id>`.
- A service principal is always created, and the current Terraform identity always owns
  it so later runs stay authorized. `service_principal_owners` adds others.
- `password_values` is sensitive. Prefer `federated_credentials` and create secrets only
  where a client genuinely cannot federate.
- `issuer` and `issuer_url`, and `display_name` and `name`, are both accepted on a
  federated credential.

## Requirements

Terraform `>= 1.11`, providers `hashicorp/azuread` and `hashicorp/random`. Declare both
in the calling root: the module does not carry its own `required_providers`.
# terraform-azurerm-avm-res-aad-appregistration
