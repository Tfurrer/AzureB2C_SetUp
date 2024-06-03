
Register-SecretVault -Name SecretStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault 
Set-SecretStoreConfiguration -Authentication None -Interaction None
Set-Secret -name "Az_Validation" -secret "Test"
Get-Secret -name "Az_Az_Validation" -AsPlainText #Check that it exists
