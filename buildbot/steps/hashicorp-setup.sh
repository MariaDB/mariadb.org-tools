########################################################################
# Hashicorp vault configuration on Linux
########################################################################

. /etc/os-release
linux=${ID}
if [ "${linux}" == "rocky" ] || [ "${linux}" == "centos" ]  ; then
  linux=rhel
fi

if [ "${linux}" == "debian" ] || [ "${linux}" == "ubuntu" ] ; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo sh -c "echo \"deb [arch=i386,amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list"
  # does not work on Sid
  #  sudo apt-add-repository "deb [arch=i386,amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update && sudo apt-get install vault
elif [ "${linux}" == "rhel" ] ; then
  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  sudo yum -y install vault
else
  echo "WARNING: Don't know how to install vault on ${linux}, skipping hashicorp tests"
  exit 0
fi

if which vault ; then
  cat << EOF > /tmp/vault.hcl
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://127.0.0.1:8200"

max_lease_ttl = "730h"
default_lease_ttl = "730h"
max_versions=2
ui = true
log_level = "Trace"
EOF

  sudo cp /tmp/vault.hcl /etc/vault.d/
  export VAULT_ADDR='http://127.0.0.1:8200'
  sudo systemctl restart vault
  # restart exits too early, vault may be not ready yet
  for i in 1 2 3 4 5 ; do
    sleep 2
    if vault operator init > /tmp/vault.init ; then
      break
    fi
  done

  vault operator unseal `grep 'Unseal Key 1:' /tmp/vault.init | awk '{ print $4 }'`
  vault operator unseal `grep 'Unseal Key 2:' /tmp/vault.init | awk '{ print $4 }'`
  vault operator unseal `grep 'Unseal Key 3:' /tmp/vault.init | awk '{ print $4 }'`
  export VAULT_TOKEN=`grep 'Initial Root Token:' /tmp/vault.init | awk '{ print $4 }'`
  vault login $VAULT_TOKEN
fi
