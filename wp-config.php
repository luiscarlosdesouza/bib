<?php
/**
 * Configurações básicas do WordPress (Containerizado / Portainer Stack)
 *
 * Todas as configurações sensíveis e de ambiente são lidas via variáveis
 * de ambiente definidas no Portainer Stack ou arquivo .env.
 *
 * @package WordPress
 */

if ( ! function_exists( 'getenv_docker' ) ) {
	/**
	 * Função auxiliar para ler variáveis de ambiente ou Docker Secrets (*_FILE).
	 */
	function getenv_docker( $env, $default = '' ) {
		if ( $fileEnv = getenv( $env . '_FILE' ) ) {
			return rtrim( file_get_contents( $fileEnv ), "\r\n" );
		} elseif ( ( $val = getenv( $env ) ) !== false && $val !== '' ) {
			return $val;
		} else {
			return $default;
		}
	}
}

// ** Suporte a Proxy Reverso (Nginx Proxy Manager / Cloudflare / Load Balancer) ** //
if ( isset( $_SERVER['HTTP_X_FORWARDED_PROTO'] ) && strpos( $_SERVER['HTTP_X_FORWARDED_PROTO'], 'https' ) !== false ) {
	$_SERVER['HTTPS'] = 'on';
}
if ( isset( $_SERVER['HTTP_X_FORWARDED_HOST'] ) && ! empty( $_SERVER['HTTP_X_FORWARDED_HOST'] ) ) {
	$forwarded_hosts = explode( ',', $_SERVER['HTTP_X_FORWARDED_HOST'] );
	$_SERVER['HTTP_HOST'] = trim( $forwarded_hosts[0] );
}

// ** Configurações do Banco de Dados (MariaDB / MySQL) ** //
define( 'DB_NAME',     getenv_docker( 'WORDPRESS_DB_NAME',     getenv_docker( 'DB_NAME',     'bib' ) ) );
define( 'DB_USER',     getenv_docker( 'WORDPRESS_DB_USER',     getenv_docker( 'DB_USER',     'bib' ) ) );
define( 'DB_PASSWORD', getenv_docker( 'WORDPRESS_DB_PASSWORD', getenv_docker( 'DB_PASSWORD', '' ) ) );
define( 'DB_HOST',     getenv_docker( 'WORDPRESS_DB_HOST',     getenv_docker( 'DB_HOST',     'db:3306' ) ) );
define( 'DB_CHARSET',  getenv_docker( 'WORDPRESS_DB_CHARSET',  'utf8mb4' ) );
define( 'DB_COLLATE',  getenv_docker( 'WORDPRESS_DB_COLLATE',  '' ) );

// ** URLs do Site (Homologação / Produção / Local) ** //
$wp_home    = getenv_docker( 'WP_HOME', '' );
$wp_siteurl = getenv_docker( 'WP_SITEURL', $wp_home );

if ( ! empty( $wp_home ) ) {
	define( 'WP_HOME', rtrim( $wp_home, '/' ) );
}
if ( ! empty( $wp_siteurl ) ) {
	define( 'WP_SITEURL', rtrim( $wp_siteurl, '/' ) );
}

// ** Chaves únicas de autenticação e salts ** //
define( 'AUTH_KEY',         getenv_docker( 'WORDPRESS_AUTH_KEY',         '3[rRK2b#We8YHv@t!RRr59,8w(OfQ&8]%<441Vh7;x|KppBj7W)%t0w*$CN(!&z.' ) );
define( 'SECURE_AUTH_KEY',  getenv_docker( 'WORDPRESS_SECURE_AUTH_KEY',  'vh3TIkw 1NN$?xE[V9oARbLKolLDx?04=To45c`yWm~<ynRXUG|K0;7SNvSE%W#<' ) );
define( 'LOGGED_IN_KEY',    getenv_docker( 'WORDPRESS_LOGGED_IN_KEY',    'Zp4|aq<$@e-V^:8j}U9,GJbSmJ6r>7?J7~u!hS7+3D0ieD:rS;j5+ShM^ZzCxLb7' ) );
define( 'NONCE_KEY',        getenv_docker( 'WORDPRESS_NONCE_KEY',        '3ExNXw5eEa@IDCEKKGf/,)?c_Gl.5QLQ?o.<yq`0_[i(-&R0pr=#M|)_;~qkiYv-' ) );
define( 'AUTH_SALT',        getenv_docker( 'WORDPRESS_AUTH_SALT',        '?,f7*<<Ut!/_[Lj5EkAwVvx7dyVa#?54`bj!-D))}q vTzmgG;0Kxv}ue+jP*JC{' ) );
define( 'SECURE_AUTH_SALT', getenv_docker( 'WORDPRESS_SECURE_AUTH_SALT', 'oB{ho2&ldQh*c !$!`PllNYYP4+h~sbR+K9)0XshfXy04!!|x%{l^vN;;(5f1(K-' ) );
define( 'NONCE_SALT',       getenv_docker( 'WORDPRESS_NONCE_SALT',       '1&BhM)5?5K!,6ema? jtoEGS#%LuRXy}dngs@zLX8?5?k}2LifcMs[jh7kl*:7K;' ) );
define( 'LOGGED_IN_SALT',   getenv_docker( 'WORDPRESS_LOGGED_IN_SALT',   'T7l~W]ve3Xjdo|4[A~DYB#:-(}Xo6 .=_B!%KDNN`[He0_VML^)Wc^,?`gd0R)b.' ) );

// ** Prefixo das tabelas do banco de dados ** //
$table_prefix = getenv_docker( 'WORDPRESS_TABLE_PREFIX', 'wp_' );

// ** Desempenho, Memória e Sistema de Arquivos Direto no Container ** //
define( 'WP_CACHE',            filter_var( getenv_docker( 'WP_CACHE', 'false' ), FILTER_VALIDATE_BOOLEAN ) );
define( 'FS_METHOD',           'direct' );
define( 'WP_MEMORY_LIMIT',     getenv_docker( 'WP_MEMORY_LIMIT', '256M' ) );
define( 'WP_MAX_MEMORY_LIMIT', getenv_docker( 'WP_MAX_MEMORY_LIMIT', '512M' ) );

// ** Modo de Debug ** //
define( 'WP_DEBUG',         filter_var( getenv_docker( 'WORDPRESS_DEBUG', 'false' ), FILTER_VALIDATE_BOOLEAN ) );
define( 'WP_DEBUG_LOG',     filter_var( getenv_docker( 'WORDPRESS_DEBUG_LOG', 'false' ), FILTER_VALIDATE_BOOLEAN ) );
define( 'WP_DEBUG_DISPLAY', filter_var( getenv_docker( 'WORDPRESS_DEBUG_DISPLAY', 'false' ), FILTER_VALIDATE_BOOLEAN ) );

/* Isto é tudo, pode parar de editar! :) */

/** Caminho absoluto para o diretório WordPress. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Configura as variáveis e arquivos do WordPress. */
require_once ABSPATH . 'wp-settings.php';
