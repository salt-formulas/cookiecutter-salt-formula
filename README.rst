cookiecutter-salt-formula
=========================

A cookiecutter_ template for Salt Formula.

Usage
============

.. code-block:: bash

    cookiecutter cookiecutter-salt-formula


Init Kitchen CI
===============

Install prerequisites. 
- `envtpl` is renders jinja2 templates on the command line with shell environment variables.
- gems required dpends on driver configured to be used (docker by default)

.. code-block:: bash

    pip install cookiecutter
    pip install envtpl
    gem install kitchen-docker kitchen-vagrant kitchen-salt kitchen-openstack kitchen-inspec busser-serverspec

Once you create your `tests/pillar` structure (required if you want to auto populate kitchen test suites)

.. code-block:: bash

    pip install envtpl
    ./kitchen-init.sh

Instantly for latest version or on existing formulas:

.. code-block:: bash

    curl -skL "https://raw.githubusercontent.com/tcpcloud/cookiecutter-salt-formula/master/kitchen-init.sh" | bash -s --
