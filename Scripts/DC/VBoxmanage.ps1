$User = $env:UserName

#Pad instellen waar je de VM's wilt opslaan
$MapNaam = "src"
$InstallatiePad = "D:\VirtualBox VMs\$MapNaam"

#Pad instellen naar waar je Windows Server ISO staat
$isoPadServer = "C:\Users\noaht\Downloads\en_windows_server_2019_x64_dvd_4cb967d8.iso"

#Pad instellen naar de map waarin de scripts staan
$gedeeldeMapDC = "C:\Users\noaht\Documents\BP-POC\Scripts\DC\Scripts"
$gedeeldeMap = "C:\Users\noaht\Documents\BP-POC\Scripts\ActiveXperts"
$env:PATH = $env:PATH + ";C:\Program Files\Oracle\VirtualBox"

# maken van intnet
VBoxManage natnetwork add --netname BP-internal --network "192.168.0.0/24" --enable --dhcp off


function Alle_VMs_Aanmaken{
    
    VM_Aanmaken -naam 'dc' -ostype Windows2019_64 -cores 1 -vram 64 -ram 6144 -geheugen 40960 -groep $MapNaam
    VM_Aanmaken -naam 'activexperts' -ostype Windows2019_64 -cores 1 -vram 64 -ram 6144 -geheugen 40960 -groep $MapNaam
}

function VM_Aanmaken{
    param(
    [string] $naam = '',
    [string] $ostype = '',
    [int] $ram = '',
    [int] $vram = '64',
    [int] $cores = '',
    [string] $gc = 'VBoxSVGA',
    [int] $geheugen = '',
    [string] $groep = '')

    try{
        Write-Host "########## $naam WORDT GECREËERD... ##########" -ForegroundColor Yellow
        #vm's aanmaken
        VBoxManage createvm --name $naam --register --groups "/$MapNaam" --ostype $ostype 
        VBoxManage modifyvm $naam --memory $ram --vram $vram --cpus $cores --graphicscontroller $gc
            
        #netwerkadapters instellen
        VBoxManage modifyvm $naam --nic1 intnet --nictype1 82540EM
        VBoxManage modifyvm $naam --intnet1 "BP-internal"
            
        #Nieuwe harde schijf maken en importeren in de virtuele machine
        VBoxManage createhd --filename "$InstallatiePad\$naam\$naam.vdi" --size $geheugen --variant Standard
        VBoxManage storagectl $naam --name "SATA Controller" --add sata --controller IntelAHCI
        
        VBoxManage storageattach $naam --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$InstallatiePad\$naam\$naam.vdi"

        #gedeelde map linken
        if ($naam -eq "dc"){
	        VBoxManage sharedfolder add $naam --name gedeeld --hostpath $gedeeldeMapDC --automount
        }else{
            VBoxManage sharedfolder add $naam --name gedeeld --hostpath $gedeeldeMap --automount
        }
        #Unattended installs van de VM's
        
        VboxManage unattended install $naam --iso=$isoPadServer --user=Administrator --password=Temporarypass123! --install-additions --locale="nl_BE" --full-user-name="Administrator" --country="BE" --start-vm=gui --image-index=2 --post-install-command="shutdown /r -t 0"
        
        
        Write-Host "########## $naam SUCCESVOL GECREËERD ##########" -ForegroundColor Green
        
        
    }catch {
       Write-Host "Er is een fout opgetreden bij het aanmaken van de volgende VM: $naam"
       Write-Host $_
    }
}


Alle_VMs_Aanmaken