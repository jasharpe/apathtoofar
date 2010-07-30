# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import Song, Game

# Prints sql to update mid_files since for some reason django doesn't let you do it????

for song in Song.objects.all():
  mid_file = 'mid/%s/%s.mid' % (song.game.short_name, song.mid_name)
  print "UPDATE paths_song SET mid_file='%s' WHERE mid_name='%s';" % (mid_file, song.mid_name)
