#################### DC 1 ####################

#IntNet instellen met statisch ip-adres
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.0.1 -PrefixLength 24 -DefaultGateway 192.168.0.5
Set-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.0.1 -PrefixLength 24

#Ethernet adapters renamen
Rename-NetAdapter "Ethernet" -NewName "LAN"

#DNS instellen
Set-DnsClientServerAddress -InterfaceAlias "LAN" -ServerAddresses ("192.168.0.1")

#AD DS rol installeren en opzetten
Install-WindowsFeature -ConfigurationFilePath 'Z:\DC\ADDS.xml'
$SafeModeAdministratorPassword = ConvertTo-SecureString "Temporarypass123!" -AsPlainText -Force

Import-Module ADDSDeployment
Install-ADDSForest `
-SafeModeAdministratorPassword:$SafeModeAdministratorPassword `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "bap.local" `
-DomainNetbiosName "BAP" `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true

# DNS rol installeren 
Install-WindowsFeature DNS -Confirm

#rebooten om installaties te voltooien
shutdown /r -t 0
