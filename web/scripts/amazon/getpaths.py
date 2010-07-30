#!/usr/bin/python

##
# A script to use Amazon Web Services to get generated paths for a batch of songs.
##

__author__ = "Jeremy Sharpe"
__copyright__ = "Copyright 2009, Jeremy Sharpe"

# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

import os, shutil, re, sys
from aptf.paths.models import Song, Game, Path, PathSettings, Platform, Difficulty, Instrument
from django.db import transaction

from fetchpaths import fetch_paths
from time import time

if __name__ == "__main__":
  times = 1
  if len(sys.argv) > 1:
    times = int(sys.argv[1])
  if len(sys.argv) > 2:
    dir_prefix = sys.argv[2]
  else:
    dir_prefix = "results%d" % int(time())
    os.mkdir(dir_prefix)
  fetch_paths('./%s' % dir_prefix, times)
  png_match = re.compile("^([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.e\.(png)$")
  txt_match = re.compile("^([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.e\.(txt)$")
  opt_match = re.compile("^([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.([^\.]*)\.e\.(opt)$")
  songs = {}
  for entry in os.listdir('.'):
    #if re.match(dir_prefix+"\d*", entry):
    if re.match(dir_prefix, entry):
      for file in os.listdir(entry):
        file_path = entry + '/' + file
        if re.match(".*\.png$|.*\.txt$|.*\.opt$", file):
          p = png_match.match(file)
          t = txt_match.match(file)
          o = opt_match.match(file)
          if p:
            a = p
          elif t:
            a = t
          elif o:
            a = o
          else:
            print file

          if a is None:
            continue

          (mid_name, diff, inst, lazy, squeeze, whammy, file_type) = a.groups()
         
          if not (mid_name, diff, inst, lazy, squeeze, whammy) in songs:
            songs[(mid_name, diff, inst, lazy, squeeze, whammy)] = {}
          
          if file_type == "txt":
            # Have to open txt file to find optimal score...
            txt_f = open(file_path, "r")
            opt_score_pat = re.compile("^Estimated Optimal Score: (\d+)$")
            for line in txt_f:
              line = line.rstrip()
              opt_score_mat = opt_score_pat.match(line)
              if opt_score_mat:
                score = int(opt_score_mat.group(1))
            txt_f.close()
            if not score:
              print "Couldn't get score from txt file " + txt
              continue
            songs[(mid_name, diff, inst, lazy, squeeze, whammy)]['score'] = score
          
          songs[(mid_name, diff, inst, lazy, squeeze, whammy)][file_type] = file_path



  paths = Path.objects.all()
  transaction.enter_transaction_management()
  transaction.managed(True)
  for (mid_name, diff_str, inst_str, lazy, squeeze, whammy), files in songs.items():
    if 'png' in files and 'txt' in files and 'opt' in files and 'score' in files:
      png = files['png']
      txt = files['txt']
      opt = files['opt']
      score = files['score']

      # Get path settings (if they exist, otherwise skip)
      try:
        settings = PathSettings.objects.get(squeeze=squeeze,lazy=lazy,whammy=whammy)
        song = Song.objects.get(mid_name=mid_name)
        song.path_genning = 1
        song.save()
        platform = Platform.objects.get(short_name="xbox360")
        diff = Difficulty.objects.get(short_name=diff_str)
        inst = Instrument.objects.get(short_name=inst_str)
      except PathSettings.DoesNotExist:
        print "Settings don't exist corresponding to " + str((lazy, squeeze, whammy))
        continue
      except Song.DoesNotExist:
        print "Song doesn't exist corresponding to " + mid_name
        continue
      except Platform.DoesNotExist:
        print "Platform xbox360 doesn't exist"
        continue
      except Instrument.DoesNotExist:
        print "Instrument " + inst_str + " does not exist"
        continue
      except Difficulty.DoesNotExist:
        print "Difficulty " + diff_str + " does not exist"
        continue

      # Delete old path if one still exists
      if Path.objects.filter(song=song,diff=diff,inst=inst,settings=settings):
        print "deleting path from song %s" % song.mid_name
        for path in Path.objects.filter(song=song,diff=diff,inst=inst,settings=settings):
          try:
            path.img.delete()
            path.txt.delete()
            path.delete()
          except:
            print "failed to delete"
      
      print (song, diff, inst, platform, settings, score, png, txt)

      # Actually add path!
      # Copy files to the correct location
      os.rename(png, "../../media/path/img/"+os.path.basename(png))
      os.rename(txt, "../../media/path/txt/"+os.path.basename(txt))
      os.rename(opt, "../../media/path/opt/"+os.path.basename(opt))

      path = Path(song=song,diff=diff,inst=inst,platform=platform, \
                  settings=settings,score=score,img="path/img/"+os.path.basename(png),txt="path/txt/"+os.path.basename(txt))
      path.save()
  
  transaction.commit()
  transaction.leave_transaction_management()
