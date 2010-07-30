# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import Path, Song, Game

if __name__ == "__main__":
  
  for song in [song for song in Song.objects.all() if song.game.short_name == 'rb1']:
    if len(song.path_set.all()) < 48:
      print song
      song.path_genning = 0
      song.save()
