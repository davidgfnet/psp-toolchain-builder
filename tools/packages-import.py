#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, re, argparse, shutil

EXTRADEPS = "toolchain"
PKGDESCFN = "PSPBUILD"
PKGMANVARS = ["pkgname", "pkgver", "pkgrel", "pkgdesc", "arch"]

parser = argparse.ArgumentParser(prog='pkg-importer')
parser.add_argument('--input', dest='inputdir', required=True, help='Input directory (ie. the packages repo)')
parser.add_argument('--output', dest='outdir', required=True, help='Output directory where to place the files (will overwrite stuff)')
parser.add_argument('--group', dest='group', default=None, help='Group override, will overwrite any existing group info')
parser.add_argument('--extra-deps', dest='edeps', default=EXTRADEPS, help='Comma separated list of extra dependencies to add')
args = parser.parse_args()

edeps = args.edeps.split(",")

# Find all the package description files and inspect them.
pkgfiles = []
for root, dirs, files in os.walk(os.path.abspath(args.inputdir), topdown=False):
  for name in files:
    if name == PKGDESCFN:
      fn = os.path.join(root, name)
      pkgfiles.append(fn)

def find_varval(content, varname):
  for i, l in enumerate(content):
    if l.startswith(varname + "="):
      return l[len(varname) + 1:]
  return None

def find_vardef(content, varname):
  for i, l in enumerate(content):
    if l.startswith(varname + "="):
      return i
  return -1

def newvar_idx(content, varname):
  # Insert the variable right after the mandatory vars are defined.
  pvars = set(PKGMANVARS)
  for i, l in enumerate(content):
    vname = l.split("=")[0]
    if vname in pvars:
      pvars.remove(vname)

    if not pvars:
      return i + 1

  raise ValueError("Invalid pkgbuild file, missing some variables")

pkgdb = {}
for pkgf in pkgfiles:
  data = open(pkgf).read()
  content = data.split("\n")

  pkgvars = { v: find_varval(content, v) for v in PKGMANVARS }

  # Replace "groups" if so specified
  if args.group:
    value = "groups=('%s')" % args.group
    idx = find_vardef(content, "groups")
    if idx >= 0:
      content[idx] = value
    else:
      content.insert(newvar_idx(content, "groups"), value)

  # Find the "depends" variable, to add the "toolchain" dependency
  if edeps:
    idx = find_vardef(content, "depends")
    if idx >= 0:
      # Add the dependencies to the existing ones
      value = re.match(r"depends=\((.*)\)", content[idx])
      pdeps = [x.strip("'") for x in value.group(1).split(" ") if x]
      pdeps += edeps
      content[idx] = "depends=(%s)" % (" ".join("'%s'" % x for x in pdeps))
    else:
      content.insert(newvar_idx(content, "depends"), "depends=(%s)" % (" ".join("'%s'" % x for x in edeps)))

  # Parse all sources, see if there are any local files
  localfiles = []
  m = re.search(r"source=\((.*?)\)", data, re.DOTALL)
  if m:
    srcs = re.findall(r"[\"'](.*?)[\"']", m.group(1))
    for s in srcs:
      if s.startswith("http") or s.startswith("git+"):
        continue

      # Some file names might use variables:
      for v in PKGMANVARS:
        s = s.replace("${%s}" % v, pkgvars[v])

      localfiles.append(s)

  pkgdb[pkgvars["pkgname"]] = {
    "fn": pkgf,
    "content": "\n".join(content),
    "local-files": localfiles,
  }

# Generate output files. We generate a single file, unless there are local sources
# (such as patches or similar).
for pkgname, info in pkgdb.items():
  if info["local-files"]:
    os.mkdir(os.path.join(args.outdir, pkgname))
    open(os.path.join(args.outdir, pkgname, pkgname + ".pkgbuild"), "w").write(info["content"])
    for lf in info["local-files"]:
      shutil.copyfile(os.path.join(os.path.dirname(info["fn"]), lf), os.path.join(args.outdir, pkgname, lf))
  else:
    open(os.path.join(args.outdir, pkgname + ".pkgbuild"), "w").write(info["content"])


