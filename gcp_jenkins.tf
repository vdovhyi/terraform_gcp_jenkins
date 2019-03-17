
provider "google" {
  credentials = "${file(".ssh/gcp.json")}"
  project     = "${var.project_name}"
  region      = "${var.region}"
}

resource "google_compute_firewall" "tcp-firewall-rule-8080" {
  name = "tcp-firewall-rule-8080"
  network = "default"

  allow {
    protocol = "tcp"
    ports = ["8080"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "test" {
  name         = "test"
  machine_type = "g1-small"
  zone         = "${var.zone}"

  boot_disk {
    initialize_params {
      image = "centos-7-v20190312"
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP - leaving this block empty will generate a new external IP and assign it to the machine
    }
  }
  metadata_startup_script = <<SCRIPT
yum update -y
yum install -y mc nano wget
#install java amazon corretto JDK and JRE
wget https://d1f2yzg3dx5xke.cloudfront.net/java-1.8.0-amazon-corretto-devel-1.8.0_202.b08-1.amzn2.x86_64.rpm
wget https://d1f2yzg3dx5xke.cloudfront.net/java-1.8.0-amazon-corretto-1.8.0_202.b08-1.amzn2.x86_64.rpm
yum localinstall -y java-1.8.0-amazon-corretto*.rpm
#enable the Jenkins repository
curl --silent --location http://pkg.jenkins-ci.org/redhat-stable/jenkins.repo | sudo tee /etc/yum.repos.d/jenkins.repo
#add the repository to system
rpm --import https://jenkins-ci.org/redhat/jenkins-ci.org.key
#install the latest stable version of Jenkins
yum install -y jenkins
#start the Jenkins service
systemctl start jenkins
#enable the Jenkins service to start on system boot
systemctl enable jenkins
#install maven
yum install maven -y
#download maven latest version
wget https://www-us.apache.org/dist/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz -P /tmp
#Extract maven
tar xf /tmp/apache-maven-3.6.0-bin.tar.gz -C /opt
#create a symbolic link maven which will point to the Maven installation directory
ln -s /opt/apache-maven-3.6.0 /opt/maven
#setup the environment variables
cat <<EOF | tee -a /etc/profile.d/maven.sh
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-amazon-corretto.x86_64/jre
export M2_HOME=/opt/maven
export MAVEN_HOME=/opt/maven
export PATH=$${M2_HOME}/bin:$${PATH}
EOF
#
chmod +x /etc/profile.d/maven.sh
#load the environment variables
source /etc/profile.d/maven.sh
########################################################################################
jusername="User"
juserpassword="userpass"
juseremail="bbb@bbb.bbb"
key=`cat /var/lib/jenkins/secrets/initialAdminPassword`
# wait for jenkins start up
response=""
while [ `echo $$response | grep 'Authenticated' | wc -l` = 0 ]; do
  echo "Jenkins not started, wait for 2s"
  response=`java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s \
  http://localhost:8080 who-am-i --username admin --password $$key`
  echo $$response
  sleep 2
done
#install plugins
java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s \
http://localhost:8080/ -auth admin:$$key -noKeyAuth install-plugin \
dashboard-view cloudbees-folder antisamy-markup-formatter build-name-setter build-timeout config-file-provider credentials-binding embeddable-build-status rebuild ssh-agent throttle-concurrents timestamper ws-cleanup ant gradle msbuild nodejs checkstyle cobertura htmlpublisher junit warnings xunit workflow-aggregator github-organization-folder pipeline-stage-view build-pipeline-plugin conditional-buildstep jenkins-multijob-plugin parameterized-trigger copyartifact bitbucket clearcase cvs git git-parameter github gitlab-plugin p4 repo subversion teamconcert tfs matrix-project ssh-slaves windows-slaves matrix-auth pam-auth ldap role-strategy active-directory email-ext emailext-template mailer publish-over-ssh ssh -restart
#create groovy script
cat <<EOF | tee -a ~/user-creation.groovy
#!groovy
import jenkins.model.*
import hudson.security.*
import jenkins.install.InstallState
import hudson.tasks.Mailer

def instance = Jenkins.getInstance()
def username = args[0]
def userpassword = args[1]
def useremail = args[2]

println "--> Creating Local User"
def user = instance.getSecurityRealm().createAccount(username, userpassword)
user.addProperty(new Mailer.UserProperty(useremail))
user.save()

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

if (!instance.installState.isSetupComplete()) {
  println '--> Disable SetupWizard'
  InstallState.INITIAL_SETUP_COMPLETED.initializeState()
}
instance.save()
EOF
# wait for jenkins start up
response=""
while [ `echo $$response | grep 'Authenticated' | wc -l` = 0 ]; do
  echo "Jenkins not started, wait for 2s"
  response=`java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s \
  http://localhost:8080 who-am-i --username admin --password $$key`
  echo $$response
  sleep 2
done
#creating local user and disable installation wizard
java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s \
http://localhost:8080/ -auth admin:$$key groovy = \
< ~/user-creation.groovy $$jusername $$juserpassword $$juseremail

# restart jenkins
java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s \
http://localhost:8080/ -auth admin:$$key safe-restart
SCRIPT

  metadata {
    sshKeys = ""
  }
}
