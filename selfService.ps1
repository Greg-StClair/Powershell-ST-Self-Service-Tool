##POSH 5.1, Greg St. Clair, Copyright Sound Transit
##For v.1, script contains all button functions
##This entire program is designed to run without admin rights, with a standard user's credentials

### First, load required dependencies: 

Add-Type -AssemblyName PresentationFramework, System.Drawing, System.Windows.Forms, WindowsFormsIntegration, PresentationCore


function FirstRun(){
    $userlist = Get-ChildItem C:\Users

    $firstrun = Test-Path 'C:\Program Files\SoundTransit IT Tools\SelfServiceComplete.txt' 
    #Whenever a new update is pushed, the firstrun file is deleted so that this firstrun happens again. 
    # we check to see if shortcuts are already in place, if they are, we do nothing

    if($firstrun -eq $false){ 

          
        $userlist = Get-ChildItem C:\Users
        $WshShell = New-Object -comObject WScript.Shell 

        ## Add shortcut to all start menus, searchable, so that even new users can see the app, just not on their desktop
        $programExecutableExists = Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\IT Self Service.lnk"

        if($programExecutableExists -eq $false){ #on first run, or if it got deleted somehow, add the start menu shortcut
            
            $Shortcut =  $WshShell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\IT Self Service.lnk")
            $Shortcut.TargetPath = "C:\Program Files\SoundTransit IT Tools\IT Self Service.exe"
        
        }    

        #Create Log file to verify task completion
        New-Item 'C:\Program Files\SoundTransit IT Tools\SelfServiceComplete.txt'

        $date = Get-Date

        $completionlog = 'C:\Program Files\SoundTransit IT Tools\SelfServiceComplete.txt'

        foreach($user in $userlist){
            
            #Test if shortcuts exist. If any do, kill them with fire so we prevent duplicate icons. 


            $desktopLnkExists = Test-Path "C:\Users\$user\Desktop\IT Self Service.lnk"
            $startLnkExists = Test-Path "C:\Users\$user\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\IT Self Service.lnk"

            ##Drop Shortcut on desktop, then drop it in each user's start menu just to be sure

            if($desktopLnkExists -eq $false){
                
                $Shortcut = $WshShell.CreateShortcut("C:\Users\$user\Desktop\IT Self Service.lnk")
                $Shortcut.TargetPath = "C:\Program Files\SoundTransit IT Tools\IT Self Service.exe"
                $Shortcut.Save()
            
            }

            if($startLnkExists -eq $false){
            
                $Shortcut = $WshShell.CreateShortcut("C:\Users\$user\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\IT Self Service.lnk")
                $Shortcut.TargetPath = "C:\Program Files\SoundTransit IT Tools\IT Self Service.exe"
                $Shortcut.Save()
            
            } 

            
            #remove the public desktop icon after we added it. Why? Well it avoids duplication and is easier than remaking the user array. Fix later.

            Remove-Item -Path 'C:\Users\Public\Desktop\IT Self Service2.lnk'
            Remove-Item -Path 'C:\Users\Public\Desktop\IT Self Service.lnk'
           
            Add-Content -Path 'C:\Program Files\SoundTransit IT Tools\SelfServiceComplete.txt' -Value "Created Shorcut in $user folder, on $date"
            

            }
        }
        else{

        Write-Host "This is not the first run, skipping task"

        }

        if($firstrun -eq $false){ ##sets it so that the first run also exits the script and doesn't load it when installed. Allows silent installation. 
            $exitcode = 0 
            exit $exitcode
        }
    }


#Check to see if we need to setup shortcuts to the tool; if the log is present then we have already installed the app. 
FirstRun

$xamlPathMain = "C:\Program Files\SoundTransit IT Tools\MainWindow.xaml"
$xamlPathITtools = "C:\Program Files\SoundTransit IT Tools\ITToolsPage.xaml"






#First we initialize our XAML reader 
function xamlLoader($pageUNCpath) #functions deloads previous xaml from memory. If this program grows, this may need to be re-written
{   
    Write-Progress -Activity 'Loading' -Status "Init XAML" -PercentComplete 10 -id 1
    $count = 0 ## old config
    $count += 1 ##Var created will always refer to the CURRENT OPEN WINDOW. 

    $xamlFile = $pageUNCpath
    #Create Window xml object for later translation
    $inputXML = Get-Content $xamlFile -Raw
    $inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
    [XML]$XAML = $inputXML

    
    ####ReadXAML and name the winow variable for later use####

    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    try {
        $window = [Windows.Markup.XamlReader]::Load($reader)
        
        Set-Variable -Name "var_$($count)" -Value $window #names the window variable; count is reset inside the function so the variable name is constant and refers to the currently spawned window. 
        }
        catch{
        Write-Warning $_.Exception
        throw
        }
    

    # Create variables based on form control names.
    # Variable will be named as 'var_<control name>'

    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        #"trying item $($_.Name)" $($ format for magic variable names/appending varnames)
        try {
            Set-Variable -Name "var_$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop
        } catch {
            throw
        }
    }

   
   #Get-Variable var_* #-- Troubleshooting, if variables are missing. this cannot load subwindow variables to the console
        
        if($pageUNCpath -eq $xamlPathMain){
        
            Write-Host("Loading main page")
            pageFunctionsMain

        }

        elseif($pageUNCpath -eq $xamlPathITtools){

            Write-Host("Loading IT Tools page")
            pageFunctionsITtools

        }
        else{break}

      
   
   
    $window.ShowDialog() | Out-Null
    
}

