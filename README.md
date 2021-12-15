# Application Gateway with mulitple sites

This sample illustrates how to deploy an Azure Application Gateway instance with multiple sites. The sample deploys two virtual machines configured as web servers, and then deploys an application gateway that routes traffic to one site to the first virtual machine, and traffic for the other site to the second virtual machine:

![](diagram.png)

It deploys a virtual network for the virtual machines and application gateway to use.

The sample shows how to use a single wildcard SSL/TLS certificate for both sites. The certificate and its password are stored in Key Vault secrets and uses Bicep key vault references.

## Parameters

When you deploy the *main.bicep* file, you need to specify values for a number of parameters. Many have default values, but the following don't:

- `vmAdminUsername`: This will be configured as the username for the virtual machines' administrator accounts.
- `vmAdminPassword`: This will be configured as the password for the virtual machines' administrator accounts.
- `app1ExternalHostName`: This is the public-facing hostname for application 1, such as `app1.contoso.com`.
- `appsExternalHostName`: This is the public-facing hostname for application 2, such as `app2.contoso.com`.
- `sslCertificateData`: This should be a base 64-encoded string with the wildcard certificate contents, in PFX format. You can optionally use the `loadFileAsBase64('filename')` function in the Bicep file to simpify your deployment, but be sure to never commit your certificate file to source control.
- `sslCertificatePassword`: This is the password to use when reading the wildcard certificate file.

## Notes

- It's generally good practice to keep your SSL certificates in a separate key vault, and refer to them from within the deployment. For simplicity, this sample creates the key vault and secret in the same Bicep file as it uses them.
- This sample assumes you use the same wildcard SSL certificate for both sites.
- Health probes aren't used in this sample.
