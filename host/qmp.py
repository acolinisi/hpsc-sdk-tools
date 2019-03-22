#!/usr/bin/python

import sys
import telnetlib as tn
import json
#import pprint
import argparse

parser = argparse.ArgumentParser(
    description="Interact with Qemu via the QMP interface")
parser.add_argument('host',
    help='Qemu QMP Telnet server hostname')
parser.add_argument('port', type=int,
    help='Qemu QMP Telnet server port')
parser.add_argument('cmd',
    help='Command to execute')
parser.add_argument('args', nargs="*",
    help='Arguments to the command (name=value, where value is quoted for string type)')
parser.add_argument('--quiet', '-q', action='store_true',
    help='Do not print any diagnostic information, only the output')
args = parser.parse_args()

cl = tn.Telnet(args.host, args.port)

reply = cl.read_until("\r\n")

cl.write('{"execute": "qmp_capabilities"}')
reply = cl.read_until("\r\n")

arg_str = ""
for arg in args.args:
    key, val = arg.split('=')

    # JSON does not support hex, but let's support it here
    if val.startswith("0x"):
        val = str(int(val, 16))

    if len(arg_str) > 0:
        arg_str += ",\n"
    arg_str += '        "%s": %s' % (key, val)

req = """
{
    "execute": "%s",
    "arguments": {
%s
    }
}
""" % (args.cmd, arg_str)

if not args.quiet:
    print req
cl.write(req)
reply = cl.read_until("\r\n")

print reply