####->Separated function from button scripts for readability<-####
#### Section contains all called functions ####

    
function vpnStatusCheck(){
    
    $connectStatus = rasdial | Select-String -Pattern "AOVPN01"
    if ($connectStatus | Select-String "AOVPN01"){$connectStatus = "Connected!"}
        else{$connectStatus = "Disconnected!"}
    return $connectStatus
}



function clearCacheAndCookies(){
    taskkill /f /im "chrome.exe"
    taskkill /f /im "iexplore.exe"
    Start-Sleep 2

    function getdllhostprocess(){
    $dllHostProcesses = Get-Process | Select-Object ProcessName, ID | Where-Object {$_.ProcessName -eq "dllhost"}
    }

    $chromeFolderstoDelete = @('Cache\*',
                               'Cookies',
                               'Login Data',
                               'Web Data')

    $folder = "$($env:LOCALAPPDATA)\Google\Chrome\User Data\Default"
    $chromeFolderstoDelete | ForEach-Object {if (Test-Path "$folder\$_") {Remove-Item "$folder\$_"}}

    ###Delete IE cache, values are for cookies, temp files, passwords, and tracking data

    #Check DLL host with different PID to see if the process finished
    
    $dllHostPids = getdllhostprocess | Select-Object ID

    $userprof = $env:userprofile

    $firefoxFoldersToDelete = "$env:userprofile\Appdata\roaming\Mozilla\Firefox\Profiles"


    $clearOptions = @(2,4,23,2048)
    foreach($x in $clearOptions){
    RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess $x | Out-Null

    $isRunDllrunning = getdllhostprocess | Select-Object ID

   

    }

    ##Add function to check folders? 
}

#Wrote function to avoid needing to write ipaddress variable on multiple lines; logic to select an address

function getInterfaceInfo($intNum, $type){

    $intNum = $intNum - 1 #-1 for 0 based array
    $Interfaces = Get-NetIPConfiguration | Select-Object -Property InterfaceAlias, IPv4Address
    
    $ip = $Interfaces[$intNum].Ipv4Address.IPAddress
    $intName = $Interfaces[$intNum].InterfaceAlias.Split(" ")
    $intName = $intName[0]
    $netInfo = @($intName, $ip)

    if($type -eq 1){return $netInfo[0]}
    if($type -eq 2){return $netInfo[1]}

}

function mainPageContent(){
    $defaultContent = " Welcome! Please select an option below.&#x0a; &#x0a; Click IT tools to see more options. The Clear cache &#x0a; and Cookies option can resolve many browser or &#x0a; website related issues."
    return $defaultContent
}



