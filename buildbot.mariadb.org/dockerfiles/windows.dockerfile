FROM mcr.microsoft.com/windows/servercore:1809

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Visual Studio Build Tools
RUN Install-WindowsFeature NET-Framework-45-Core
RUN Invoke-WebRequest "https://aka.ms/vs/16/release/vs_BuildTools.exe" -OutFile vs_BuildTools.exe -UseBasicParsing ; \
    Start-Process -FilePath 'vs_BuildTools.exe' -ArgumentList '--quiet', '--norestart', '--locale en-US', '--installPath C:\BuildTools',  '--add Microsoft.VisualStudio.Workload.VCTools', '--add Microsoft.VisualStudio.Component.VC.140', '--includeRecommended' -Wait ; \
    Remove-Item .\vs_BuildTools.exe; \
    Remove-Item -Force -Recurse 'C:\Program Files (x86)\Microsoft Visual Studio\Installer'
RUN $env:PATH = $env:PATH + ';C:\BuildTools\MSBuild\16.0\Bin'

RUN Invoke-WebRequest 'https://github.com/git-for-windows/git/releases/download/v2.12.2.windows.2/MinGit-2.12.2.2-64-bit.zip' -OutFile MinGit.zip

# Install Git
RUN Expand-Archive c:\MinGit.zip -DestinationPath c:\MinGit; \
$env:PATH = $env:PATH + ';C:\MinGit\cmd\;C:\MinGit\cmd'; \
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\' -Name Path -Value $env:PATH
# TODO remove Git
# Install Bison dependencies
RUN Start-BitsTransfer -Source 'http://downloads.sourceforge.net/gnuwin32/bison-2.4.1-dep.zip' -Destination bisonDep.zip
RUN Expand-Archive c:\bisonDep.zip -DestinationPath c:\bisonInstall
RUN Remove-Item C:\bisonDep.zip
# Install Bison
RUN Start-BitsTransfer -Source 'https://downloads.sourceforge.net/gnuwin32/bison-2.4.1-bin.zip' -Destination bisonInstall.zip
RUN Expand-Archive c:\bisonInstall.zip -DestinationPath c:\bisonInstall; \
$env:PATH = $env:PATH + ';C:\bisonInstall\bin\;C:\bisonInstall\bin'; \
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\' -Name Path -Value $env:PATH
RUN Remove-Item C:\bisonInstall.zip

# Install Perl
RUN Start-BitsTransfer -Source 'http://strawberryperl.com/download/5.30.0.1/strawberry-perl-5.30.0.1-64bit-portable.zip' -Destination perlInstall.zip
RUN Expand-Archive c:\perlInstall.zip -DestinationPath c:\perlInstall; \
$env:PATH = $env:PATH + ';C:\perlInstall\site\bin;C:\perlInstall\perl\bin;C:\perlInstall\c\bin'; \
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\' -Name Path -Value $env:PATH
RUN Remove-Item C:\perlInstall.zip
# Install Python
ENV PYTHON_VERSION 3.8.0
ENV PYTHON_RELEASE 3.8.0
RUN $url = ('https://www.python.org/ftp/python/{0}/python-{1}-amd64.exe' -f $env:PYTHON_RELEASE, $env:PYTHON_VERSION); \
    Write-Host ('Downloading {0} ...' -f $url); \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri $url -OutFile 'python.exe'; \
    \
    Write-Host 'Installing ...'; \
    # https://docs.python.org/3.5/using/windows.html#installing-without-ui
    Start-Process python.exe -Wait \
        -ArgumentList @( \
            '/quiet', \
            'InstallAllUsers=1', \
            'TargetDir=C:\Python', \
            'PrependPath=1', \
            'Shortcuts=0', \
            'Include_doc=0', \
            'Include_pip=0', \
            'Include_test=0' \
        ); \
    \
    # the installer updated PATH, so we should refresh our local value
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine); \
    \
    Write-Host 'Verifying install ...'; \
    Write-Host '  python --version'; python --version; \
    \
    Write-Host 'Removing ...'; \
    Remove-Item python.exe -Force; \
    \
    Write-Host 'Complete.'
# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 20.1.1
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/ffe826207a010164265d9cc807978e3604d18ca0/get-pip.py
ENV PYTHON_GET_PIP_SHA256 b86f36cc4345ae87bfd4f10ef6b2dbfa7a872fbff70608a1e43944d283fd0eee
RUN Write-Host ('Downloading get-pip.py ({0}) ...' -f $env:PYTHON_GET_PIP_URL); \
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri $env:PYTHON_GET_PIP_URL -OutFile 'get-pip.py'; \
    Write-Host ('Verifying sha256 ({0}) ...' -f $env:PYTHON_GET_PIP_SHA256); \
    if ((Get-FileHash 'get-pip.py' -Algorithm sha256).Hash -ne $env:PYTHON_GET_PIP_SHA256) { \
        Write-Host 'FAILED!'; \
        exit 1; \
    }; \
    \
    Write-Host ('Installing pip=={0} ...' -f $env:PYTHON_PIP_VERSION); \
    python get-pip.py \
        --disable-pip-version-check \
        --no-cache-dir \
        ('pip=={0}' -f $env:PYTHON_PIP_VERSION) \
    ; \
    Remove-Item get-pip.py -Force; \
    \
    Write-Host 'Verifying pip install ...'; \
    pip --version; \
    \
    Write-Host 'Complete.'
RUN net user Buildbot /add
SHELL ["cmd.exe", "/s", "/c"]
RUN C:\BuildTools\Common7\Tools\VsDevCmd.bat -arch=x64 && \
    python -m pip install Twisted[windows_platform]
RUN python -m pip install buildbot-worker
RUN mkdir C:\Buildbot
WORKDIR C:\\Buildbot
SHELL ["powershell", "-command"]
RUN Start-BitsTransfer -Source 'https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac' -Destination buildbot.tac
CMD C:\\Python\\Scripts\\twistd.exe -noy C:\\Buildbot\\buildbot.tac

