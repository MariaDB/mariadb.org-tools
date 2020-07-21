#escape=`

# Use the latest Windows Server Core image with .NET Framework 3.5
FROM mcr.microsoft.com/dotnet/framework/sdk:3.5-windowsservercore-ltsc2019

# Restore the default Windows shell for correct batch processing.
SHELL ["cmd", "/S", "/C"]

# Download the Build Tools bootstrapper.
ADD https://aka.ms/vs/16/release/vs_buildtools.exe C:\TEMP\vs_buildtools.exe

# Install Build Tools with the Microsoft.VisualStudio.Workload.VCTools workload etc.
RUN C:\TEMP\vs_buildtools.exe --quiet --wait `
 --norestart --nocache --installPath C:\VCTools `
 --add Microsoft.VisualStudio.Workload.VCTools `
 --includeRecommended  --add Microsoft.VisualStudio.Component.VC.ATLMFC --add Microsoft.VisualStudio.Component.VC.Redist.MSM `
 || IF "%ERRORLEVEL%"=="3010" EXIT 0

RUN powershell -Command `
    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')); `
    choco feature disable --name showDownloadProgress

RUN choco install -y git.install  --params /NoAutoCrlf
RUN choco install -y strawberryperl winflexbison windbg
RUN setx PATH "%PATH%;C:\Strawberry\perl\bin;C:\ProgramData\chocolatey\lib\winflexbison\tools;C:\Program Files\Git\cmd;C:\Program Files (x86)\Windows Kits\10\Debuggers\x64"
RUN git.exe config --global core.autocrlf input
RUN choco install -y wixtoolset

RUN choco install -y diffutils
RUN choco install -y python

RUN net user Buildbot /add
SHELL ["cmd.exe", "/s", "/c"]
RUN C:\VCTools\Common7\Tools\VsDevCmd.bat -arch=x64 && `
    python -m pip install --upgrade incremental
RUN python -m pip install twisted
RUN python -m pip install buildbot-worker
RUN python -m pip install pypiwin32

RUN mkdir C:\Buildbot
WORKDIR C:\\Buildbot
SHELL ["powershell", "-command"]
RUN Start-BitsTransfer -Source 'https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac' -Destination buildbot.tac

SHELL ["cmd.exe", "/s", "/c"]
CMD C:\\Python38\\Scripts\\twistd.exe -noy C:\\Buildbot\\buildbot.tac
