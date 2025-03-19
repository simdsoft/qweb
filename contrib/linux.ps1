# Ubuntu Linux
$Script:nginx_user = 'nginx'
$Script:mysql_user = 'mysql' # DO NOT MODIFY
$Script:php_user = 'www-data' # DO NOT MODIFY
$actions.fetch = @{
    nginx   = {
        $nginx_dir = "$install_prefix/nginx/$nginx_ver"
        if (!(Test-Path $nginx_dir -PathType Container)) {
            sudo apt install --allow-unauthenticated --yes make
            fetch_pkg -url "https://nginx.org/download/nginx-${nginx_ver}.tar.gz" -prefix 'cache'
            $nginx_src = Join-Path $download_path "nginx-${nginx_ver}"
            Push-Location $nginx_src
            sudo apt install --allow-unauthenticated --yes gcc make libz-dev libpcre3 libpcre3-dev libssl-dev
            $nginx_conf_dir = Join-Path $qweb_root "etc/nginx/$nginx_base_ver"
            $nginx_logs_dir = Join-Path $qweb_root 'var/nginx/logs'
            $nginx_tmp_dir = "$qweb_root/var/nginx/temp"
            ./configure --with-http_ssl_module --with-http_v3_module --prefix=$nginx_dir `
                --conf-path=$nginx_conf_dir/nginx.conf `
                --error-log-path=$nginx_logs_dir/error.log `
                --pid-path=$nginx_logs_dir/nginx.pid `
                --lock-path=$nginx_logs_dir/nginx.lock `
                --http-log-path=$nginx_logs_dir/access.log `
                --http-client-body-temp-path=$nginx_tmp_dir/client_body_temp `
                --http-proxy-temp-path=$nginx_tmp_dir/proxy_temp `
                --http-fastcgi-temp-path=$nginx_tmp_dir/fastcgi_temp `
                --http-uwsgi-temp-path=$nginx_tmp_dir/uwsgi_temp `
                --http-scgi-temp-path=$nginx_tmp_dir/scgi_temp
            make ; make install
            Pop-Location
        }
    }
    php     = {
        # ensure we can install old releases of php on ubuntu
        $php_ppa = $(grep -ri '^deb.*ondrej/php' /etc/apt/sources.list /etc/apt/sources.list.d/)
        if (!$php_ppa) {
            sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php
            sudo apt update
        }

        $php_pkg = "php$($php_ver.Major).$($php_ver.Minor)"
        sudo apt install --allow-unauthenticated --yes $php_pkg $php_pkg-fpm $php_pkg-mysql $php_pkg-curl $php_pkg-cgi
    }
    mysql   = {
        # sudo apt install mysql-server
        # we use offical deb to install latest mysql version 9.1.0
        $os_info = $PSVersionTable.OS.Split(' ')
        $os_name = $os_info[0].ToLower()
        $os_ver = $os_info[1].Split('.')
        $os_id = "$os_name$($os_ver[0]).$($os_ver[1])"
        $mysql_server_deb_bundle = "mysql-server_$mysql_ver-1${os_id}_amd64.deb-bundle.tar"
        if ($mysql_ver -eq $mysql_latest) {
            fetch_pkg "https://cdn.mysql.com//Downloads/MySQL-$($mysql_ver.Major).$($mysql_ver.Minor)/$mysql_server_deb_bundle" -prefix "cache/mysql-$mysql_ver"
        }
        else {
            fetch_pkg "https://downloads.mysql.com/archives/get/p/23/file/$mysql_server_deb_bundle" -prefix "cache/mysql-$mysql_ver"
        }

        $mysqld_cmd = Get-Command mysqld -ErrorAction SilentlyContinue
        if (!$mysqld_cmd) {
            # old ubuntu 22.04 maybe libaio1 ?
            $aio_package_name = 'libaio-dev'
            Push-Location $download_path/mysql-$mysql_ver
            sudo apt install --allow-unauthenticated --yes $aio_package_name libnuma-dev libmecab2
            sudo dpkg -i mysql-common_*.deb
            sudo dpkg -i mysql-community-client-plugins*amd64.deb
            sudo dpkg -i mysql-community-client-core*amd64.deb
            sudo dpkg -i mysql-community-client_*amd64.deb
            sudo dpkg -i libmysqlclient*amd64.deb
            sudo dpkg -i mysql-community-server-core*amd64.deb
            sudo dpkg -i mysql-client_*amd64.deb
            sudo dpkg -i mysql-community-server_*amd64.deb
            sudo dpkg -i mysql-server_*amd64.deb
            sudo dpkg --configure -a
            Pop-Location
        }
    }
    certbot = {
        sudo apt install --allow-unauthenticated --yes certbot python3-certbot-nginx
    }
}
$actions.init = @{
    php   = {
        $php_ini_dir = "/etc/php/$($php_ver.Major).$($php_ver.Minor)/cgi"
        $lines, $mods = mod_php_ini "$php_ini_dir/php.ini" $false
        if ($mods) {
            Set-Content -Path "$download_path/php.ini" -Value $lines
            sudo cp -f "$download_path/php.ini" "$php_ini_dir/php.ini"
        }
        else {
            println "php init: nothing need to do"
        }
    }
    mysql = {
	# MySQL 9.0+
        $my_conf_dst_file = '/etc/mysql/mysql.conf.d/mysqld.cnf'
        $my_conf_lines = Get-Content $my_conf_dst_file
	if ($my_conf_lines.Contains('bind-address = 127.0.0.1')) {
            println 'mysql init: nothing need to do'
	    return
	}
	$my_conf_file = "$qweb_root/etc/mysql/my.ini"
        $conf_lines = Get-Content $my_conf_file
        foreach ($line_text in $conf_lines) {
	    if ($line_text -match '^\s*#') {
		continue
            }
            if ($line_text -match '^\s*\[mysqld\]') {
                continue
            }
            if (!$line_text) {
                continue
            }
            println "mysql init: add config: $line_text to mysqld.conf"
            $my_conf_lines += $line_text
        }
        $tmp_conf_file = Join-Path $download_path 'mysqld.cnf'
        Set-Content -Path $tmp_conf_file -Value $my_conf_lines -Encoding utf8
        #sudo cp $tmp_conf_file $my_conf_dst_file
    }
}

$actions.start = @{
    nginx = {
        $nginx_dir = Join-Path $install_prefix "nginx/$nginx_ver"
        $nginx_conf = Join-Path $qweb_root "etc/nginx/$nginx_base_ver/nginx.conf"
        Push-Location $nginx_dir
        bash -c "sudo ./sbin/nginx -t -c '$nginx_conf'" | Out-Host
        bash -c "sudo ./sbin/nginx -c '$nginx_conf' >/dev/null 2>&1 &"
        Pop-Location
    }
    php   = {
        bash -c "nohup sudo -u www-data php-cgi -b 127.0.0.1:9000 >/dev/null 2>&1 &"
    }
    mysql = {
        bash -c "nohup sudo mysqld --user=$mysql_user >/dev/null 2>&1 &"
    }
}

$actions.stop = @{
    nginx = {
        sudo pkill -f nginx
    }
    php   = {
        sudo pkill -f php-cgi
    }
    mysql = {
        sudo pkill -f mysqld
    }
}
