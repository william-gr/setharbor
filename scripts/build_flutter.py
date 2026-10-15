"""Build from the Git committer date. Run Flutter commands sequentially: native
plugin registrants are shared generated files across debug/release builds.
"""
import argparse
import datetime
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]
def build(platform,edition,debug=False):
    date=subprocess.check_output(['git','log','-1','--format=%cs'],cwd=ROOT,text=True).strip()
    datetime.date.fromisoformat(date)
    version=date.replace('-','')
    if len(version)!=8:raise ValueError('Commit date must be YYYYMMDD')
    command=['flutter','build',platform,'--build-name',version if platform=='apk' else date.replace('-','.'),'--build-number',version]
    if platform=='apk':command+=['--flavor',edition,'--debug' if debug else '--release']
    else:command+=['--no-codesign']
    subprocess.run(command,cwd=ROOT/'flutter_app',check=True)
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('platform',choices=['apk','ios'])
    parser.add_argument('--edition',choices=['personal','preview','e2e'],default='personal')
    parser.add_argument('--debug',action='store_true')
    args=parser.parse_args();build(args.platform,args.edition,args.debug)
