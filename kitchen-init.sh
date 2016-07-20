#!/bin/bash

# Script to add Kitchen configuration to existing formulas.
# usage:
# curl -skL "https://git.tcpcloud.eu/cookiecutter-templates/cookiecutter-salt-formula/raw/master/kitchen-init.sh" | bash -s --


# CONFIG
###################################

export driver=${driver:-vagrant}      # vagrant, dokken, openstack, ...
export verifier=${verifier:-inspec}   # serverspec, pester

export formula=${formula:-$(awk -F: '/^name/{gsub(/[\ \"]/,"");print $2}' metadata.yml)}
export suites=$(ls tests/pillar|xargs -i{} basename {} .sls)

export SOURCE_REPO_URI="https://git.tcpcloud.eu/cookiecutter-templates/cookiecutter-salt-formula/raw/master/%7B%7Bcookiecutter.project_name%7D%7D"

which envtpl &> /dev/null|| pip3 install envtpl

# INIT
###################################
test ! -e .kitchen.yml || {
  kitchen init -D kitchen-docker -P kitchen-salt --no-create-gemfile
  echo .kitchen >> .gitignore
  rm -rf test
  rm -f .kitchen.yml
  rm -f chefignore
}


# CONFIGURE & SCAFFOLD TEST DIR
###################################
test -d tests/integration || {
  for suite in $SUITES; do
    mkdir -p tests/integration/$suite/$VERIFIER
  done
  mkdir -p tests/integration/helpers/$VERIFIER/
  touch $_/spec_helper.rb
}


# .KITCHEN.YML
###################################

test -e .kitchen.yml || \
envtpl < <(curl -skL  "${SOURCE_REPO_URI}/.kitchen.yml" -- | sed 's/cookiecutter\.kitchen_//g') > .kitchen.yml

[[ "$DRIVER" != "docker" ]] && {
  test -e .kitchen.docker.yml || \
  envtpl < <(curl -skL  "${SOURCE_REPO_URI}/.kitchen.yml" -- | sed 's/cookiecutter\.kitchen_//g' | head -n12 ) > .kitchen.docker.yml
}

test -e .kitchen.openstack.yml || \
envtpl < <(curl -skL  "${SOURCE_REPO_URI}/.kitchen.openstack.yml" -- | sed 's/cookiecutter\.kitchen_//g') > .kitchen.openstack.yml



# UPDATE README, etc...
###################################

grep -Eoq 'Development and testing' README.* || {

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
	
	 # list instances and status
	 kitchen list
	
	 # manually execute integration tests
	 kitchen [test || [create|converge|verify|exec|login|destroy|...]] [instance] -t tests/integration
	
	 # use with provided Makefile (ie: within CI pipeline)
	 make kitchen
	
EOF
}

test -e INTEGRATION.rst || \
curl -skL  "${SOURCE_REPO_URI}/INTEGRATION.rst" -o INTEGRATION.rst


# ADD CHANGES TO GIT
###################################

# update Makefile, but do not auto-add to git
curl -skL  "${SOURCE_REPO_URI}/Makefile" -o Makefile

git add \
  .gitignore \
  .kitchen*yml \
  INTEGRATION.rst \
  README.rst

git status
