#!/bin/bash

# usage:
# cd <formula repo>; ./kitchen_init.sh


# CONFIG

export DRIVER=${DRIVER:-vagrant}      # vagrant, dokken, openstack, ...
export VERIFIER=${VERIFIER:-inspec}  # serverspec, pester
export KITCHEN_YML=${KITCHEN_YML:-.kitchen.yml}

export FORMULA=${FORMULA:-$(awk -F: '/name/{gsub(/[\ \"]/,"");print $2}' metadata.yml)}
export SUITES=$(ls tests/pillar|xargs -I{} basename {} .sls)


# INIT

test ! -e .kitchen.yml || {
  kitchen init -D kitchen-docker -P kitchen-salt --no-create-gemfile
  echo .kitchen >> .gitignore
  rm -rf test
  rm -f .kitchen.yml
  rm -f chefignore
}

test -e INTEGRATION.rst || \
wget 'https://git.tcpcloud.eu/cookiecutter-templates/cookiecutter-salt-formula/raw/master/%7B%7Bcookiecutter.project_name%7D%7D/INTEGRATION.rst' -O INTEGRATION.rst 2>/dev/null

# CONFIGURE & SCAFFOLD TEST STRUCTURE

test -d tests/integration || {
  for suite in $SUITES; do
    mkdir -p tests/integration/$suite/$VERIFIER
  done
  mkdir -p tests/integration/helpers/$VERIFIER/
  touch $_/spec_helper.rb
}


# .KITCHEN.YML

cat > .kitchen.yml.jinja <<-EOF
	---
	driver:
	  name: $DRIVER
	{%- if DRIVER == 'docker' %}
	  hostname: $FORMULA.ci.local
	  use_sudo: false
	{%- elif DRIVER == 'vagrant' %}
	  vm_hostname: $FORMULA.ci.local
	  use_sudo: false
	  customize:
	    memory: 512
	{%- endif %}
	
	
	provisioner:
	  name: salt_solo
	  salt_install: bootstrap
	  salt_bootstrap_url: https://bootstrap.saltstack.com
	  salt_version: latest
	  formula: $FORMULA
	  log_level: info
	  state_top:
	    base:
	      "*":
	        - $FORMULA
	  pillars:
	    top.sls:
	      base:
	        "*":
	          - $FORMULA
	  grains:
	    noservices: {{ 'True' if DRIVER=='docker' else 'False' }}
	
	
	verifier:
	  name: $VERIFIER
	  sudo: true
	
	
	platforms:
	  - name: ubuntu-14.04
	  - name: ubuntu-16.04
	  - name: centos-7.1
	
	
	suites:
	  {%- if DRIVER == 'vagrant' %}
	  # Default suite, smoke test, setup prerequisites and executes run ./tests/run_tests.sh
	  - name: default
	    includes:
	      - ubuntu-16.04
	    driver:
	      name: local
	      provision_command:
	        - apt-get install -y git build-essential python-pip python-yaml python-dev python-virtualenv
	    provisioner:
	      name: shell
	      script: tests/bootstrap.sh
	
	  {%- endif %}
	  {%- for suite in SUITES.split() %}
	
	  - name: {{ suite }}
	    provisioner:
	      pillars-from-files:
	        $FORMULA.sls: tests/pillar/{{suite}}.sls
	  {%- endfor %}
	
	# vim: ft=yaml sw=2 ts=2 sts=2 tw=125
EOF

#FIXME, remove comment \{\% for name, value in environment('SUITE_') \%\}

which envtpl &> /dev/null|| pip3 install envtpl
envtpl < .kitchen.yml.jinja > .kitchen.yml

[[ "$DRIVER" != "docker" ]] && {
  test -e .kitchen.docker.yml || \
  DRIVER=docker envtpl < <(head -n12 .kitchen.yml.jinja) > .kitchen.docker.yml
}


