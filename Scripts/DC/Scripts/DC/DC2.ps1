#################### DC 2 ####################

#Configureren DNS
Add-DnsServerPrimaryZone -DynamicUpdate Secure -NetworkId ‘192.168.0.0/24’ -ReplicationScope Domain
Add-DnsServerResourceRecordPtr -Name "1" -ZoneName "0.168.192.in-addr.arpa" -AgeRecord -PtrDomainName "dc.bap.local"

#forwarders en Listen interface aanpassen
Set-DnsServerForwarder -IPAddress "1.1.1.1"
dnscmd 192.168.0.1 /ResetListenAddresses 192.168.0.1

#DNS records voor andere niet-Windows servers
Add-DnsServerResourceRecordA -Name "www.rallly" -ZoneName "bap.local" -AllowUpdateAny -IPv4Address "192.168.0.2" -CreatePtr
Add-DnsServerResourceRecordA -Name "rallly" -ZoneName "bap.local" -AllowUpdateAny -IPv4Address "192.168.0.2" -CreatePtr
Add-DnsServerResourceRecordA -Name "." -ZoneName "bap.local" -AllowUpdateAny -IPv4Address "192.168.0.2" -CreatePtr
Add-DnsServerResourceRecordA -Name "www" -ZoneName "bap.local" -AllowUpdateAny -IPv4Address "192.168.0.2" -CreatePtr

#PTR voor elke server
Add-DnsServerResourceRecordPtr -Name "webserver" -ZoneName "0.168.192.in-addr.arpa" -AllowUpdateAny -PtrDomainName "webserver.bap.local"


New-ADOrganizationalUnit -Name "MyUsers" -Path "DC=bap,DC=local" -ProtectedFromAccidentalDeletion $False
New-ADUser -Name "Noah Wallecan" -Path "OU=MyUsers,DC=bap,DC=local" -ChangePasswordAtLogon $False -AccountPassword $(ConvertTo-SecureString "Temporarypass123!" -AsPlainText -Force) -Enabled $True