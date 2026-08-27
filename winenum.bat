@ECHO OFF
ECHO ----------------------------------------
ECHO *** Quick Windows enumeration script ***
ECHO ----------------------------------------
PAUSE

:: Base variables
SET tempbatchfilepath=%~dp0
SET batchfilepath=%tempbatchfilepath:~0,-1%
ECHO Set working directory to %batchfilepath%

SET name=%COMPUTERNAME%
IF exist %batchfilepath%\%name%\ ( echo Folder %name% already exists ) ELSE ( mkdir %batchfilepath%\%name% && echo Folder %name% created! )

:: Gather system information and sent them into files
ECHO   0%% [     ]

:: System info & patching
systeminfo > %batchfilepath%\%name%\systeminfo-%name%.txt
wmic qfe list > %batchfilepath%\%name%\win-patches-%name%.txt
wmic /output:"%batchfilepath%\%name%\software-%name%.txt" product get Name, Version, Vendor
wmic process list > %batchfilepath%\%name%\processes-%name%.txt
net share > %batchfilepath%\%name%\shares-%name%.txt

ECHO  20%% [=    ]

:: Network info
ipconfig /all > %batchfilepath%\%name%\ipconfig-%name%.txt
arp -A > %batchfilepath%\%name%\arp-known-hosts-%name%.txt
netstat -ano > %batchfilepath%\%name%\listening-ports-%name%.txt
ping www.google.com > %batchfilepath%\%name%\internet-access-%name%.txt
route print > %batchfilepath%\%name%\route-%name%.txt
tracert google.com > %batchfilepath%\%name%\traceroute-%name%.txt
type C:\WINDOWS\System32\drivers\etc\hosts > %batchfilepath%\%name%\host-file-content-%name%.txt
ipconfig /displaydns | findstr "Record" | findstr "Name Host" > %batchfilepath%\%name%\dns-records-%name%.txt

ECHO  40%% [==   ]

:: User & accounts info
net localgroup > %batchfilepath%\%name%\localgroups-%name%.txt
net users > %batchfilepath%\%name%\localusers-%name%.txt
net accounts > %batchfilepath%\%name%\local-password-policies-%name%.txt
query user > %batchfilepath%\%name%\logged-in-users-%name%.txt
klist sessions > %batchfilepath%\%name%\list-sessions-%name%.txt

ECHO  60%% [===  ]

:: Domain info
gpresult /R > %batchfilepath%\%name%\gp-result-%name%.txt
net accounts /domain > %batchfilepath%\%name%\domain-password-policy-%name%.txt
net users /domain > %batchfilepath%\%name%\domain-users-%name%.txt
net groups /domain > %batchfilepath%\%name%\domain-groups-%name%.txt
:: Credentials
cmdkey /list > %batchfilepath%\%name%\stored-credentials-%name%.txt

ECHO  80%% [==== ]

:: Processes, services, tasks, startup
tasklist /v > %batchfilepath%\%name%\proc-tasklist-%name%.txt
wmic process get CSName,Description,ExecutablePath,ProcessId > %batchfilepath%\%name%\proc-processes-%name%.txt
schtasks /query /fo LIST /v > %batchfilepath%\%name%\proc-scheduledtasks-%name%.txt
sc query > %batchfilepath%\%name%\proc-sc-%name%.txt
tasklist /SVC  > %batchfilepath%\%name%\proc-tasklistsvc-%name%.txt
wmic service get Caption,Name,PathName,ServiceType,Started,StartMode,StartName > %batchfilepath%\%name%\proc-wmicservices-%name%.txt
wmic startup get Caption,Command,Location,User > %batchfilepath%\%name%\proc-wmicstartup-%name%.txt

ECHO 100%% [=====]

ECHO Commands completed successfully!
PAUSE
