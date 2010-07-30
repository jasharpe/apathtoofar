# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

# Rest of the imports
import csv
from full_name import full_name as get_full_name
from datetime import date
from django.utils.encoding import DjangoUnicodeDecodeError
from aptf.paths.models import Song, Game

if __name__ == "__main__":
  # Get song to game mapping
  song_to_game_file = 'songtogame'
  songToGameReader = csv.reader(open(song_to_game_file), delimiter=',')
  song_to_game = {}
  for row in songToGameReader:
    mid_name = row[0]
    game_short = row[1]
    song_to_game[mid_name] = game_short

  # Read songs and add them to database
 # old_song_file = 'old_data'
 # songReader = csv.reader(open(old_song_file), delimiter=',', quotechar='"', lineterminator='\n', escapechar='\\')
 # for row in songReader:
 #   mid_name = row[0]
 #   full_name = row[1]
 #   #print mid_name
 #   if not Song.objects.filter(mid_name=mid_name):
 #     game = Game.objects.get(short_name=song_to_game[mid_name])
 #     song = Song(game=game,mid_name=mid_name,full_name=full_name,release=date(year=2000,month=1,day=1))
 #     song.save()

  # Read all songs and add new ones to database, getting name from ajanata
  song_file = 'midlist'
  songReader = csv.reader(open(song_file), delimiter=',')
  count = 0
  songset = {}
  for row in songReader:
    mid_name = row[0]
    game = row[1]
    if not Song.objects.filter(mid_name=mid_name):
      game = Game.objects.get(short_name=game)
      full_name = get_full_name(row[0])
      try:
        song = Song(game=game,mid_name=mid_name,full_name=full_name,release=date(year=2000,month=1,day=1))
        #print song
        #song.save()
      except DjangoUnicodeDecodeError:
        song = Song(game=game,mid_name=mid_name,full_name=mid_name,release=date(year=2000,month=1,day=1))
        #print song
        #song.save()
    else:
      if mid_name in songset:
        print mid_name
      songset[mid_name] = 1
      count += 1
      #print mid_name
    
  print count
