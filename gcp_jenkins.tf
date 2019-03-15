variable "region" {
  default = "europe-west1-d"
}

provider "google" {
  credentials = "${file("gcp.json")}"
  project     = "probproject"
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
  machine_type = "f1-micro"
  zone         = "${var.region}"

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
sudo systemctl enable jenkins
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
chmod +x /etc/profile.d/maven.sh
#load the environment variables
source /etc/profile.d/maven.sh
SCRIPT

  metadata {
    sshKeys = ""
  }
}
output "public_ip" {
  value = ["${google_compute_instance.test.*.network_interface.0.access_config.0.nat_ip}"]
}



