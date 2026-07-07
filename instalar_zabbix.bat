@echo off
title Instalador Zabbix Agent - Enterprise
setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURACOES DO SERVIDOR (ALERE PARA AS SUB-REDES DA SUA EMPRESA)
REM ============================================================================
set "ZABBIX_SERVER=192.168.1.100"
set "ZABBIX_PORT=10051"
set "MSI=%~dp0zabbix_agent.msi"
set "LOG=%~dp0install_zabbix_log.txt"
set "SERVICE_NAME=Zabbix Agent"
set "MAX_WAIT=45"
set "MIN_DISK_MB=200"
set "MIN_PS_VERSION=3"
set "LOCK=%TEMP%\zabbix_install.lock"

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "INSTALL_DIR=C:\Program Files\Zabbix Agent"
) else if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
    set "INSTALL_DIR=C:\Program Files\Zabbix Agent"
) else (
    set "INSTALL_DIR=C:\Program Files (x86)\Zabbix Agent"
)

set "CONF=%INSTALL_DIR%\zabbix_agentd.conf"

call :LOG "========================================================"
call :LOG "INICIO INSTALACAO - ZABBIX AGENT AUTOMATION"
call :LOG "Computador : %COMPUTERNAME%"
call :LOG "Servidor   : %ZABBIX_SERVER%:%ZABBIX_PORT%"
call :LOG "InstallDir : %INSTALL_DIR%"
call :LOG "========================================================"

echo ==================================================
echo        INSTALADOR ZABBIX AGENT - ENTERPRISE
echo ==================================================
echo.
echo [INFO] Computador : %COMPUTERNAME%
echo [INFO] Servidor   : %ZABBIX_SERVER%:%ZABBIX_PORT%
echo [INFO] Log        : %LOG%
echo.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] Execute este arquivo como ADMINISTRADOR.
    call :LOG "[ERRO] Sem privilegios de administrador."
    pause
    exit /b 10
)

if exist "%LOCK%" (
    echo [AVISO] Lock antigo encontrado. Removendo...
    del "%LOCK%" >nul 2>&1
    call :LOG "[AVISO] Lock antigo removido automaticamente."
)

echo %COMPUTERNAME%_%TIME% > "%LOCK%"
call :LOG "[OK] Lock criado: %LOCK%"

echo [INFO] Verificando PowerShell...
set "PS_VER=0"
for /f "usebackq delims=" %%V in (
    `powershell -NoProfile -ExecutionPolicy Bypass -Command "$PSVersionTable.PSVersion.Major" 2^>nul`
) do set "PS_VER=%%V"

if %PS_VER% lss %MIN_PS_VERSION% (
    echo [ERRO] PowerShell %PS_VER% detectado. Minimo necessario: %MIN_PS_VERSION%.
    call :LOG "[ERRO] PowerShell insuficiente."
    call :CLEANUP
    pause
    exit /b 22
)

echo [OK] PowerShell %PS_VER% detectado.
call :LOG "[OK] PowerShell versao: %PS_VER%"

if not exist "%MSI%" (
    echo [ERRO] zabbix_agent.msi nao encontrado.
    echo Ele deve estar na mesma pasta deste .bat.
    call :LOG "[ERRO] MSI nao encontrado: %MSI%"
    call :CLEANUP
    pause
    exit /b 11
)

echo [OK] MSI encontrado.
call :LOG "[OK] MSI encontrado: %MSI%"

echo [INFO] Verificando espaco em disco...
set "FREE_MB="
for /f "usebackq delims=" %%S in (
    `powershell -NoProfile -ExecutionPolicy Bypass -Command "[math]::Round((Get-PSDrive C).Free / 1MB)" 2^>nul`
) do set "FREE_MB=%%S"

if defined FREE_MB (
    if !FREE_MB! lss %MIN_DISK_MB% (
        echo [ERRO] Espaco insuficiente: !FREE_MB! MB livres.
        call :LOG "[ERRO] Disco insuficiente: !FREE_MB! MB."
        call :CLEANUP
        pause
        exit /b 21
    )
    echo [OK] Espaco em disco: !FREE_MB! MB livres.
    call :LOG "[OK] Disco: !FREE_MB! MB livres."
)

echo [INFO] Detectando IP local...
set "LOCAL_IP=desconhecido"
for /f "usebackq delims=" %%A in (
    `powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.*' -and $_.IPAddress -notlike '127.*' -and $_.InterfaceAlias -notlike '*VMware*' -and $_.InterfaceAlias -notlike '*VirtualBox*' -and $_.InterfaceAlias -notlike '*Hyper-V*' -and $_.InterfaceAlias -notlike '*WSL*' -and $_.InterfaceAlias -notlike '*Docker*' -and $_.InterfaceAlias -notlike '*Loopback*' } | Sort-Object InterfaceMetric | Select-Object -First 1 -ExpandProperty IPAddress" 2^>nul`
) do set "LOCAL_IP=%%A"