test -e .kitchen.openstack.yml || \
cat > .kitchen.openstack.yml <<-\EOF
	# usage: `KITCHEN_LOCAL_YAML=.kitchen.openstack.yml kitchen test`

	# https://docs.chef.io/config_yml_kitchen.html
	# https://github.com/test-kitchen/kitchen-openstack

	---
	driver:
	  name: openstack
	  openstack_auth_url: <%= ENV['OS_AUTH_URL'] %>/tokens
	  openstack_username: <%= ENV['OS_USERNAME'] || 'ci' %>
	  openstack_api_key:  <%= ENV['OS_PASSWORD'] || 'ci' %>
	  openstack_tenant:   <%= ENV['OS_TENANT_NAME'] || 'ci_jenkins' %>

	  #floating_ip_pool: <%= ENV['OS_FLOATING_IP_POOL'] || 'nova' %>
	  key_name: <%= ENV['BOOTSTRAP_SSH_KEY_NAME'] || 'bootstrap_insecure' %>
	  private_key_path: <%= ENV['BOOTSTRAP_SSH_KEY_PATH'] || "#{ENV['HOME']}/.ssh/id_rsa_bootstrap_insecure" %>


	platforms:
	  - name: ubuntu-14.04
	    driver:
	      username: <%= ENV['OS_UBUNTU_IMAGE_USER'] || 'root' %>
	      image_ref: <%= ENV['OS_UBUNTU_IMAGE_REF'] || 'ubuntu-14-04-x64-1455869035' %>
	      flavor_ref: m1.medium
	      network_ref:
	        <% if ENV['OS_NETWORK_REF'] -%>
	        - <% ENV['OS_NETWORK_REF'] %>
	        <% else -%>
	        - ci-net
	        <% end -%>
	    # force update apt cache on the image
	    run_list:
	      - recipe[apt]
	    attributes:
	      apt:
	          compile_time_update: true
	transport:
	  username: <%= ENV['OS_UBUNTU_IMAGE_USER'] || 'root' %>

	# vim: ft=yaml sw=2 ts=2 sts=2 tw=125
EOF


# CLEANUP
rm -f .kitchen.yml.jinja


# ADD CHANGES TO GIT

git add \
  .gitignore \
  .kitchen*yml \
  INTEGRATION.rst



# UPDATE README

# skip if already updated
grep -Eoq 'Development and testing' README.* && exit 0

KITCHEN_LIST=$(kitchen list|tail -n+2)
cat >> README.* <<-\EOF

	Development and testing
	=======================
	
	Development and test workflow with `Test Kitchen <http://kitchen.ci>`_ and
	`kitchen-salt <https://github.com/simonmcc/kitchen-salt>`_ provisioner plugin.
	
	Test Kitchen is a test harness tool to execute your configured code on one or more platforms in isolation.
	There is a ``.kitchen.yml`` in main directory that defines *platforms* to be tested and *suites* to execute on them.
	
	Kitchen CI can spin instances locally or remote, based on used *driver*.
	For local development ``.kitchen.yml`` defines a `vagrant <https://github.com/test-kitchen/kitchen-vagrant>`_ or
	`docker  <https://github.com/test-kitchen/kitchen-docker>`_ driver.
	
	To use backend drivers or implement your CI follow the section `INTEGRATION.rst#Continuous Integration`__.
	
	A listing of scenarios to be executed:
	
	.. code-block:: shell
	
	  $ kitchen list
	
	  Instance                    Driver   Provisioner  Verifier  Transport  Last Action
	
EOF

echo "$KITCHEN_LIST" | sed 's/^/  /' >> README.*

cat >> README.* <<-\EOF
	
	The `Busser <https://github.com/test-kitchen/busser>`_ *Verifier* is used to setup and run tests
	implementated in `<repo>/test/integration`. It installs the particular driver to tested instance
	(`Serverspec <https://github.com/neillturner/kitchen-verifier-serverspec>`_,
	`InSpec <https://github.com/chef/kitchen-inspec>`_, Shell, Bats, ...) prior the verification is executed.
	
	
	Usage:
	
	.. code-block:: shell
	
	  # manually
	  kitchen [test || [create|converge|verify|exec|login|destroy|...]] -t tests/integration
	
	  # or with provided Makefile within CI pipeline
	  make kitchen
	
EOF

git add README.*
git status

echo "Note: Dont forget to add kitchen targets to 'Makefile'.