#page functions implement buttons/context features and previous functions
function pageFunctionsMain(){ #Future versions may iterate over xaml controls and add features that way, however that method is not very easy to read. All variables must be initially statically asigned with page functions. 
    Write-Progress -Activity 'Loading' -Status "Loading PC Info" -PercentComplete 20 -id 1
    
    $var_txt_outputBlock.Content = mainPageContent
          
    $var_txt_userName.Content = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName | Out-String
    $var_txt_userName.Add_Click({$var_txt_userName.Content | Set-Clipboard})


    $var_txt_compName.Content = hostname
    $var_txt_compName.Add_Click({$var_txt_compName.Content | Set-Clipboard})

    $var_txt_vpnStatus.Content = vpnStatusCheck
    $var_txt_vpnStatus.Add_Click({$var_txt_vpnStatus.Content | Set-Clipboard})

    Write-Progress -Activity 'Loading' -Status "Loading User Functions" -PercentComplete 30 -id 1
    $var_btn_RefreshInfo.Add_Click({

          Write-Host "Refreshing"

          $var_txt_loading.Text = "Loaded Info!"
          $var_txt_userName.Content = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName | Out-String  
          $var_txt_compName.Content = hostname
          $var_txt_vpnStatus.Content = vpnStatusCheck
    
    })

    $var_btn_mainITtools.Add_Click({

        $var_1.close()
        xamlLoader $xamlPathITtools

    })

    $var_label_Network1.Content = getInterfaceInfo 1 1
    $var_btn_Network1.Content   = getInterfaceInfo 1 2
    $var_btn_Network1.Add_Click({$var_btn_Network1.Content | Set-Clipboard})

    $var_label_Network2.Content = getInterfaceInfo 2 1
    $var_btn_Network2.Content   = getInterfaceInfo 2 2
    $var_btn_Network2.Add_Click({$var_btn_Network2.Content | Set-Clipboard})

    $var_label_Network3.Content = getInterfaceInfo 3 1
    $var_btn_Network3.Content   = getInterfaceInfo 3 2
    $var_btn_Network3.Add_Click({$var_btn_Network3.Content | Set-Clipboard})

    $var_label_Network4.Content = getInterfaceInfo 4 1
    $var_btn_Network4.Content   = getInterfaceInfo 4 2
    $var_btn_Network4.Add_Click({$var_btn_Network4.Content | Set-Clipboard})

    $var_label_Network5.Content = getInterfaceInfo 5 1
    $var_btn_Network5.Content   = getInterfaceInfo 5 2
    $var_btn_Network5.Add_Click({$var_btn_Network5.Content | Set-Clipboard})

    
    

    Write-Progress -Activity 'Loading' -Status "Loading IT Tool Main Page" -PercentComplete 50 -id 1
    Write-Progress -Activity 'Loading' -Status "Loading IT Tool Main Page" -PercentComplete 55 -id 1
    Write-Progress -Activity 'Loading' -Status "Loading IT Tool Main Page" -PercentComplete 60 -id 1
    Write-Progress -Activity 'Loading' -Status "Loading IT Tool Main Page" -PercentComplete 75 -id 1
    Write-Progress -Activity 'Loading' -Status "Loading IT Tool Main Page" -PercentComplete 100 -id 1 -Completed
    

}



function pageFunctionsITtools()
{ #Still probably a better way to do this...


    $var_btn_goBackToMain.Add_Click({

    $var_1.close()
    xamlLoader $xamlPathMain #re-open main screen so the app doesnt close
    })

    $var_btn_connectVPN.Add_Click({

    $textToDisplay = "Re-Establishing Always On Connection"
    $var_txt_StatusBox.Text = $textToDisplay
    $aovpnStatus = rasdial aovpn01
    $var_txt_StatusBox.Text = $aovpnStatus
    ##Hosts file fix cannot be done without admin...
    })

    $var_btn_dellWarrantySite.Add_Click({

    [system.Diagnostics.Process]::Start("chrome","https://www.dell.com/support/home/en-us?app=warranty")
    $var_txt_StatusBox.Text = " Opened Dell Warranty Site"
    Start-Sleep 1 #prevents double clicks from opening multiple windows
    })

    $var_btn_snowPortal.Add_Click({

    [system.Diagnostics.Process]::Start("chrome", "https://soundtransit.service-now.com/sp?id=index")
    $var_txt_StatusBox.Text = " Opened Ticket System"
    Start-Sleep 1 #prevents double clicks from opening multiple windows
    })

    $var_btn_resetPassword.Add_Click({

    [system.Diagnostics.Process]::Start("chrome", "https://sspr.soundtransit.org/showLogin.cc")
    $var_txt_StatusBox.Text = " Opened Sound Transit Self Service Site!"
    Start-Sleep 1 #prevents double clicks from opening multiple windows
    })


    $var_btn_hardwareInfo.Add_Click({

    #Possibly do this with systeminfo | select-object later
    msinfo32
    })

    $var_btn_clearCredentialVault.Add_Click({

        try{

            $credTargets = Get-StoredCredential -AsCredentialObject -ErrorAction Stop

            foreach($cred in $credTargets){

                $target = $cred.TargetName
                $type = $cred.Type
                Remove-StoredCredential -Type $type -Target $target

            }

    
            $var_txt_StatusBox.Text = "Command completed successfully, please log out and back in to test"
            
        }
        catch{

            $var_txt_StatusBox.Text = "No Credentials stored or cmdlet error. Check Credential Manager manually."

        }


    })

    $var_btn_clearCacheAndCookies.Add_Click({

    ## val 6 = yes, val 7 = no ##

    $wshell = New-Object -ComObject Wscript.Shell #Declare shell inside button, that way it is cleaned up when the prompt closes
    $answer = $wshell.Popup("Warning: This tool will close Chrome and Internet Explorer, and clear all cache and cookies. Do you want to continue?",0,"Alert",32+4)

    if($answer -eq 6){
               
        clearCacheAndCookies | out-null
        
        $var_txt_StatusBox.Text = " Successfully cleared cache and cookies!"
        
        
    }
        else{

            $var_txt_StatusBox.Text = " Cancelled Clear Cache and Cookies Action"

        }

    })
    Write-Progress -Activity 'Loading' -Status "Loading IT Tool Main Page" -PercentComplete 100 -id 1 -Completed
}

xamlLoader $xamlPathMain
#Set-ForegroundWindow (Get-Process -Name "IT Self Service").MainWindowHandle --last broken piece