echo [INFO] IP local detectado: %LOCAL_IP%
call :LOG "[INFO] IP local: %LOCAL_IP%"

echo [INFO] Verificando instalacao antiga do Zabbix Agent...
set "INSTALLED="
set "OLD_GUID="

sc query "%SERVICE_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    set "INSTALLED=1"
    echo [AVISO] Zabbix Agent antigo encontrado.
    call :LOG "[AVISO] Zabbix Agent antigo encontrado."

    if exist "%CONF%" (
        copy "%CONF%" "%CONF%.backup" >nul 2>&1
        call :LOG "[INFO] Backup do .conf criado."
    )

    echo [INFO] Parando servico antigo...
    sc stop "%SERVICE_NAME%" >nul 2>&1
    timeout /t 5 /nobreak >nul

    echo [INFO] Procurando GUID da instalacao antiga...
    for /f "usebackq delims=" %%G in (
        `powershell -NoProfile -ExecutionPolicy Bypass -Command "$paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'); $app=$paths | ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue } | Where-Object { $_.DisplayName -like '*Zabbix Agent*' } | Select-Object -First 1; if ($app) { $app.PSChildName }" 2^>nul`
    ) do set "OLD_GUID=%%G"

    if defined OLD_GUID (
        echo [INFO] Removendo Zabbix Agent antigo: !OLD_GUID!
        call :LOG "[INFO] Removendo Zabbix Agent antigo: !OLD_GUID!"

        msiexec /x "!OLD_GUID!" /qn /norestart
        set "UNINSTALL_EXIT=!errorlevel!"

        if !UNINSTALL_EXIT! neq 0 (
            echo [ERRO] Falha ao remover Zabbix Agent antigo. Codigo: !UNINSTALL_EXIT!
            call :LOG "[ERRO] Falha ao remover agente antigo. Codigo: !UNINSTALL_EXIT!"
            call :CLEANUP
            pause
            exit /b 16
        )

        timeout /t 5 /nobreak >nul
        echo [OK] Zabbix Agent antigo removido.
        call :LOG "[OK] Zabbix Agent antigo removido."
    ) else (
        echo [AVISO] GUID nao encontrado. Removendo servico manualmente...
        call :LOG "[AVISO] GUID nao encontrado. Removendo servico manualmente."
        sc delete "%SERVICE_NAME%" >nul 2>&1
        timeout /t 5 /nobreak >nul
    )
) else (
    echo [INFO] Nenhum Zabbix Agent antigo encontrado.
    call :LOG "[INFO] Instalacao limpa."
)

echo [INFO] Testando conexao com %ZABBIX_SERVER%:%ZABBIX_PORT%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "if ((Test-NetConnection '%ZABBIX_SERVER%' -Port %ZABBIX_PORT% -WarningAction SilentlyContinue).TcpTestSucceeded) { exit 0 } else { exit 1 }"

if %errorlevel% neq 0 (
    echo [AVISO] Porta %ZABBIX_PORT% inacessivel. Instalacao continuara.
    call :LOG "[AVISO] Porta %ZABBIX_PORT% inacessivel."
) else (
    echo [OK] Conexao com servidor OK.
    call :LOG "[OK] Conectividade OK."
)

echo [INFO] Instalando novo Zabbix Agent...
call :LOG "[INFO] Iniciando msiexec."

msiexec /i "%MSI%" /qn /norestart ^
    SERVER="%ZABBIX_SERVER%" ^
    SERVERACTIVE="%ZABBIX_SERVER%" ^
    HOSTNAME="%COMPUTERNAME%" ^
    INSTALLDIR="%INSTALL_DIR%" ^
    /L*v "%LOG%.msi.txt"

set "MSI_EXIT=%errorlevel%"

if %MSI_EXIT% neq 0 if %MSI_EXIT% neq 1641 if %MSI_EXIT% neq 3010 (
    echo [ERRO] msiexec falhou: %MSI_EXIT%
    call :LOG "[ERRO] msiexec falhou: %MSI_EXIT%"
    call :CLEANUP
    pause
    exit /b 12
)

echo [OK] MSI instalado.
call :LOG "[OK] MSI instalado."

echo [INFO] Aguardando criacao do arquivo .conf...
set /a "waited=0"

