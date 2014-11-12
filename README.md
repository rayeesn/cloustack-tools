cloustack-tools
===============

This is repository to keep cloudstack tools for deployment and automation 



#This scripts help you setup build environment and run simulator test  in new RHEL 6.5 machine

# 1 Configure repository

touch /etc/yum.repos.d/rhel6.repo
chmod 777 /etc/yum.repos.d/rhel6.repo
echo [rhel] >>  /etc/yum.repos.d/rhel6.repo
echo name=rhel6 >> /etc/yum.repos.d/rhel6.repo
echo baseurl=http://10.220.0.11/vol/xenrtdata/linux/distros/CentOS/6.5/x86_64/ >> /etc/yum.repos.d/rhel6.repo
echo enabled=1 >> /etc/yum.repos.d/rhel6.repo
echo gpgcheck=0 >> /etc/yum.repos.d/rhel6.repo

# 2 Update host file to get fqdn, else SMTP test cases will fail
IP=$(/sbin/ifconfig | grep -e "inet:" -e "addr:" | grep -v "inet6" | grep -v "127.0.0.1" | head -n 1 | awk '{print $2}' | cut -c6-)
echo $IP centos65 >> /etc/hosts

# 3 Install Git  and Maven
yum install git -y
cd /tmp
wget http://mirrors.sonic.net/apache/maven/maven-3/3.2.3/binaries/apache-maven-3.2.3-bin.tar.gz
tar -xvf apache-maven-3.2.3-bin.tar.gz
cp -r apache-maven-3.2.3 /usr/local/
cd /tmp
wget http://nfs1.lab.vmops.com/softwares/java/jdk-7u60-linux-x64.rpm
# You need to download and keep in your local fileserver path
rpm -ivh jdk*
yum install libICE-devel libSM-devel libX11-devel libXp-devel libXt-devel libXtst-devel libXext-devel -y
yum groupinstall "Development tools" -y
yum install java-1.7*openjdk* tomcat6 ws-commons-util MySQL-python mkisofs createrepo -y

# 4 Mysql
yum install mysql-server mysql php-mysql -y
service mysqld start


# 5 Configure Python 2.7
mkdir -p /data/python
wget http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tar.xz
yum install xz-libs -y
yum install bzip2-devel mercurial ncurses-devel openssl-devel python-argparse python-tools python-setuptools readline-devel sqlite-devel tk-devel zlib-devel -y
xz -d Python-2.7.6.tar.xz
tar -xvf Python-2.7.6.tar
cd Python-2.7.6

./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"
make && make altinstall


# 6 Configure Env
echo export M2_HOME=/usr/local/apache-maven-3.2.3 >> ~/.bashrc
echo export M2=/usr/local/apache-maven-3.2.3/bin >> ~/.bashrc
echo export PATH=/usr/local/apache-maven-3.2.3/bin:/data/python/Python-2.7.6:$PATH >> ~/.bashrc
echo export JAVA_HOME="/usr/lib/java/jdk1.6.0_24" >> ~/.bashrc
source ~/.bashrc


# 7 Configure Pip
# Let's download the installation file using wget:
mkdir /data/pip
cd /data/pip
wget --no-check-certificate https://pypi.python.org/packages/source/s/setuptools/setuptools-1.4.2.tar.gz

# Extract the files from the archive:
tar -xvf setuptools-1.4.2.tar.gz

# Enter the extracted directory:
cd setuptools-1.4.2

# Install setuptools using the Python we've installed (2.7.6)
python setup.py install

# Download the setup files for pip
curl https://raw.githubusercontent.com/pypa/pip/master/contrib/get-pip.py | python -

# 8 Configure Repo
cd /data
git clone https://git-wip-us.apache.org/repos/asf/cloudstack.git
cd cloudstack
git checkout -b 4.5


# 9 Build
mvn -Pawsapi,systemvm -Dsimulator clean install
mvn -P developer -pl :cloud-apidoc
mvn -P developer -pl :cloud-marvin
pip install --upgrade tools/marvin/dist/Marvin-*  --allow-external mysql-connector-python
mvn -Pdeveloper -pl developer -Ddeploydb
mvn -Pdeveloper -pl developer -Ddeploydb-simulator
mvn -Dsimulator -pl client jetty:run &


# 10 Simulator setup
yum install nc -y
IP=$(/sbin/ifconfig | grep -e "inet:" -e "addr:" | grep -v "inet6" | grep -v "127.0.0.1" | head -n 1 | awk '{print $2}' | cut -c6-)
./sim_zone.sh $IP 1



# https://ftp.dlitz.net/pub/dlitz/crypto/pycrypto/pycrypto-2.2.tar.gz
# https://pypi.python.org/packages/source/e/ecdsa/ecdsa-0.11.tar.gz


nosetests --with-xunit --xunit-file=$suite.xml --with-marvin --marvin-config=/data/sim.cfg.cfg -w /data/cloudstack/test/integration/smoke -a tags=advanced,simulator_only --zone=Zone1 --hypervisor=$hyp --collect-only

