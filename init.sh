#!/bin/sh



TMPDIR=$(mktemp -d)

trap "echo \"deleting tmp dir ${TMPDIR}\" && rm -rf ${TMPDIR}" EXIT
trap "exit 1" INT

install_packages(){
  echo "install unzip git openssh-client ansible curl"
  sudo apt install -qqq -y unzip git openssh-client ansible curl
}


install_bitwarden_client(){
  if bw -v > /dev/null 2>&1; then
    echo "bitwarden client already exists"
  else
    echo "install bitwarden client"
    local PREV_DIR=$(pwd)
    cd $TMPDIR
    mkdir -p /usr/local/bin && \
    curl -o bw.zip -L 'https://vault.bitwarden.com/download/?app=cli&platform=linux' && \
    unzip bw.zip
    sudo install -o root -g root -m 0755 ./bw /usr/local/bin/bw
    cd ${PREV_DIR}
  fi
  bw -v > /dev/null
}

retrieve_bw_files(){
  if (test -f $HOME/.config/rclone/rclone.conf); then
    echo "rclone.conf already exists"
  else 
  (
    set -e
    echo "bitwarden login"
    bwsession=$(bw login --raw)
    echo "retrieve rclone config"
    mkdir -p $HOME/.config/rclone
    bw --session ${bwsession} get notes ee4ad0b0-9290-420e-a187-afca0168ede0 > $HOME/.config/rclone/rclone.conf
    bw logout
    chmod 600 $HOME/.config/rclone/rclone.conf
  )
  fi
}

ansible_os_provisioning(){
  echo "git clone debian-provisioning config repo"
  local PREV_DIR=$(pwd)
  cd ${TMPDIR}
  git clone -q https://github.com/thomas-hugon/debian-provisioning.git
  cd debian-provisioning
  echo "launch global ansible configuration playbook"
  ansible-galaxy collection install -r requirements.yml
  ansible-playbook -v --ask-become-pass  playbooks/new_install.yml
  cd ${PREV_DIR}
}


ansible_additional(){
  local PREV_DIR=$(pwd)
  cd $XDG_DOCUMENTS_DIR/provisioning
  echo "launch private ansible playbook"
  if test -f requirements.yml; then
    ansible-galaxy collection install -r requirements.yml
  fi
  if test -f additional.yml; then
    ansible-playbook -v --ask-become-pass additional.yml
  fi
  cd ${PREV_DIR}
}

. $HOME/.config/user-dirs.dirs && \
install_packages && \
install_bitwarden_client && \
retrieve_bw_files && \
ansible_os_provisioning && \
ansible_additional

