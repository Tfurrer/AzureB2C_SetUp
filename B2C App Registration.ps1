# Environment: Windows
# Powershell Version: 7.4.2
# About this script: Run segments in blocks

##########################################################
#     Functions
#############################################################
function Add-AppReg {
    param(
        [Parameter(Mandatory)]
        [string] $Tenant_Secret_Name,
        [Parameter(Mandatory)]
        [string] $AZ_B2C_Domain, 
        [Parameter(Mandatory)]
        [string] $App_Reg_Name)
        $b2c_Tenant = $AZ_B2C_Domain.Replace('.onmicrosoft.com', '')
        $app_id = az ad app create --display-name $App_Reg_Name --web-redirect-uris "https://$b2c_Tenant.b2clogin.com/$b2c_Tenant.onmicrosoft.com/oauth2/authresp" --query id -o tsv
        Set-Secret -name "${Tenant_Secret_Name}_AuthAppId" -secret $app_id
        # Create the Credential for this App Registration & Save to Local Secret Store for Later
        Set-Secret -name "${Tenant_Secret_Name}_AuthCred" -secret $(az ad app credential reset --id $app_id --display-name "${Tenant_Secret_Name}_AuthCred" --years 5 --query password -o tsv)
        az logout
}
function Add-AppB2CReg {
    param(
        [Parameter(Mandatory)]
        [string]$Tenant_Secret_Name,
        [Parameter(Mandatory)] 
        [string]$App_Reg_Name)
        $app_id = az ad app create --display-name $App_Reg_Name --enable-id-token-issuance true --enable-access-token-issuance true --query id -o tsv
        Set-Secret -name "${Tenant_Secret_Name}_AuthAppId" -secret $app_id
        az rest `
            --method PATCH `
            --uri "https://graph.microsoft.com/v1.0/applications/${app_id}" `
            --headers 'Content-Type=application/json' `
            --body "{spa:{redirectUris:['http://localhost:3000']}}"

        # Create the Credential for this App Registration & Save to Local Secret Store for Later
        Set-Secret -name "${Tenant_Secret_Name}_AuthCred" -secret $(az ad app credential reset --id $app_id --display-name "${Tenant_Secret_Name}_AuthCred" --years 5 --query password -o tsv)
}

function Add-B2CIdentity {
    param(
        [Parameter(Mandatory)]
        [string]$Domain,
        [Parameter(Mandatory)]
        [string]$Group)

        $clientId = Get-Secret -name 'Agent_AuthAppId' -AsPlainText
        $clientSecret = Get-Secret -name 'Agent_AuthCred' -AsPlainText
        $params = @{
            "@odata.type" = "microsoft.graph.openIdConnectIdentityProvider"
            displayName = "Login with ${Group}"
            clientId = $clientId
            clientSecret = $clientSecret
            claimsMapping = @{
                userId = "sub"
                givenName = "given_name"
                surname = "family_name"
                email = "preferred_username"
                displayName = "name"
            }
            domainHint = ""
            metadataUrl = "https://login.microsoftonline.com/${Domain}/v2.0/.well-known/openid-configuration"
            responseMode = "form_post"
            responseType = "code"
            scope = "openid"
        }
        
        New-MgBetaIdentityProvider -BodyParameter $params
}

##########################################################
#     Imports
#############################################################
Import-Module Microsoft.Graph.Beta.Identity.SignIns

##########################################################
#     Create Variables
#############################################################
$AZB2C_Tenant_Id = '' #Replace with Azure B2C Tenant ID
$AZB2C_Tenant_Name = "" #Replace Domain Name
$B2C_Tenant_BE_App_Reg_Name  = '' #User Defined
$B2C_App_Reg_BE_SecretName = '' #User Defined

$B2C_Tenant_FE_App_Reg_Name  = '' #User Defined
$B2C_App_Reg_FE_SecretName = '' #User Defined

$AZ_Agent_Tenant_Secret_Prefix = "" #User Defined
$AZ_Agent_Tenant_DomainName = "" #Replace Domain Name
$AZ_Agent_Tenant_Id = ""    #Replace with AZ Tenant ID
$AZ_Agent_Tenant_App_Reg_Name  = '' #User Defined

$AZ_Backoffice_Tenant_Secret_Prefix = "" #User Defined
$AZ_Backoffice_Tenant_DomainName = "" #Replace Domain Name
$AZ_Backoffice_Tenant_Id = ""    #Replace with AZ Tenant ID
$AZ_Backoffice_Tenant_App_Reg_Name  = '' #User Defined

############################################################
#     Login to the AzureB2C Tenant
#############################################################

az login -t $AZB2C_Tenant_Name --allow-no-subscriptions
#Create FrontEnd App Reg
Add-AppB2CReg -Tenant_Secret_Name $B2C_App_Reg_FE_SecretName.ToString() -App_Reg_Name $B2C_Tenant_FE_App_Reg_Name.ToString()
Add-AppB2CReg -Tenant_Secret_Name $B2C_App_Reg_BE_SecretName.ToString() -App_Reg_Name $B2C_Tenant_BE_App_Reg_Name.ToString()
az logout

############################################################
#     Build Out Azure Agent Tenant with AD App Registration
#############################################################
# Login to the Azure Agent Tenant

az login -t $AZ_Agent_Tenant_DomainName 
Add-AppReg -Tenant_Secret_Name $AZ_Agent_Tenant_Secret_Prefix.ToString() -AZ_B2C_Domain $AZB2C_Tenant_Name.ToString() -App_Reg_Name $AZ_Agent_Tenant_App_Reg_Name.ToString()
az logout


#Create the Identity Provider in Azure AD.
Connect-MgGraph -TenantId $AZB2C_Tenant_Name -Scopes "IdentityProvider.ReadWrite.All"
Add-B2CIdentity -Domain $AZ_Agent_Tenant_DomainName -Group $AZ_Agent_Tenant_Secret_Prefix
Add-B2CIdentity -Domain $AZ_Backoffice_Tenant_DomainName -Group $AZ_Backoffice_Tenant_Secret_Prefix
Disconnect-MgGraph