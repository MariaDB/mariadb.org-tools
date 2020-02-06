from __future__ import absolute_import
from __future__ import print_function

import os

from buildbot.process.results import statusToString
from flask import Flask
from flask import render_template

griddashboardapp = Flask('grid', root_path=os.path.dirname(__file__))
# this allows to work on the template without having to restart Buildbot
griddashboardapp.config['TEMPLATES_AUTO_RELOAD'] = True

@griddashboardapp.route("/index.html")
def main():
    # This code fetches build data from the data api, and give it to the template
    builders = griddashboardapp.buildbot_api.dataGet("/builders")

    # request last 20 builds
    builds = griddashboardapp.buildbot_api.dataGet("/builds", order=["-buildid"], limit=20)

    used_builders = list(map(lambda x: x['builderid'], builds))
    builders = list(filter(lambda x: x['builderid'] in used_builders, builders))

    # to store all revisions from builds above
    revisions = []

    # properties are actually not used in the template example, but this is how you get more properties
    for build in builds:
        build['properties'] = griddashboardapp.buildbot_api.dataGet(("builds", build['buildid'], "properties"))
        build['results_text'] = statusToString(build['results']) # translate result to string
        build['state'] = griddashboardapp.buildbot_api.dataGet(
                ("builds", build['buildid']))

        try:
            if build["properties"]["revision"][0] not in revisions:
                revisions.append(build["properties"]["revision"][0])
        except KeyError as e:
            # this means the build didn't get to the point of getting a revision,
            # more than likely an environment isssue such as disk full, power outtage, etc...
            print('Error', str(e))
            pass

    # would like to display newest first
    revisions.sort(reverse=True)
    print(revisions, builds)

    # grid.html is a template inside the template directory
    return render_template('grid.html', builders=builders, builds=builds,
                           revisions=revisions)

# Here we assume c['www']['plugins'] has already be created earlier.
# Please see the web server documentation to understand how to configure
# the other parts.
c['www']['plugins']['wsgi_dashboards'].append({
        'name': 'custom',  # as used in URLs
        'caption': 'Custom',  # Title displayed in the UI'
        'app': griddashboardapp,
        # priority of the dashboard in the left menu (lower is higher in the
        # menu)
        'order': 15,
        # available icon list can be found at http://fontawesome.io/icons/
        'icon': 'share-alt-square'
    })

