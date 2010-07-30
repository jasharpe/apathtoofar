# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import *

from datetime import datetime
import os

import songdata
from songdata import refresh_song_data, get_song_data
