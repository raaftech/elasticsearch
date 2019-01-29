#!/usr/bin/env python

# Load modules
from __future__ import print_function
from argparse import ArgumentParser
from base64 import b64encode
from ConfigParser import ConfigParser
from os.path import expanduser,isfile,sep
from ssl import create_default_context, CERT_NONE
from urllib2 import Request, urlopen
from xml.dom.minidom import parseString

# Version.
version="Elasticsearch Request Runner 0.1."

# Load configuration.
ini = expanduser("~") + sep + '.elasticsearch.ini'
conf = ConfigParser()
if isfile(ini):
    conf.read(ini)
else:
    print('Error: cannot find configuration file')
    print('Expected to find ' + ini)

# Create an argument parser object.
parser = ArgumentParser(description='Elasticsearch Request Runner.')
parser.add_argument('-b', '--body', action='store', type=file, help='specify the file containing the request body')
parser.add_argument('-m', '--method', action='store', help='specify the file containing the request body')
parser.add_argument('-p', '--path', action='store', help='specify the path to send the request to')
parser.add_argument('-v', '--version', action='version', version=version)

args = parser.parse_args()

if args.file:
    url = conf.get('soap', 'gtin_service')
    data = args.file.read()

    username = conf.get('soap', 'user')
    password = conf.get('soap', 'pass')

    req =  Request(url, data)
    req.add_header("Authorization", "Basic %s" % b64encode('%s:%s' % (username, password)))
    req.add_header('Content-Type', 'text/xml')


    # Disable SSL/TLS certificate validation.
    context = create_default_context()
    context.check_hostname = False
    context.verify_mode = CERT_NONE

    res = urlopen(url=req, context=context).read()


    print(parseString(res).toprettyxml(encoding='utf8'))

else:
    parser.print_help()


