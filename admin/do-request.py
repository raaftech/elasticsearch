#!/usr/bin/env python

# Load modules
from __future__ import print_function
from argparse import Action,ArgumentParser,ArgumentTypeError
from base64 import b64encode
from ConfigParser import ConfigParser
from os import access,walk,R_OK
from os.path import expanduser,isdir,isfile,join,sep
from ssl import create_default_context, CERT_NONE
from sys import stderr

try:
    # For Python 3.0 and later..
    from urllib.request import Request, urlopen
except ImportError:
    # Fall back to Python 2's urllib2.
    from urllib2 import Request, urlopen

# Version.
version="Elasticsearch Request Runner 0.2."

# Load configuration.
ini = expanduser("~") + sep + '.elasticsearch.ini'
conf = ConfigParser()
if isfile(ini):
    conf.read(ini)
else:
    print('Error: cannot find configuration file')
    print('Expected to find ' + ini)

# Define a readable directory action.
class directory(Action):
    def __call__(self, parser, namespace, values, option_string=None):
        prospective_dir=values
        if not isdir(prospective_dir):
            raise ArgumentTypeError("directory:{0} is not a valid path".format(prospective_dir))
        if access(prospective_dir, R_OK):
            setattr(namespace,self.dest,prospective_dir)
        else:
            raise ArgumentTypeError("directory:{0} is not a readable dir".format(prospective_dir))

# Error printer.
def eprint(*args, **kwargs):
    print(*args, file=stderr, **kwargs)

# The call dispatcher.
def do_request(method, path, body, format):
    url = conf.get('elasticsearch', 'baseurl') + path
    data = body.read()

    username = conf.get('elasticsearch', 'user')
    password = conf.get('elasticsearch', 'pass')

    req =  Request(url, data)
    req.add_header("Authorization", "Basic %s" % b64encode('%s:%s' % (username, password)))

    if format == 'json' or format == 'JSON':
        req.add_header('Content-Type', 'application/json')
    elif format == 'xml' or format == 'XML':
        req.add_header('Content-Type', 'text/xml')
    else:
        req.add_header('Content-Type', 'text/plain')

    req.get_method = lambda: method

    # Disable SSL/TLS certificate validation.
    context = create_default_context()
    context.check_hostname = False
    context.verify_mode = CERT_NONE

    eprint('Invoking ' + method + ' with a ' + format + ' formatted body on ' + url )
    res = urlopen(url=req, context=context).read()
    print(res)

# Create an argument parser object.
parser = ArgumentParser(description='Elasticsearch Request Runner.')
parser.add_argument('-a', '--automated', action=directory, help='find all files in specified path recursively, where the directory name is the relative path, and the filename is formatted as follows: <nr>.<final_endpoint>.<method>.<format>. The requests are executed in numerical order, based on <nr>.')

parser.add_argument('-b', '--body', action='store', type=file, help='specify the file containing the request body')
parser.add_argument('-f', '--format', action='store', help='specify the format of the request body, either xml or json')
parser.add_argument('-m', '--method', action='store', help='specify the file containing the request body')
parser.add_argument('-p', '--path', action='store', help='specify the path to send the request to')
parser.add_argument('-v', '--version', action='version', version=version)

args = parser.parse_args()

if args.automated:
    requests=[]
    for root, dirs, files in walk(args.automated):
        for file in files:
            if file.endswith(".json") or file.endswith(".xml"):
                body = open(join(root, file), "r")
                path = root.split('.')[1]
                number = int(file.split('.')[0])
                final = file.split('.')[1]
                method = file.split('.')[2].upper()
                format = file.split('.')[3].upper()

                requests.append({'number':number, 'method':method, 'endpoint':path + '/' + final, 'format':format, 'body':body})

    for entry in sorted(requests, key=lambda k: k['number']) :
        do_request(entry['method'], entry['endpoint'], entry['body'], entry['format'])

elif args.body and args.format and args.method and args.path:
    do_request(args.method.upper(), args.path, args.body, args.format.upper())

else:
    eprint('error: Please specify either -a <directory>, or -b <body_text> -m <http_method> -p <relative_http_path>')
    parser.print_help()


