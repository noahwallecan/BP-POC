#################### ActiveXperts ####################

#IntNet instellen met statisch ip-adres
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.0.4 -PrefixLength 24 -DefaultGateway 192.168.0.5
Set-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.0.4 -PrefixLength 24

#Ethernet adapters renamen
Rename-NetAdapter "Ethernet" -NewName "LAN"

#DNS instellen
Set-DnsClientServerAddress -InterfaceAlias "LAN" -ServerAddresses ("192.168.0.1")

#Auto login as Domain Admin (https://sid-500.com/2020/12/28/windows-10-configure-auto-logon-with-powershell-automation/)
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$DomainUsername = "bap.local\Administrator"
$DomainPassword = "Temporarypass123!"
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String 
Set-ItemProperty $RegPath "DefaultUsername" -Value "$DomainUsername" -type String 
Set-ItemProperty $RegPath "DefaultPassword" -Value "$DomainPassword" -type String

#SQL aan domein toevoegen (https://www.hexnode.com/mobile-device-management/help/script-to-add-windows-devices-to-active-directory-domain/)
$pw = "Temporarypass123!" | ConvertTo-SecureString -asPlainText –Force # Specify the password for the domain admin.
$usr = "bap.local\Administrator" # Specify the domain admin account.
$creds = New-Object System.Management.Automation.PSCredential($usr,$pw)
Add-Computer -DomainName "bap.local" -ComputerName "ActiveXperts" -Credential $creds -force -verbose -restart


#rebooten om installaties te voltooien
shutdown /r -t 0