:WAIT_CONF
if exist "%CONF%" goto CONF_FOUND
set /a "waited+=2"
timeout /t 2 /nobreak >nul
if %waited% lss %MAX_WAIT% goto WAIT_CONF

echo [ERRO] Timeout: .conf nao encontrado.
call :LOG "[ERRO] Timeout aguardando .conf."
call :CLEANUP
pause
exit /b 13

:CONF_FOUND
echo [OK] .conf encontrado.
call :LOG "[OK] .conf encontrado."

echo [INFO] Aplicando configuracoes no zabbix_agentd.conf...

powershell -NoProfile -ExecutionPolicy Bypass -Command " ^
    $conf = '%CONF%'; ^
    $lines = Get-Content $conf -Encoding ASCII; ^
    $filtered = $lines | Where-Object { $_ -notmatch '^(Server=|ServerActive=|Hostname=|HostnameItem=|HostMetadata=|HostInterface=|HostInterfaceItem=)' }; ^
    $newLines = @( ^
        'Server=%ZABBIX_SERVER%', ^
        'ServerActive=%ZABBIX_SERVER%', ^
        'HostnameItem=system.hostname', ^
        'HostMetadata=Windows', ^
        'HostInterface=%LOCAL_IP%' ^
    ); ^
    Set-Content -Path $conf -Value ($filtered + $newLines) -Encoding ASCII"

if %errorlevel% neq 0 (
    echo [ERRO] Falha ao editar o .conf.
    call :LOG "[ERRO] Falha ao editar .conf."
    call :CLEANUP
    pause
    exit /b 14
)

echo [OK] Configuracao aplicada.
call :LOG "[OK] .conf editado com HostInterface=%LOCAL_IP%."

echo [INFO] Iniciando servico Zabbix Agent...
sc start "%SERVICE_NAME%" >nul 2>&1
sc failure "%SERVICE_NAME%" reset= 0 actions= restart/5000 >nul 2>&1

set /a "waited=0"

:WAIT_SERVICE
timeout /t 2 /nobreak >nul
sc query "%SERVICE_NAME%" | find "RUNNING" >nul
if %errorlevel% equ 0 goto SERVICE_UP
set /a "waited+=2"
if %waited% lss %MAX_WAIT% goto WAIT_SERVICE

echo [ERRO] Servico nao iniciou.
call :LOG "[ERRO] Servico nao iniciou."
call :CLEANUP
pause
exit /b 15

:SERVICE_UP
echo [OK] Servico RUNNING.
call :LOG "[OK] Servico RUNNING."

echo [INFO] Testando resposta do Agent...
set "AGENT_HOSTNAME="

for /f "usebackq delims=" %%R in (
    `"%INSTALL_DIR%\zabbix_agentd.exe" -t agent.hostname 2^>nul`
) do set "AGENT_HOSTNAME=%%R"

echo %AGENT_HOSTNAME% | findstr /i "%COMPUTERNAME%" >nul
if %errorlevel% equ 0 (
    echo [OK] Agent respondeu: %AGENT_HOSTNAME%
    call :LOG "[OK] Agent funcional: %AGENT_HOSTNAME%"
) else (
    echo [AVISO] Agent nao respondeu como esperado: %AGENT_HOSTNAME%
    call :LOG "[AVISO] Resposta inesperada: %AGENT_HOSTNAME%"
)

echo.
echo ==================================================
if defined INSTALLED (
    echo      ZABBIX AGENT ANTIGO REMOVIDO E NOVO INSTALADO
) else (
    echo      ZABBIX AGENT INSTALADO COM SUCESSO
)
echo ==================================================
echo Hostname      : %COMPUTERNAME%
echo IP local      : %LOCAL_IP%
echo HostInterface : %LOCAL_IP%
echo Metadata      : Windows
echo Servidor      : %ZABBIX_SERVER%
echo PowerShell    : %PS_VER%
echo.
echo Aguarde 1 a 3 minutos para o host aparecer no Zabbix.
echo.

call :LOG "[OK] ==== INSTALACAO CONCLUIDA ===="
call :LOG "[OK] Hostname: %COMPUTERNAME% | IP: %LOCAL_IP% | PS: %PS_VER%"

call :CLEANUP
pause
exit /b 0

:CLEANUP
if exist "%LOCK%" (
    del "%LOCK%" >nul 2>&1
    call :LOG "[OK] Lock removido."
)
goto :EOF

:LOG
for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set "_d=%%c/%%b/%%a"
for /f "tokens=1-3 delims=:., " %%a in ("%time: =0%") do set "_t=%%a:%%b:%%c"
echo [%_d% %_t%] %~1 >> "%LOG%"
goto :EOF