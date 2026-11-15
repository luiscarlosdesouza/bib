# Histórico da Conversa e Contexto de Retomada — Projeto Biblioteca (IME-USP)

> **Para o Agente Antigravity no computador do trabalho:**  
> Leia este documento integralmente para absorver todo o contexto do que já foi executado, testado e enviado ao GitHub na sessão anterior, e continuar exatamente do ponto onde paramos.

---

## 1. Resumo Executivo do Estado Atual (Status do Projeto)

* **Repositório GitHub (Sincronizado):** `https://github.com/luiscarlosdesouza/bib` (branch `main`).
* **O que já está pronto e testado:**
  1. **Análise e Limpeza:** Código WordPress `7.1.3` (tema `education-hub` v3.0.1 e 13 plugins) verificado e compatibilizado com **PHP 8.3**. Removidos artefatos legados do servidor antigo (`cgi-bin/php-wrapper` do PHP 7.3, `.maintenance-old`, pasta vazia `biblioteca`, e `wp-content/advanced-cache.php` que tinha caminhos fixos `/home/spec/bib/www/`).
  2. **Refatoração de Segurança e Variáveis de Ambiente:**
     * [wp-config.php](wp-config.php): Lê credenciais do banco, URLs (`WP_HOME`, `WP_SITEURL`), debug e chaves `SALT` via variáveis de ambiente (`getenv_docker`) e trata cabeçalhos de Proxy Reverso (`HTTP_X_FORWARDED_PROTO` e `HTTP_X_FORWARDED_HOST`) para o **Nginx Proxy Manager**.
     * [.htaccess](.htaccess): Configurado para rodar na raiz do subdomínio (`RewriteBase /`), com regra `301` automática para redirecionar links antigos `/bib/*` para `/*`, e bloqueio (`403 Forbidden`) a arquivos sensíveis (`wp-config.php`, `.env`, `*.sql`).
  3. **Containerização Otimizada:**
     * [Dockerfile](Dockerfile): Baseado em `wordpress:php8.3-apache` (já com `mysqli`, `gd`, `imagick`, `zip`, `intl`, `exif`, `bcmath`, `opcache` pré-compilados) + `mariadb-client` + `WP-CLI`.
     * [docker/db/bib.sql.gz](docker/db/bib.sql.gz): Dump original do MariaDB compactado de 63,1 MB para **7,05 MB** (copiado para `/usr/src/bib-db/bib.sql.gz` fora da raiz web).
     * [docker/entrypoint.sh](docker/entrypoint.sh): Aguarda o banco `db` responder, importa automaticamente `bib.sql.gz` se o banco estiver vazio, executa `wp search-replace` automático sempre que `WP_HOME` mudar (convertendo `https://www.ime.usp.br/bib` e `/home/spec/bib/www`), e atualiza a senha do usuário `WP_ADMIN_USER` se `WP_ADMIN_PASSWORD` for informada.
     * [docker-compose.yml](docker-compose.yml): Serviços `app` (`bib-app`) e `db` (`bib-db` com `mariadb:10.11`), conectados à rede externa `web` (para o Nginx Proxy Manager) e à rede interna `bib_internal`, usando volumes persistentes `bib_uploads` e `bib_db_data`.
  4. **Credenciais e Acesso Administrativo do WordPress:**
     * **URL de Login (plugin WPS Hide Login):** `/logbime` (acessar `/wp-admin` deslogado retorna 404 por segurança).
     * **Usuário Admin:** `admin`
     * **Senha definida via `.env` local:** `Admin@Bib2026` (configurável via variável `WP_ADMIN_PASSWORD`).
     * **Senha original do banco (`bib`):** `8MPZ7ukIHUqV68gn`

* **Ponto Pendente para Retomar no Trabalho:**
  * Ao tentar criar a Stack no **Portainer** do servidor de produção remotamente, o proxy reverso (`openresty` / Nginx Proxy Manager) retornou **`504 Gateway Time-out`** após 60 segundos enquanto o servidor clonava os ~800 MB do repositório GitHub e construía a imagem.
  * **Próximo passo no trabalho:**
    1. Verificar no Portainer de produção (em **Containers** / **Images** / **Stacks**) se o deploy terminou em segundo plano ou acessar o Portainer diretamente na rede local (ou ajustar `proxy_read_timeout 600s;` no Nginx Proxy Manager).
    2. Caso ainda queira evitar qualquer `git clone` grande pelo Portainer, podemos usar uma Stack via **Web editor** ou publicar a imagem pronta no GitHub Container Registry (`ghcr.io`).

