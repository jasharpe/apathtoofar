# -*- coding: utf-8 -*-

# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

import csv
from django.utils.encoding import smart_unicode
import codecs
from aptf.paths.models import Song

# Changes the song specified by mid_name's full_name to full_name
def change_full_name(mid_name, full_name):
  song = Song.objects.get(mid_name=mid_name)
  song.full_name = full_name
  song.save()
  print song

if __name__ == "__main__":
  #ugh = [('vivalagloria', unicode("\u00a1Viva La Gloria!", errors='replace'))]
  ugh = [('vivalagloria', u"\xa1Viva la Gloria!")]
  for thing in ugh:
    mid_name = thing[0]
    full_name = thing[1]
    change_full_name(mid_name, full_name)
