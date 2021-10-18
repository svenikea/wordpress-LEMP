#! /bin/bash 


# Load Distribution Environment variables
source /etc/os-release

apt () {
	sudo apt-get update
	sudo apt-get -y install \
		apt-transport-https \
		ca-certificates \
		curl \
		gnupg \
		lsb-release
	# Add Docker GPG Key
	# Add Docker repository
	if [[ $ID == "debian" ]]
	then
		if [[ $VERSION_ID == "9" ]]
		then
			curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
			echo \
				"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
				$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
			sudo apt-get update 
			sudo apt-get -y install docker-ce docker-ce-cli containerd.io
		elif [[ $VERSION_ID -lt 9 ]]
		then 
			echo "Detected $PRETTY_NAME which is not supported"
			exit 0
		fi
	elif [[ $ID == "ubuntu" ]]
	then
		if [[ "$VERSION_ID == 16.04" ]]
		then
			sudo gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv 9BDB3D89CE49EC21
			sudo gpg --export --armor 9BDB3D89CE49EC21 | sudo apt-key add -
			sudo add-apt-repository "deb [arch=amd64] \
    		https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
			sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
			sudo apt-get update 
			sudo apt-get -y install docker-ce docker-ce-cli containerd.io
		elif [[ "$VERSION_ID -lt 16.04" ]]
		then 
			echo "Detected $PRETTY_NAME which is not supported"
			exit 0
		elif [[ "$VERSION_ID == 18.04" ]]
		then
			curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
			echo \
			"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
			$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
			sudo apt-get update
			sudo apt-get -y install docker-ce docker-ce-cli containerd.io
		fi
	fi
	sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
}


yum () {
	sudo yum install -y yum-utils
	# Add Docker repository
	sudo yum-config-manager \
		--add-repo \
		https://download.docker.com/linux/centos/docker-ce.repo
	sudo yum install -y docker-ce docker-ce-cli containerd.io 
	sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

}

pacman () {
	sudo pacman -Sy
	sudo pacman -S docker docker-compose git base-devel --needed
}

if [[ $ID == "debian" || $ID == "ubuntu" ]] 
then
	echo "Detected $PRETTY_NAME which is supported"
	apt
elif [[ $ID == "centos" || $ID == "rhel"  ]]
then
	echo "Detected $PRETTY_NAME which is supported"
	yum
elif [[ $PID == "arch" || $PID == "manjaro" ]]
then
	echo "Detected $PRETTY_NAME which is supported"
	pacman
else 
	echo "Unsupported Distribution"
fi

clear

# Asking for network name for docker
read -t 2 -p "Network Name (Default is net): " network_name
network_name=${network_name:-net}