---

## 2. Transcrição Completa da Conversa

### Mensagem 1 — Usuário
> Olá, nesta pasta eu coloquei o backup que fiz de um wordpress que estava em um servidor que foi desativado, qual o desafio, subir este site de um biblioteca em um container para que possa subir no meu servidor de produção, no primeiro momento faça uma análise do código e trace o planejado, lembrando que precisamos corrigir para já subir na última versão estável do php, acredito que esta versão rodava no php 7.43 mas o wordpress já estava na versão 7, da uma conferida nos arquivos.  
> copiei para pasta o banco de dados bib.sql, se não achar as credenciais me avise que acho que tenho anotado.  
> Lembrando que minha infra-estrutura do servidor é o portainer (vou querer subir esta app via stack) e colocar em um repositõrio que vou colocar no github para facilitar atualizações futuras ou portabilidade para outro servidor se precisar. A rede do container precisa se chamar web para poder rodar no meu nginx manager. Todos dados sensíveis iremos colocar em variais de ambiente.  
> já criei o repositório do github que iremos usar para subir nosso projeto:  
> https://github.com/luiscarlosdesouza/bib  
> Nele vamos colocar um manual no readme dando instruções de instalação e restauração de backup.  
> acabei de subir do docker.desktop em minha máquina pra facilitar nosso trablho.  
> Qualquer dúvida me avise

### Resposta 1 — Antigravity
* Realizada a inspeção completa dos arquivos:
  * Confirmado WordPress `7.1.3` em `wp-includes/version.php` e wrapper antigo `cgi-bin/php-wrapper` apontando para `php7.3`.
  * Encontradas as credenciais no `wp-config.php` (`DB_NAME=bib`, `DB_USER=bib`, `DB_PASSWORD=8MPZ7ukIHUqV68gn`, `DB_HOST=mysql.ime.usp.br`) e os salts.
  * Identificada a URL de login oculta `/logbime` (plugin `wps-hide-login`) e 13 usuários na tabela `wp_users`.
  * Verificada compatibilidade do tema `education-hub` (v3.0.1) e dos 13 plugins com PHP 8.3.
  * Identificados pontos de correção: `wp-content/advanced-cache.php` com caminho fixo `/home/spec/bib/www/`, `.htaccess` com `RewriteBase /bib/`, ausência de suporte a `HTTP_X_FORWARDED_PROTO` no `wp-config.php`.
* Feitas 3 perguntas de alinhamento sobre: (1) domínio/subdomínio em homologação e produção, (2) inclusão de `uploads` e banco no GitHub neste primeiro momento, e (3) método de deploy no Portainer.

---

### Mensagem 2 — Usuário
> 1 - no servidor de testes - homolocagação ira ficar em bib.dos.ime.usp.br em produção ficara bib.sistemas.ime.usp.br depois posso fazer um redirect em www.ime.usp.br/bib apontando para estes servidores, será tratato no proxy manager de cada servidor. A uma possibilidade no futuro de o dns apontar diretamente para bib.ime.usp.br. Então isto deverá ser fácil e documentado para alterarmos conforme necessário.  
> 2 - neste primeiro momento que estamos com urgencia para colocar no ar vamos subir os uploads e o banco, no futuro vamos trabalhar separadamente como backup externo.  
> 3 - eu aponto diretamente parao repositório do git, por isso já precisa estar tudo lá, template, dados, bancos, arquivos, etc..

### Resposta 2 — Antigravity
* Executada a higienização dos arquivos legados (`cgi-bin`, `biblioteca`, `.maintenance-old`, `wp-content/advanced-cache.php`, `wp-content/wpo-cache`).
* Criados/refatorados:
  * `wp-config.php` (variáveis de ambiente + suporte a HTTPS via Nginx Proxy Manager).
  * `.htaccess` (`RewriteBase /`, redirect 301 de `/bib/*` para `/*`, bloqueio de arquivos sensíveis).
  * `Dockerfile`, `docker/php/custom.ini`, `docker/entrypoint.sh` (com importação automática do banco e `wp search-replace` dinâmico baseado na variável `WP_HOME`), `docker-compose.yml`, `.env.example`, `.env`, `.gitignore`, `.gitattributes` e `README.md`.
