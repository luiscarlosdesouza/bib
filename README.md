# Biblioteca Carlos Benjamin de Lyra (IME-USP) — WordPress Containerizado

Repositório oficial da aplicação WordPress da **Biblioteca Carlos Benjamin de Lyra (IME-USP)**, preparada para execução em containers Docker (**PHP 8.3 + Apache** e **MariaDB 10.11 LTS**), integrada à rede `web` (Nginx Proxy Manager) e pronta para implantação via **Portainer Stack**.

---

## Sumário

1. [Arquitetura da Solução](#1-arquitetura-da-solução)
2. [Pré-requisitos](#2-pré-requisitos)
3. [Implantação via Portainer (Stack com Git)](#3-implantação-via-portainer-stack-com-git)
4. [Implantação Local / CLI (Docker Compose)](#4-implantação-local--cli-docker-compose)
5. [Configuração no Nginx Proxy Manager e Troca de Domínio](#5-configuração-no-nginx-proxy-manager-e-troca-de-domínio)
6. [Acesso Administrativo do WordPress](#6-acesso-administrativo-do-wordpress)
7. [Manual de Backup e Restauração](#7-manual-de-backup-e-restauração)
8. [Evolução Futura: Desacoplamento de Uploads e Banco do Git](#8-evolução-futura-desacoplamento-de-uploads-e-banco-do-git)

---

## 1. Arquitetura da Solução

* **Aplicação (`bib-app`):**
  * Imagem construída a partir de `php:8.3-apache` com as extensões `mysqli`, `pdo_mysql`, `gd` (FreeType/JPEG/WebP), `imagick`, `zip`, `intl`, `exif`, `bcmath`, `opcache` e **WP-CLI** pré-instalado.
  * **WordPress:** `7.1.3` (Tema ativo: `education-hub` v3.0.1).
  * **Automação de Inicialização ([docker/entrypoint.sh](docker/entrypoint.sh)):**
    1. Aguarda o banco de dados MariaDB ficar saudável.
    2. Caso o banco esteja vazio no primeiro deploy, importa automaticamente o dump inicial (`bib.sql`).
    3. Sempre que a variável `WP_HOME` mudar (ex.: de homologação para produção ou mudança de DNS), executa automaticamente `wp search-replace` em todas as tabelas (respeitando dados serializados do PHP) para atualizar links internos, mídias e menus.
* **Banco de Dados (`bib-db`):**
  * Imagem oficial `mariadb:10.11` com charset `utf8mb4` e collation `utf8mb4_unicode_ci`.
* **Redes e Volumes:**
  * `web` *(externa)*: Conecta o container `bib-app` ao **Nginx Proxy Manager**.
  * `bib_internal` *(bridge interna)*: Isola a comunicação entre `bib-app` e `bib-db`.
  * `bib_uploads` e `bib_db_data`: Volumes Docker persistentes para arquivos de mídia (`wp-content/uploads`) e dados do MariaDB (`/var/lib/mysql`).

---

## 2. Pré-requisitos

No servidor Docker onde o Portainer e o Nginx Proxy Manager estão rodando, certifique-se de que a rede externa `web` existe:

```bash
docker network create web
```
*(Caso o Nginx Proxy Manager já esteja rodando na rede `web`, este comando não é necessário).*

---

## 3. Implantação via Portainer (Stack com Git)

1. Acesse o painel do **Portainer** e selecione o seu ambiente Docker.
2. No menu lateral, clique em **Stacks** $\rightarrow$ **+ Add stack**.
3. Preencha os campos:
   * **Name:** `bib`
   * **Build method:** Selecione **Repository**.
   * **Repository URL:** `https://github.com/luiscarlosdesouza/bib`
   * **Repository reference:** `refs/heads/main`
   * **Compose path:** `docker-compose.yml`
4. Na seção **Environment variables**, adicione as variáveis conforme o ambiente desejado (você pode clicar em *Advanced mode* e colar o bloco abaixo ajustando as senhas e o domínio):

### Exemplo de Variáveis — Homologação (`bib.dos.ime.usp.br`)
```env
WP_HOME=https://bib.dos.ime.usp.br
APP_PORT=8080
WORDPRESS_DB_HOST=db:3306
WORDPRESS_DB_NAME=bib
WORDPRESS_DB_USER=bib
WORDPRESS_DB_PASSWORD=DEFINA_SENHA_FORTE_DO_BANCO
MYSQL_ROOT_PASSWORD=DEFINA_SENHA_FORTE_ROOT
WORDPRESS_TABLE_PREFIX=wp_
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=DEFINA_SENHA_DO_ADMIN_WP
WORDPRESS_DEBUG=false
```

### Exemplo de Variáveis — Produção (`bib.sistemas.ime.usp.br`)
```env
WP_HOME=https://bib.sistemas.ime.usp.br
APP_PORT=8080
WORDPRESS_DB_HOST=db:3306
WORDPRESS_DB_NAME=bib
WORDPRESS_DB_USER=bib
WORDPRESS_DB_PASSWORD=DEFINA_SENHA_FORTE_DO_BANCO
MYSQL_ROOT_PASSWORD=DEFINA_SENHA_FORTE_ROOT
WORDPRESS_TABLE_PREFIX=wp_
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=DEFINA_SENHA_DO_ADMIN_WP
WORDPRESS_DEBUG=false
```

5. Clique em **Deploy the stack**.
   * Na primeira execução, o Portainer fará o build da imagem PHP 8.3, iniciará o MariaDB, importará automaticamente o banco `bib.sql` e converterá todas as URLs antigas (`https://www.ime.usp.br/bib`) para o valor configurado em `WP_HOME`.

---

## 4. Implantação Local / CLI (Docker Compose)

Para subir em máquina local (ex.: Docker Desktop):

```bash
# 1. Clonar o repositório
git clone https://github.com/luiscarlosdesouza/bib.git
cd bib

# 2. Criar a rede externa 'web' (caso ainda não exista)
docker network create web

# 3. Criar o arquivo .env a partir do modelo
cp .env.example .env
# Edite o .env e defina WP_HOME=http://localhost:8080

# 4. Construir e subir os containers
docker compose up -d --build

# 5. Acompanhar o log de importação e ajuste de URLs
docker logs -f bib-app
```

Acesse em seu navegador: `http://localhost:8080`.

---

## 5. Configuração no Nginx Proxy Manager e Troca de Domínio

### 5.1. Criar o Proxy Host no Nginx Proxy Manager
1. Acesse o **Nginx Proxy Manager** $\rightarrow$ **Hosts** $\rightarrow$ **Proxy Hosts** $\rightarrow$ **Add Proxy Host**.
2. Aba **Details**:
   * **Domain Names:**
     * Homologação: `bib.dos.ime.usp.br`
     * Produção: `bib.sistemas.ime.usp.br` (ou futuramente `bib.ime.usp.br`)
   * **Scheme:** `http`
   * **Forward Hostname / IP:** `bib-app` *(nome do container na rede `web`)*
   * **Forward Port:** `80`
   * Marque **Block Common Exploits** e **Websockets Support**.
3. Aba **SSL**:
   * Selecione ou solicite o certificado Let's Encrypt para o domínio.
   * Marque **Force SSL** e **HTTP/2 Support**.
4. Clique em **Save**.

> **Nota sobre HTTPS:** O arquivo [wp-config.php](wp-config.php) já está preparado para ler os cabeçalhos `X-Forwarded-Proto` e `X-Forwarded-Host` enviados pelo Nginx Proxy Manager, evitando loops de redirecionamento.

### 5.2. Como Alterar o Domínio no Futuro (Ex.: para `https://bib.ime.usp.br`)
Quando o DNS definitivo `bib.ime.usp.br` estiver apontando para o servidor:
1. Adicione `bib.ime.usp.br` no Proxy Host do **Nginx Proxy Manager** (e gere o SSL).
2. No **Portainer**, abra a Stack `bib`, altere a variável de ambiente:
   ```env
   WP_HOME=https://bib.ime.usp.br
   ```
3. Clique em **Update the stack** (com a opção *Re-pull image and redeploy* ou apenas reinicie o container `bib-app`).
4. O script de inicialização detectará automaticamente a mudança de `WP_HOME` e executará o `wp search-replace` em todo o banco de dados para o novo domínio sem quebrar menus, widgets ou imagens.

### 5.3. Redirecionamento de `www.ime.usp.br/bib`
* Caso o servidor principal `www.ime.usp.br` redirecione requisições de `/bib` ou `/bib/*` para o novo servidor, o [.htaccess](.htaccess) do container já possui uma regra de compatibilidade (`RewriteRule ^bib/(.*)$ /$1 [R=301,L]`) que remove o prefixo `/bib/` automaticamente caso algum link antigo ainda o inclua.

---

## 6. Acesso Administrativo do WordPress

* **URL de Login Personalizada:** Por segurança (plugin *WPS Hide Login*), a URL `/wp-admin` retorna `404` para visitantes não autenticados. O login deve ser feito em:
  * **Local:** `http://localhost:8080/logbime`
  * **Homologação:** `https://bib.dos.ime.usp.br/logbime`
  * **Produção:** `https://bib.sistemas.ime.usp.br/logbime`

### Como Redefinir a Senha de Administrador
Você pode redefinir a senha do usuário `admin` (ou qualquer outro administrador) de duas formas:

1. **Via Variável de Ambiente no Portainer:**
   Defina na Stack:
   ```env
   WP_ADMIN_USER=admin
   WP_ADMIN_PASSWORD=SuaNovaSenhaForteAqui
   ```
   Ao reiniciar o container `bib-app`, a senha será aplicada automaticamente. *(Depois de logar, você pode remover a variável `WP_ADMIN_PASSWORD` da Stack).*

2. **Via Terminal / Console do Container (WP-CLI):**
   ```bash
   docker exec -it bib-app wp user list --allow-root
   docker exec -it bib-app wp user update admin --user_pass="SuaNovaSenhaForteAqui" --allow-root
   ```

---

## 7. Manual de Backup e Restauração

### 7.1. Realizar Backup do Banco de Dados (MariaDB)
Execute no servidor host (ou via agendamento cron):

```bash
# Gerar dump SQL compactado com data
docker exec bib-db mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" bib | gzip > backup_bib_db_$(date +%F).sql.gz
```
*(Alternativa usando WP-CLI dentro do container `bib-app`, sem precisar da senha de root)*:
```bash
docker exec bib-app wp db export - --allow-root | gzip > backup_bib_db_$(date +%F).sql.gz
```

### 7.2. Realizar Backup dos Arquivos de Mídia (`uploads`)
Os arquivos enviados pelos usuários ficam persistidos no volume Docker `bib_uploads`:

```bash
docker run --rm \
  -v bib_uploads:/uploads:ro \
  -v $(pwd):/backup \
  alpine tar -czf /backup/backup_bib_uploads_$(date +%F).tar.gz -C /uploads .
```

---

### 7.3. Restaurar Backup do Banco de Dados

1. **A partir de um arquivo `.sql.gz`:**
   ```bash
   gunzip < backup_bib_db_YYYY-MM-DD.sql.gz | docker exec -i bib-db mariadb -u bib -p"$WORDPRESS_DB_PASSWORD" bib
   ```
2. **A partir de um arquivo `.sql` descompactado (ex.: `bib.sql`):**
   ```bash
   docker exec -i bib-db mariadb -u bib -p"$WORDPRESS_DB_PASSWORD" bib < bib.sql
   ```
3. **Sincronizar URLs após restauração (caso o backup venha de outro domínio):**
   Basta reiniciar o container `bib-app` para o entrypoint ajustar as URLs para o `WP_HOME` atual:
   ```bash
   docker restart bib-app
   ```

### 7.4. Restaurar Backup dos Arquivos de Mídia (`uploads`)

```bash
docker run --rm \
  -v bib_uploads:/uploads \
  -v $(pwd):/backup \
  alpine sh -c "rm -rf /uploads/* && tar -xzf /backup/backup_bib_uploads_YYYY-MM-DD.tar.gz -C /uploads"

# Corrigir permissões para o usuário do Apache (www-data)
docker exec bib-app chown -R www-data:www-data /var/www/html/wp-content/uploads
```

---

## 8. Evolução Futura: Desacoplamento de Uploads e Banco do Git

Atualmente, para permitir implantação imediata via Git no Portainer, a pasta `wp-content/uploads` e o arquivo `bib.sql` estão incluídos no repositório. Quando desejar migrar para a rotina de backup externo:

1. Faça o backup atualizado de `bib_uploads` e do banco conforme a [Seção 7](#7-manual-de-backup-e-restauração).
2. Adicione no [.gitignore](.gitignore):
   ```gitignore
   bib.sql
   *.sql
   *.sql.gz
   wp-content/uploads/
   ```
3. Remova-os do índice do Git (mantendo os arquivos locais e nos volumes Docker de produção):
   ```bash
   git rm --cached bib.sql
   git rm -r --cached wp-content/uploads
   git commit -m "chore: move banco e uploads para armazenamento externo"
   git push
   ```
Os containers em execução no Portainer **não perderão nenhum dado**, pois o banco e a pasta `uploads` já estarão salvos nos volumes persistentes `bib_db_data` e `bib_uploads`.
