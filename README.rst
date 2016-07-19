cookiecutter-salt-formula
=========================

A cookiecutter_ template for Salt Formula.

Installation
============

.. code-block:: bash

    pip install cookiecutter

    cookiecutter cookiecutter-salt-formula


Init Kitchen CI
===============

Install prerequisite (Render jinja2 templates on the command line with shell environment variables)

.. code-block:: bash

    pip install envtpl

Once you create your `tests/pillar` structure (required if you want to auto populate kitchen test suites)

.. code-block:: bash

    pip install envtpl
    ./kitchen-init.sh

Instantly for latest version or on existing formulas:

.. code-block:: bash

    curl -sL "https://git.tcpcloud.eu/cookiecutter-templates/cookiecutter-salt-formula/raw/master/kitchen-init.sh" | bash -s --