* Subidos e testados os containers localmente no Docker Desktop (`http://localhost:8080` e `http://localhost:8080/logbime/` retornando `200 OK`, redirect `/bib/sobre-a-biblioteca/` retornando `301`, e `/wp-config.php` retornando `403`).
* Realizado o commit e push para `https://github.com/luiscarlosdesouza/bib`.

---

### Mensagem 3 — Usuário
> qual a senha de admin para entrar em http://localhost:8080/logbime? não existe WP_ADMIN_PASSWORD= em .env, como coloco isso em variaveis de ambiente do portainer tambem?

### Resposta 3 — Antigravity
* Explicado que no dump original as senhas estão em hash (`$P$B...`).
* Adicionadas as variáveis `WP_ADMIN_USER=admin` e `WP_ADMIN_PASSWORD=Admin@Bib2026` no arquivo `.env` local e aplicada a senha no container (`wp user update admin`).
* Atualizado o `README.md` com `WP_ADMIN_USER` e `WP_ADMIN_PASSWORD` nos blocos de variáveis de ambiente do Portainer (Homologação e Produção) e enviado ao GitHub.

---

### Mensagem 4 — Usuário
> tentando fazer o deploy no servidor de produção, e deu este erro ao tentar criar a stack  
> `<html> <head><title>504 Gateway Time-out</title></head> <body> <center><h1>504 Gateway Time-out</h1></center> <hr><center>openresty</center> </body> </html>`

### Resposta 4 — Antigravity
* Diagnosticado que o erro `504 Gateway Time-out` vem do proxy reverso `openresty` (Nginx Proxy Manager) na frente do Portainer, cujo timeout padrão é de 60 segundos.
* Aplicadas 4 otimizações para acelerar o deploy:
  1. `Dockerfile` alterado para `FROM wordpress:php8.3-apache` (eliminando ~3 minutos de compilação das extensões `gd`, `imagick`, `intl`, `zip`).
  2. Uso de `COPY --chown=www-data:www-data` (eliminando o `chown -R` demorado no build).
  3. Compactação de `bib.sql` (63 MB) para `docker/db/bib.sql.gz` (7,05 MB) e remoção de 110 MB de arquivos `.js.map` do Gutenberg.
  4. Remoção de `condition: service_healthy` no `depends_on` do `docker-compose.yml` para liberar o retorno ao Portainer imediatamente.
* Feito novo commit limpo (sem o `bib.sql` de 63 MB no histórico) e enviado (`git push --force`) para o GitHub.

---

### Mensagem 5 — Usuário
> deve ser problema do proxy, como estou trabalhando remoto acho que vou ter que ir na empresa amanhã ver o que pode estar acontecendo, olha o erro  
> `<html> <head><title>504 Gateway Time-out</title></head> <body> <center><h1>504 Gateway Time-out</h1></center> <hr><center>openresty</center> </body> </html>`

### Resposta 5 — Antigravity
* Explicadas 3 alternativas para contornar o timeout de 60s do `openresty`:
  1. Verificar em **Containers** / **Images** no Portainer se o processo em segundo plano já concluiu sozinho.
  2. Adicionar `proxy_read_timeout 600s;` na aba **Advanced** do Proxy Host do Portainer no Nginx Proxy Manager, ou acessar o Portainer diretamente via `http://IP_DO_SERVIDOR:9000` / `https://IP_DO_SERVIDOR:9443`.
  3. Usar deploy instantâneo via **Web editor** (fazendo pull prévio das imagens em **Images** ou baixando os arquivos em background dentro do container).

---

### Mensagem 6 — Usuário
> salve toda nossa conversa no diretorio de nosso projeto, enquanto nao consigo resover o timeout eu vou começar a alterar um novo projeto e depois volto aqui, aliais, como continuar trabalhando do computador do meu trablho (estou em casa hoje), me diga o passo a passo do que preciso para continuar trabalhando amanha no meu antigravity do trabalho
