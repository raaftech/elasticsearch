#!/usr/bin/env python

# Load modules
from __future__ import print_function
from argparse import ArgumentParser
from base64 import b64encode
from ConfigParser import ConfigParser
from os.path import expanduser,isfile,sep
from ssl import create_default_context, CERT_NONE

try:
    # For Python 3.0 and later..
    from urllib.request import Request, urlopen
except ImportError:
    # Fall back to Python 2's urllib2.
    from urllib2 import Request, urlopen

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
    url = conf.get('elasticsearch', 'baseurl')
    data = args.file.read()

    username = conf.get('elasticsearch', 'user')
    password = conf.get('elasticsearch', 'pass')

    req =  Request(url, data)
    req.add_header("Authorization", "Basic %s" % b64encode('%s:%s' % (username, password)))
    req.add_header('Content-Type', 'text/xml')


    # Disable SSL/TLS certificate validation.
    context = create_default_context()
    context.check_hostname = False
    context.verify_mode = CERT_NONE

    res = urlopen(url=req, context=context).read()


    print(res)

else:
    parser.print_help()


