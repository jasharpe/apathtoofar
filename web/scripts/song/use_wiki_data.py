# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

# Rest of the imports
import re
from datetime import date
from aptf.paths.models import Song

if __name__ == '__main__':
  song_file = open('songs', 'r')
  song_data = song_file.read().splitlines()
  names = song_data[0::8]
  bands = song_data[1::8]
  decades = song_data[2::8]
  genres = song_data[3::8]
  packs = song_data[4::8]
  releases = song_data[5::8]
  legos = song_data[6::8]
  for i in range(0, len(names)):
    if Song.objects.filter(full_name__iexact=names[i]):
      song = Song.objects.get(full_name__iexact=names[i])
      song.release = releases[i]
      song.save()
