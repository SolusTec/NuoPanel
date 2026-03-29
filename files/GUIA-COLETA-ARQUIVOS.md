# GUIA DE COLETA DE ARQUIVOS PARA O REPOSITÓRIO NUOPANEL

## ESTRUTURA DO OLSPANEL ORIGINAL

```
osmanfc/olspanel/
├── install.sh
├── requirements.txt
├── ub24req.txt
├── reqcentos.txt
├── Ubuntu/panel.sh
├── Centos/
├── Debian/
└── item/install (arquivo ZIP com configs)
```

**IMPORTANTE:** O OLSPanel NÃO hospeda os arquivos grandes no GitHub!
Eles estão hospedados em https://olspanel.com/

---

## ARQUIVOS QUE VOCÊ PRECISA COLETAR

### 1. ARQUIVOS DO SERVIDOR DE PRODUÇÃO (root@Nuo-Panel)

Execute no servidor de produção:

```bash
# Criar diretório temporário
mkdir -p /tmp/nuopanel-export/{config,assets}

# === ARQUIVOS /config ===

# ub24req.txt
cp /root/venv/requirements.txt /tmp/nuopanel-export/config/ub24req.txt

# nuopanel.sh (banner SSH)
cp /etc/profile.d/nuopanel.sh /tmp/nuopanel-export/config/nuopanel.sh 2>/dev/null || \
echo '#!/bin/bash
echo ""
echo "  _   _             ____                  _ "
echo " | \\ | |_   _  ___|  _ \\ __ _ _ __   ___| |"
echo " |  \\| | | | |/ _ \\ |_) / _\` | '\'\'_ \\ / _ \\ |"
echo " | |\\  | |_| |  __/  __/ (_| | | | |  __/ |"
echo " |_| \\_|\\__,_|\\___|_|   \\__,_|_| |_|\\___|_|"
echo ""
echo " Sistema de Gerenciamento de Hospedagem Web"
echo ""' > /tmp/nuopanel-export/config/nuopanel.sh

# httpd_config.conf
cp /usr/local/lsws/conf/httpd_config.conf /tmp/nuopanel-export/config/httpd_config.conf

# cp.service
cp /etc/systemd/system/cp.service /tmp/nuopanel-export/config/cp.service

# vhosts
mkdir -p /tmp/nuopanel-export/config/vhosts/{Example,mypanel}
cp /usr/local/lsws/conf/vhosts/Example/vhconf.conf /tmp/nuopanel-export/config/vhosts/Example/
cp /usr/local/lsws/conf/vhosts/mypanel/vhconf.conf /tmp/nuopanel-export/config/vhosts/mypanel/

# === ARQUIVOS /assets ===

# panel_latest.zip (você já tem)
cp /root/panel_latest.zip /tmp/nuopanel-export/assets/panel_latest.zip

# panel_db.sql
cp /root/item/panel_db.sql /tmp/nuopanel-export/assets/panel_db.sql 2>/dev/null

# Listar arquivos coletados
echo ""
echo "=== ARQUIVOS COLETADOS ==="
ls -lh /tmp/nuopanel-export/config/
ls -lh /tmp/nuopanel-export/config/vhosts/*/
ls -lh /tmp/nuopanel-export/assets/
```

---

### 2. ARQUIVOS DO OLSPANEL ORIGINAL (baixar diretamente)

Esses arquivos NÃO estão no GitHub, estão hospedados em olspanel.com:

```bash
# No seu computador local ou servidor de teste:

# install.zip (contém todas as configs: postfix, dovecot, pure-ftpd, etc)
wget -O install.zip https://raw.githubusercontent.com/osmanfc/olspanel/main/item/install

# base_apps_config.zip (contém phpMyAdmin, webmail, etc)
# Este arquivo NÃO está no GitHub! Você precisa:
# OPÇÃO 1: Copiar do servidor de produção em /root/item/
cp /root/item/base_apps_config.zip /tmp/nuopanel-export/assets/

# OPÇÃO 2: Baixar de uma instalação fresca do OLSPanel
```

---

### 3. NUOAPP.ZIP (Softaculous/OLSAPP)

Você mencionou que já tem o `nuoapp.zip` (renomeado de olsapp.zip).

Se não tiver, baixe de:
```bash
# Este arquivo também NÃO está no GitHub
# Você precisa copiar do servidor de produção:
cp /root/item/olsapp.zip /tmp/nuopanel-export/assets/nuoapp.zip
```

---

## ESTRUTURA FINAL DO REPOSITÓRIO NUOPANEL

```
SolusTec/NuoPanel/
├── install.sh ✅
├── config.env ✅
├── common-functions.sh ✅
├── README.md ✅
├── assets/
│   ├── panel_latest.zip ⏳ (coletar do servidor)
│   ├── base_apps_config.zip ⏳ (coletar do servidor)
│   ├── nuoapp.zip ⏳ (você já tem?)
│   ├── install.zip ⏳ (baixar do GitHub olspanel)
│   └── panel_db.sql ⏳ (coletar do servidor)
├── config/
│   ├── ub24req.txt ⏳ (coletar do servidor)
│   ├── nuopanel.sh ⏳ (coletar do servidor)
│   ├── httpd_config.conf ⏳ (coletar do servidor)
│   ├── cp.service ⏳ (coletar do servidor)
│   └── vhosts/
│       ├── Example/vhconf.conf ⏳ (coletar do servidor)
│       └── mypanel/vhconf.conf ⏳ (coletar do servidor)
└── scripts/
    ├── 01-system-setup.sh ✅
    ├── 02-openlitespeed.sh ✅
    ├── 03-mariadb.sh ✅
    ├── 04-python-venv.sh ✅
    ├── 05-extract-panel.sh ✅
    ├── 06-mail-ftp-dns.sh ✅
    ├── 07-ssl-config.sh ✅
    ├── 08-softaculous.sh ✅
    └── 09-finalize.sh ✅
```

---

## PRÓXIMOS PASSOS

1. **Execute o script de coleta** no servidor de produção
2. **Baixe** o `/tmp/nuopanel-export/` do servidor
3. **Organize** os arquivos na estrutura do repositório
4. **Faça upload** para o GitHub em `SolusTec/NuoPanel`
5. **Teste** a instalação em um servidor limpo

---

## OBSERVAÇÕES IMPORTANTES

- `panel_setup.zip` em https://olspanel.com/panel_setup.zip = seu `panel_latest.zip`
- `install.zip` contém configs de Postfix, Dovecot, Pure-FTPd, PowerDNS
- `base_apps_config.zip` contém phpMyAdmin e webmail
- Todos os arquivos de `/root/item/move/` vêm do `install.zip`
