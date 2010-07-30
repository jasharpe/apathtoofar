import os
import time
import re
import zipfile
import shutil

# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import *

def fetch_paths(results_dir, times=1):
  file_list = 'tmp/file_list%d' % int(time.time())
  lst_cmd = 'ruby s3sync/s3cmd.rb list aptf_results:/ 1000000 > %s' % file_list
  os.system(lst_cmd)

  # if the file is not yet ready, wait for it
  loop_times = 3
  while not os.path.isfile(file_list) and loop_times > 0:
    sleep(10)
    loop_times -= 1

  file_list_f = open(file_list, 'r')

  zip_matcher = re.compile("^.*?([^/]*).zip$")
  for line in [line.rstrip() for line in sorted(file_list_f.readlines())]:
    zip_match = zip_matcher.match(line)
    if zip_match:
      bad_file = 0
      mid_name = zip_match.group(1)
      try:
        song = Song.objects.get(mid_name=mid_name)
      except:
        print "Song with name %s doesn't exist!" % mid_name
        continue
      song.path_genning = 1
      song.save()
      zip_file = 'tmp/%s.zip' % mid_name
      get_cmd = 'ruby ./s3sync/s3cmd.rb get aptf_results:%s %s' % (line, zip_file)
      del_cmd = 'ruby ./s3sync/s3cmd.rb delete aptf_results:%s' % line
      bad_file = 0
      if os.path.isfile(zip_file):
        os.remove(zip_file)
      while not os.path.isfile(zip_file):
        try:
          os.system(get_cmd)
        except:
          bad_file = 1
          break
      if bad_file:
        print "uh oh, skipping a line: %s" % line
        continue
      # unzip
      try:
        zip = zipfile.ZipFile(zip_file, 'r')
      except zipfile.BadZipfile:
        print "bad zipfile: %s" % line
        continue
      for n in zip.namelist():
        dest = os.path.join(results_dir, n)
        destdir = os.path.dirname(results_dir)
        if not os.path.isdir(destdir):
          os.makedirs(destdir)
        data = zip.read(n)
        f = open(dest, 'w')
        f.write(data)
        f.close()
      zip.close()
      os.system(del_cmd)
      if times == 1: break
      times -= 1
      #os.unlink(zip_file)

if __name__=="__main__":
  fetch_paths('./results')
