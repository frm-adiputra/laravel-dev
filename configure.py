#!/usr/bin/env python
#
# Copyright 2001 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Script that generates the build.ninja for ninja itself.

Projects that use ninja themselves should either write a similar script
or use a meta-build system that supports Ninja output."""

from __future__ import print_function

from optparse import OptionParser
import os
import pipes
import string
import subprocess
import sys

sys.path.insert(0, 'builder')
import ninja_syntax

def template(filename):
    return os.path.join('builder','templates', filename)
def built(filename):
    return os.path.join('$builddir', filename)
def compose_file(filename):
    return os.path.join('builder', 'compose', filename)
def dockerfile(filename):
    return os.path.join('docker', filename, 'Dockerfile')
def container(name):
    return os.getenv('BASENAME') + '_' + os.getenv('PROJECT') + '-' + name

DOCKERFILES=[
    dockerfile('web')
]

DOCKER_IMAGES = [
    'mariadb:10.1',
    'nazarpc/phpmyadmin',
    'busybox',
    'frma/baseimage-composer'
]

COMPOSE_BIN = '${builddir}/bin/docker-compose'
PROJECT_SRC = os.path.join('src', os.getenv('PROJECT'))

SERVICES_COMPOSE_FILES=[
	compose_file('services.yml'),
	compose_file('volumes.yml'),
	compose_file('names.yml'),
	compose_file('env-dev.yml')
]

SERVICES=[
	'db',
	'db-admin',
	'web'
]

VOLUMES=['db-volume', ]

BUILD_FILENAME = 'build.ninja'



ninja_writer = ninja_syntax.Writer(open(BUILD_FILENAME, 'w'))
n = ninja_writer

n.comment('This file is used to build ninja itself.')
n.comment('It is generated by ' + os.path.basename(__file__) + '.')
n.newline()

n.variable('ninja_required_version', '1.6')
n.variable('docker_compose_required_version', '1.5.2')
n.newline()

n.variable('builddir', os.getenv('BUILDDIR'))
n.newline()

n.variable('project', os.getenv('PROJECT'))
n.newline()

n.comment('Regenerate build files if build script changes.')
n.rule('configure',
        command='${configure_env}python configure.py ${configure_args}',
        generator=True)
n.build(BUILD_FILENAME, 'configure',
        implicit=['configure.py', os.path.normpath('builder/ninja_syntax.py'), 'my-config', 'builder/build-env'])
n.newline()

n.rule('mo',
        command='./builder/bin/mo ${in} > ${out}',
        description='generating ${in} > ${out}')
n.newline()

n.rule('curl',
        command='curl ${curl_flags} ${url} > ${out}',
        pool='console')
n.newline()

n.rule('compose_up',
        command='docker-compose --project-name ${project} ${compose_files} up ${compose_up_flags} ${compose_up_services}',
        pool='console',
        description='starting services ${compose_up_services}')
n.newline()

n.rule('compose_run',
        command='docker-compose --project-name ${project} ${compose_files} run ${compose_run_flags} ${compose_run_service} ${compose_run_cmd}',
        pool='console',
        description='run services ${compose_run_service} ${compose_run_cmd}')
n.newline()

n.rule('compose_stop',
        command='docker-compose --project-name ${project} ${compose_files} stop ${compose_stop_flags} ${compose_stop_services}',
        pool='console',
        description='stopping containers ${compose_stop_services}')
n.newline()

n.rule('compose_rm',
        command='docker-compose --project-name ${project} ${compose_files} rm ${compose_rm_flags} ${compose_rm_services}',
        pool='console',
        description='removing containers ${compose_rm_services}')
n.newline()

n.rule('init',
        command='docker-compose --project-name ${project} -f %s run --rm init || true && touch %s/.lastbuild' % (compose_file('init.yml'), PROJECT_SRC),
        pool='console',
        description='initializing')
n.newline()

n.rule('docker_pull',
        command='docker pull ${docker_image}',
        pool='console',
        description='pulling docker image ${docker_image}')
n.newline()

n.rule('docker_exec',
        command='docker exec -it ${docker_exec_container} ${docker_exec_command}',
        pool='console',
        description='execute command in container ${docker_exec_container} ${docker_exec_command}')
n.newline()

n.build(COMPOSE_BIN, 'curl',
        variables=[('url', 'https://github.com/docker/compose/releases/download/${docker_compose_required_version}/docker-compose-`uname -s`-`uname -m`'),
                    ('curl_flags', '-L')])
n.newline()

for t in DOCKER_IMAGES:
    n.build(t, 'docker_pull')
    n.newline()

for t in DOCKERFILES:
    n.build(built(t), 'mo', template(t), implicit=['my-config', 'builder/build-env', 'run', 'builder/bin/mo'])
    n.newline()

n.build('update-images', 'phony', DOCKER_IMAGES)
n.newline()

n.build(PROJECT_SRC, 'init',
        implicit=[compose_file('init.yml')])
n.newline()

n.build('start', 'compose_up', [COMPOSE_BIN] + [built(v) for v in DOCKERFILES] + [PROJECT_SRC, 'volumes'],
        implicit=SERVICES_COMPOSE_FILES,
        variables=[
            ('compose_files', '-f '+ ' -f '.join(SERVICES_COMPOSE_FILES)),
            ('compose_up_flags', '--force-recreate'),
            ('compose_up_services', SERVICES)
        ])
n.newline()

n.build('volumes', 'compose_up',
        implicit=SERVICES_COMPOSE_FILES,
        variables=[
            ('compose_files', '-f '+ ' -f '.join(SERVICES_COMPOSE_FILES)),
            ('compose_up_services', " ".join(VOLUMES))
        ])
n.newline()

n.build('app-shell', 'docker_exec',
        variables=[
            ('docker_exec_container', container('web')),
            ('docker_exec_command', 'bash'),
        ])
n.newline()

n.build('db-shell', 'docker_exec',
        variables=[
            ('docker_exec_container', container('db')),
            ('docker_exec_command', 'bash'),
        ])
n.newline()

n.build('mysql-shell', 'docker_exec',
        variables=[
            ('docker_exec_container', container('db')),
            ('docker_exec_command', 'mysql -u root -p$${MYSQL_ROOT_PASSWORD} $${MYSQL_DATABASE}'),
        ])
n.newline()

n.build('rm-volumes', 'compose_rm',
        implicit=SERVICES_COMPOSE_FILES,
        variables=[
            ('compose_files', '-f '+ ' -f '.join(SERVICES_COMPOSE_FILES)),
            ('compose_rm_flags', '-v --force'),
            ('compose_rm_services', 'db-volume')
        ])
n.newline()

n.build('stop-containers', 'compose_stop',
        implicit=SERVICES_COMPOSE_FILES,
        variables=[
            ('compose_files', '-f '+ ' -f '.join(SERVICES_COMPOSE_FILES)),
            ('compose_stop_services', 'web db db-admin db-volume')
        ])
n.newline()

n.build('rm-containers', 'compose_rm', ['stop-containers'],
        implicit=SERVICES_COMPOSE_FILES,
        variables=[
            ('compose_files', '-f '+ ' -f '.join(SERVICES_COMPOSE_FILES)),
            ('compose_rm_flags', '-v --force'),
            ('compose_rm_services', 'web db db-admin db-volume')
        ])
n.newline()

n.default('start')
n.newline()