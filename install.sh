# Run all commands logged in as root or "sudo su - "
# Start from a base Debian 10 install and update it to current.
# Add backports repo so that we can install odbc-mariadb.

echo deb http://ftp.us.debian.org/debian/ buster-backports main > /etc/apt/sources.list.d/backports.list
echo deb-src http://ftp.us.debian.org/debian/ buster-backports main >> /etc/apt/sources.list.d/backports.list
apt-get update
apt-get upgrade

# Install all prerequisite packages

apt-get install -y build-essential linux-headers-`uname -r` openssh-server apache2 mariadb-server  mariadb-client bison flex php php-curl php-cli php-pdo php-mysql php-pear php-gd php-mbstring php-intl php-bcmath curl sox libncurses5-dev libssl-dev mpg123 libxml2-dev libnewt-dev sqlite3  libsqlite3-dev pkg-config automake libtool autoconf git unixodbc-dev uuid uuid-dev  libasound2-dev libogg-dev libvorbis-dev libicu-dev libcurl4-openssl-dev libical-dev libneon27-dev libsrtp2-dev libspandsp-dev sudo subversion libtool-bin python-dev unixodbc dirmngr sendmail-bin sendmail asterisk debhelper-compat cmake libmariadb-dev odbc-mariadb php-ldap

# Install Node.js
  
curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install this pear module

pear install Console_Getopt

# Prepare asterisk

systemctl stop asterisk
systemctl disable asterisk

cd /etc/asterisk
mkdir DIST
mv * DIST
cp DIST/asterisk.conf .
sed -i 's/(!)//' asterisk.conf
touch modules.conf
touch cdr.conf

# Configure Apache

sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.3/apache2/php.ini 
sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.3/apache2/php.ini
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
a2enmod rewrite
service apache2 restart
rm /var/www/html/index.html

# Configure odbc

cat <<EOF > /etc/odbcinst.ini
[MySQL]
Description = ODBC for MySQL (MariaDB)
Driver = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
FileUsage = 1
EOF

cat <<EOF > /etc/odbc.ini
[MySQL-asteriskcdrdb]
Description = MySQL connection to 'asteriskcdrdb' database
Driver = MySQL
Server = localhost
Database = asteriskcdrdb
Port = 3306
Socket = /var/run/mysqld/mysqld.sock
Option = 3
EOF

# Download ffmpeg static build for sound file manipulation

cd /usr/local/src
wget "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
tar xf ffmpeg-release-amd64-static.tar.xz
cd ffmpeg-4*
mv ffmpeg /usr/local/bin

# Finally we get to install FreePBX

cd /usr/local/src
wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-15.0-latest.tgz
tar zxvf freepbx-15.0-latest.tgz 
cd /usr/local/src/freepbx/
./start_asterisk start
./install -n

# Get the rest of the modules
fwconsole ma installall

# Uninstall digium_phones module, broken with PHP 7.3
fwconsole ma uninstall digium_phones

# Reload to apply config so far
fwconsole r

# Use the sound files freepbx installed instead of the sound files from the Debian repo

cd /usr/share/asterisk
mv sounds sounds-DIST
ln -s /var/lib/asterisk/sounds sounds

# Need to restart in order to load Asterisk modules that weren't configured yet

fwconsole restart

# Set up systemd startup script

cat <<EOF > /etc/systemd/system/freepbx.service
[Unit]
Description=FreePBX VoIP Server
After=mariadb.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/fwconsole start -q
ExecStop=/usr/sbin/fwconsole stop -q
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable freepbx

# Asterisk and FreePBX 15 are installed! Go to the web interface at http://YOUR-IP to finish setup.