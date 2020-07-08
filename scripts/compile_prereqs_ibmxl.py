#!/usr/bin/env python3
"""
Installs prereqs for Gemini program for IBM XL compiler
"""

import shutil
from pathlib import Path
from argparse import ArgumentParser
import typing as T
import sys
import os

from compile_prereqs_gcc import mumps, hdf5, lapack, scalapack

# ========= user parameters ======================
BUILDDIR = "build"
# ========= end of user parameters ================

nice = ["nice"] if sys.platform == "linux" else []


def get_compilers() -> T.Mapping[str, str]:
    """ get paths to compilers """
    env = os.environ

    fc_name = "xlf"
    cc_name = "xlc"
    cxx_name = "xlc++"

    fc = env.get("FC", "")
    if fc_name not in fc:
        fc = shutil.which(fc_name)
    if not fc:
        raise FileNotFoundError(fc_name)

    cc = env.get("CC", "")
    if cc_name not in cc:
        cc = shutil.which(cc_name)
    if not cc:
        raise FileNotFoundError(cc_name)

    cxx = env.get("CXX", "")
    if cxx_name not in cxx:
        cxx = shutil.which(cxx_name)
    if not cxx:
        raise FileNotFoundError(cxx_name)

    env.update({"FC": fc, "CC": cc, "CXX": cxx})

    return env


if __name__ == "__main__":
    p = ArgumentParser()
    p.add_argument(
        "libs",
        help="libraries to compile",
        choices=["hdf5", "lapack", "scalapack", "mumps"],
        nargs="+",
    )
    p.add_argument("-prefix", help="toplevel path to install libraries under", default="~/lib_xl")
    p.add_argument("-workdir", help="toplevel path to where you keep code repos", default="~/code")
    p.add_argument("-wipe", help="wipe before completely recompiling libs", action="store_true")
    p.add_argument("-buildsys", help="build system (meson or cmake)", default="cmake")
    P = p.parse_args()

    dirs = {
        "prefix": Path(P.prefix).expanduser().resolve(),
        "workdir": Path(P.workdir).expanduser().resolve(),
    }

    if "lapack" in P.libs:
        lapack(P.wipe, dirs, P.buildsys, env=get_compilers())
    if "scalapack" in P.libs:
        scalapack(P.wipe, dirs, P.buildsys, env=get_compilers())
    if "mumps" in P.libs:
        mumps(P.wipe, dirs, P.buildsys, env=get_compilers())
    if "hdf5" in P.libs:
        hdf5(dirs, env=get_compilers())