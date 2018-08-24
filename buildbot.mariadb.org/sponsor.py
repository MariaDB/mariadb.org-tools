# -*- python -*-
# ex: set filetype=python:

from __future__ import absolute_import
from __future__ import print_function

import os
import time

import requests
from flask import Flask
from flask import render_template

from buildbot.process.results import statusToString

sponsorapp = Flask('test', root_path=os.path.dirname(__file__))
# this allows to work on the template without having to restart Buildbot
sponsorapp.config['TEMPLATES_AUTO_RELOAD'] = True


@sponsorapp.route("/index.html")
def main():
    # sponsor.html is a template inside the template directory
    return render_template('sponsor.html')

# Here we assume c['www']['plugins'] has already be created earlier.
# Please see the web server documentation to understand how to configure
# the other parts.
c['www']['plugins']['wsgi_dashboards'] = [  # This is a list of dashboards, you can create several
    {
        'name': 'sponsor',  # as used in URLs
        'caption': 'Sponsors',  # Title displayed in the UI'
        'app': sponsorapp,
        # priority of the dashboard in the left menu (lower is higher in the
        # menu)
        'order': 20,
        # available icon list can be found at http://fontawesome.io/icons/
        'icon': 'share-alt-square'
    }
]
