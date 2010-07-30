# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import *

from datetime import datetime
import os

import songdata
from songdata import get_song_data

def get_songs_raw_by_date_range(start_date, end_date):
  return filter(lambda x: start_date <= x['release'] <= end_date, get_song_data())
  
