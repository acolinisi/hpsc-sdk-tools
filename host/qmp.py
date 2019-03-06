#!/usr/bin/python

import sys
import telnetlib as tn
import json
#import pprint
import argparse

parser = argparse.ArgumentParser(
    description="Generate assembly source for vector table")
parser.add_argument('host',
    help='Qemu QMP Telnet server hostname')
parser.add_argument('port', type=int,
    help='Qemu QMP Telnet server port')
parser.add_argument('cmd',
    help='Command to execute')
parser.add_argument('args', nargs="*",
    help='Arguments to the command')
parser.add_argument('--quiet', '-q', action='store_true',
    help='Do not print any diagnostic information, only the output')
args = parser.parse_args()

cl = tn.Telnet(args.host, args.port)

reply = cl.read_until("\r\n")

cl.write('{"execute": "qmp_capabilities"}')
reply = cl.read_until("\r\n")

req = '{"execute": "%s"}' % args.cmd
if not args.quiet:
    print req
cl.write(req)
reply = cl.read_until("\r\n")

if not args.quiet:
    print reply

if args.cmd == "query-chardev":
    reply_json = json.loads(reply)
    cdevs = reply_json[u"return"]

    fnames = {}
    for cdev in cdevs:
            fnames[cdev[u"label"]] = cdev[u"filename"]
    #pprint.pprint(fnames)

    for label in args.args:
            fname = fnames[label]
            fname = fname.replace(u"pty:", u"")
            print(fname),
elif args.cmd == "cont":
    pass # nothing to do
else:
    raise Exception('unknown command: %s' % args.cmd);
