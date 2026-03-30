# NuoPanel

Sistema de gerenciamento de hospedagem web baseado em OpenLiteSpeed, Django e MariaDB.

## Requisitos

- Ubuntu 22.04 LTS ou 24.04 LTS
- Servidor limpo (fresh install)
- Acesso root

## Instalacao Rapida

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SolusTec/NuoPanel/main/install.sh)
```

## Caracteristicas

- **OpenLiteSpeed** - Servidor web de alta performance
- **Django** - Painel de controle web
- **MariaDB** - Banco de dados
- **PHP 7.4 - 8.5** - Multiplas versoes PHP
- **Postfix + Dovecot** - Servidor de email
- **Pure-FTPd** - Servidor FTP
- **PowerDNS** - Servidor DNS
- **Let's Encrypt** - Certificados SSL gratuitos
- **Softaculous** - Instalador de aplicacoes

## Configuracao

Todas as URLs e configuracoes podem ser personalizadas editando o arquivo `config.env`:

```bash
# Versoes PHP a instalar
PHP_VERSIONS="74 80 81 82 83 84 85"

# Versao PHP padrao
PHP_DEFAULT_VERSION="81"
```

## Estrutura do Projeto

```
SolusTec/NuoPanel/
├── install.sh              # Instalador principal
├── config.env              # Configuracao centralizada
├── common-functions.sh     # Funcoes compartilhadas
├── assets/                 # Arquivos grandes
├── config/
│   ├── ubuntu.txt         # Python requirements (Ubuntu)
│   ├── centos.txt         # Python requirements (CentOS/Alma/Rocky)
│   ├── banner-ssh.sh      # Banner SSH
│   ├── httpd_config.conf  # Config OpenLiteSpeed
│   └── vhosts/            # Virtual hosts
└── scripts/                # Scripts modulares de instalacao
```

## Apos a Instalacao

O painel estara disponivel em:

```
URL: https://SEU-IP:PORTA
Usuario: admin
Senha: (exibida no final da instalacao)
```

## Atualizacao

Para atualizar o painel:

```bash
nuopanel-update
```

## Suporte

- GitHub: https://github.com/SolusTec/NuoPanel
- Issues: https://github.com/SolusTec/NuoPanel/issues

## Licenca

Este projeto e um fork customizado do OLSPanel.

---

**Desenvolvido por SolusTec**
