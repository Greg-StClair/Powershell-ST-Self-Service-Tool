if(Get-Module -ListAvailable -Name Pscx){
    
    write-output("Installer found pscx, choosing not to install.")

}
else{

    Install-Module -Name Pscx -RequiredVersion 3.3.2 -Force -AllowClobber

}

if(Get-Module -ListAvailable -Name CredentialManager){

    write-output("Installer found Cred Manager, choosing not to install.")

}
else{

    Install-Module -Name CredentialManager -Force -AllowClobber

}



##Delete the first run text file so that we know the user-specific first time run actions will happen, necessary to ensure future changes run as expected, without being nested in the admin first run script (this one)
##First run of the script creates shortcuts for users, as well as 
if(Test-Path 'C:\Program Files\SoundTransit IT Tools\SelfServiceComplete.txt'){

    Remove-Item -Path 'C:\Program Files\SoundTransit IT Tools\SelfServiceComplete.txt'

}

Start-Process -FilePath "C:\Program Files\SoundTransit IT Tools\IT Self Service.exe" | Out-Null # Out-Null allows execution of item and continuation of script; 
