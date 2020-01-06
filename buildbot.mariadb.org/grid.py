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

customapp = Flask('test', root_path=os.path.dirname(__file__))
# this allows to work on the template without having to restart Buildbot
customapp.config['TEMPLATES_AUTO_RELOAD'] = True


@customapp.route("/index.html")
def main():
# This code fetches build data from the data api, and give it to the
    # template
    builders = customapp.buildbot_api.dataGet("/builders")

    builds = customapp.buildbot_api.dataGet("/builds", order=['-buildid'], limit=100)
    
    used_builders = list(map(lambda x: x['builderid'], builds))
    builders = list(filter(lambda x: x['builderid'] in used_builders, builders))
    # properties are actually not used in the template example, but this is
    # how you get more properties
    for build in builds:
        build['properties'] = customapp.buildbot_api.dataGet(
            ("builds", build['buildid'], "properties"))
        build['state'] = customapp.buildbot_api.dataGet(
            ("builds", build['buildid']))

        build['results_text'] = statusToString(build['results'])

    graph_data = [
        {'x': 1, 'y': 100},
        {'x': 2, 'y': 200},
        {'x': 3, 'y': 300},
        {'x': 4, 'y': 0},
        {'x': 5, 'y': 100},
        {'x': 6, 'y': 200},
        {'x': 7, 'y': 300},
        {'x': 8, 'y': 0},
        {'x': 9, 'y': 100},
        {'x': 10, 'y': 200},
    ]
    # grid.html is a template inside the template directory
    return render_template('grid.html', builders=builders, builds=builds,
                           graph_data=graph_data)

# Here we assume c['www']['plugins'] has already be created earlier.
# Please see the web server documentation to understand how to configure
# the other parts.
c['www']['plugins']['wsgi_dashboards'].append({
        'name': 'custom',  # as used in URLs
        'caption': 'Custom',  # Title displayed in the UI'
        'app': customapp,
        # priority of the dashboard in the left menu (lower is higher in the
        # menu)
        'order': 15,
        # available icon list can be found at http://fontawesome.io/icons/
        'icon': 'share-alt-square'
    })

