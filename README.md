# 🛡️ Zabbix Agent - Instalador Automatizado & Resiliente (Windows)

[![Windows](https://img.shields.io/badge/OS-Windows%2010%20%7C%2011%20%7C%20Server-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-3.0%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Zabbix](https://img.shields.io/badge/Zabbix%20Agent-Automation-D40000?style=for-the-badge&logo=zabbix&logoColor=white)](https://www.zabbix.com/)

Um instalador **zero-touch, auto-curável (self-healing) e defensivo** para o Zabbix Agent em ambientes Windows corporativos. 

Desenvolvido em uma abordagem híbrida de **Batch Script e PowerShell**, este projeto foi criado para eliminar falhas manuais de implantação, remover instalações legadas sem deixar rastro no Registro do Windows e resolver dinamicamente o endereço IP da interface física de rede.

---

## ✨ Principais Funcionalidades

| Funcionalidade | Descrição Técnica |
| :--- | :--- |
| **🧹 Purga de Legados** | Varre automaticamente o Registro do Windows (`HKLM`) em busca de GUIDs de instalações antigas ou travadas do Zabbix Agent e executa uma desinstalação limpa via `msiexec /x` antes do novo deploy. |
| **🌐 Detecção Inteligente de IP** | Utiliza PowerShell para filtrar e ignorar interfaces virtuais (Docker, VMware, VirtualBox, Hyper-V, WSL, Loopback), vinculando o parâmetro `HostInterface` estritamente ao endereço IPv4 físico principal da máquina. |
| **⚙️ Configuração Dinâmica** | Limpa parâmetros antigos e injeta dinamicamente em tempo de execução no `zabbix_agentd.conf`: `Server`, `ServerActive`, `HostnameItem`, `HostMetadata` e `HostInterface`. |
| **🔄 Resiliência de Serviço** | Configura o serviço no Windows para reiniciar automaticamente em caso de falhas inesperadas (recovery actions/5000ms). |
| **🔒 Mecanismo Anti-Concorrência** | Criação de arquivo lock (`.lock`) em `%TEMP%` e validações prévias de privilégio de Administrador, versão do PowerShell e espaço livre em disco. |
| **📝 Auditoria e Logs** | Todos os passos da instalação, diagnósticos e falhas são gravados com timestamp em um arquivo de log local (`install_zabbix_log.txt`). |

---

## 📁 Estrutura do Repositório

```text
📦 zabbix_agent
 ┣ 📜 instalar_zabbix.bat   # Script principal de automação, validação e deploy
 ┣ 📦 zabbix_agent.msi      # Pacote oficial de instalação do Zabbix Agent
 ┣ 📄 como_instalar.txt     # Guia rápido em texto plano para técnicos de suporte
 ┗ 📖 README.md             # Documentação técnica do projeto
📋 Pré-requisitos
Sistema Operacional: Windows 10, Windows 11 ou Windows Server (2016, 2019, 2022) - arquiteturas x86 ou x64.

PowerShell: Versão 3.0 ou superior nativa no sistema.

Privilégios: A execução DEVE ser realizada por um usuário com permissões de Administrador.

🚀 Como Configurar e Utilizar
1. Configuração Inicial do Servidor
Antes de executar, abra o arquivo instalar_zabbix.bat em qualquer editor de texto e altere as linhas 6 e 7 para apontar para o IP ou Hostname do seu servidor Zabbix corporativo:

DOS
set "ZABBIX_SERVER=192.168.1.100"   <-- Altere para o IP do seu Servidor/Proxy Zabbix
set "ZABBIX_PORT=10051"             <-- Altere a porta caso não utilize o padrão
2. Execução da Instalação
Certifique-se de que os arquivos instalar_zabbix.bat e zabbix_agent.msi estão na mesma pasta.

Clique com o botão direito em instalar_zabbix.bat e selecione "Executar como administrador".

Acompanhe a saída no terminal. O processo leva em média de 15 a 30 segundos.

🔍 Diagnóstico e Troubleshooting
Caso a instalação apresente alguma anormalidade no terminal, verifique os relatórios gerados automaticamente no mesmo diretório do script:

install_zabbix_log.txt: Histórico detalhado com carimbo de tempo (tentativas de remoção, IP detectado, versão do PowerShell e status final).

install_zabbix_log.txt.msi.txt: Log verboso oficial do próprio instalador do Windows (msiexec), gerado caso ocorram erros de nível de sistema operacional (códigos MSI).

👨‍💻 Autor
Matheus Felipe Fullstack Software Developer & Systems Architect LinkedIn • GitHub