# Asking for Container name
## Wordpress 
read -t 2 -p "Wordpress Container Name (Default is wp): " wp_container_name
wp_container_name=${wp_container_name:-wp}
read -t 2 -p "Wordpress  Hostname (Default is wordpress): " wp_hostname
wp_hostname=${wp_hostname:-wordpress}
key=$(curl https://api.wordpress.org/secret-key/1.1/salt/)

## Database
read -t 2 -p "Database Container Name (Default is db): " db_container_name
db_container_name=${db_container_name:-db}
read -t 2 -p "Database Hostname (Default is mysql): " db_hostname
db_hostname=${db_hostname:-mysql}
read -t 2 -p "Database Database Name (Default is mysql): " db_table
db_table=${db_table:-mysql}
read -t 2 -p "Database User Name (Default is user): " db_username
db_username=${db_username:-user}
read -t 2 -p "Database User Password (Default is password): " db_password
db_password=${db_password:-password}

## Website
read -t 2 -p "Web Container name (Default is web): " web_container_name
web_container_name=${web_container_name:-web}
read -t 2 -p "Web hostname (Default is web): " web_hostname
web_hostname=${web_hostname:-web}
echo "SSL Connection keys and Cert"
read -t 2 -p "The key name (Default is server): " keyname
keyname=${keyname:-server}
keyname+='.key'
read -t 2 -p "The Cert name (Default is server): " certname
certname=${certname:-server}
certname+='.crt'
read -t 2 -p "How many days does this key will expires (Default is 365): " days
days=${days:-365}
read -t 2 -p "Specify the max file size in (M) allowed to upload (Default is 100MB): " file_size
file_size=${file_size:-100M}
read -t 2 -p "Allow unfiltered upload (yes[y]/no[n]): " allowed_unfilterd
allowed_unfilterd=${allowed_unfilterd:-y}
read -t 2 -p "Specify the server name: " 	server_name
server_name=${server_name:-localhost}

# Creating key for SSL connection
sudo mkdir -p nginx/ssl
sudo openssl req -x509 -nodes -newkey rsa:4096 -days ${days} -keyout ./nginx/ssl/${keyname} -out ./nginx/ssl/${certname} -subj "/C=US/ST=GA/L=Atlanta/O=NHK Inc/OU=DevOps Department/CN=wordpress-test.com"

# Export all variable to the environment file
sed "s/net/$network_name/g" -i ./.env
sed "s/wp/$wp_container_name/g" -i ./.env
sed "s/wordpress/$wp_hostname/g" -i ./.env
sed "s/mysql/$db_hostname/g" -i ./.env
sed "s/db/$db_container_name/g" -i ./.env
sed "s/user/$db_username/g" -i ./.env
sed "s/password/$db_password/g" -i ./.env
sed "s/mysql/$db_table/g" -i ./.env
sed "s/web/$web_container_name/g" -i ./.env
sed "s/web/$web_hostname/g" -i ./.env
sed "s/<MB>/$file_size/g" -i ./nginx/my-nginx.conf
sed "s/post_max_size = <MB>/post_max_size = $file_size/g" -i ./wordpress/php-fpm/my-php-development.ini
sed "s/upload_max_filesize = <MB>/upload_max_filesize = $file_size/g" -i ./wordpress/php-fpm/my-php-development.ini
sed "s/<key>/$keyname/g" -i ./.env
sed "s/<certificate>/$certname/g" -i ./.env
sed "s/<key>/$keyname/g" -i ./nginx/my-default.conf
sed "s/<certificate>/$certname/g" -i ./nginx/my-default.conf
sed "s/<localhost>/$server_name/g" -i ./nginx/my-default.conf
sed "s/wordpress/$wp_hostname/g" -i ./nginx/my-default.conf
#sed -e '49,56d' -i  ./wordpress/wp-config/my-wp-config-sample.php

if [[ $allowed_unfilterd == "yes" || $allowed_unfilterd == "y" ]]
then
    sed  "s/Allow_Filter/define('ALLOW_UNFILTERED_UPLOADS', true);/g" -i ./wordpress/wp-config/my-wp-config-sample.php
else
    sed  "s/Allow_Filter//g" -i ./wordpress/wp-config/my-wp-config-sample.php
fi

# Start Docker Systemd
sudo systemctl start docker
# Run the Docker Compose
sudo docker network create -d bridge ${network_name}
sudo docker-compose up -d
web_ip=$(sudo docker inspect $web_container_name | grep '"IPAddress": "1' | tr -d  '", ' | cut -d ':' -f2)
database_ip=$(sudo docker inspect $db_container_name | grep '"IPAddress": "1' | tr -d  '", ' | cut -d ':' -f2)
wordpress_ip=$(sudo docker inspect $wp_container_name | grep '"IPAddress": "1' | tr -d  '", ' | cut -d ':' -f2)
echo "============================================="
echo "|     Container      |      IP Address      |"
echo "---------------------------------------------"
echo "|		$wp_container_name	   |     $wordpress_ip    		  |"
echo "---------------------------------------------"
echo "|  $db_container_name		   |    $database_ip           	  |"
echo "---------------------------------------------"
echo "|	$web_container_name		   |	$web_ip 		  |"
echo "============================================="
if [[ -z "$wordpress_ip" || -z "$database_ip" || -z "$web_ip" ]];
then
	exit 1
else
	echo "Go to this IP $web_ip or address of this system and go to your browser and check it out"
fi