# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import Song, Game

from datetime import datetime
import os

import songdata
from songdata import refresh_song_data, get_song_data
from getsong import get_songs_raw_by_date_range

# Add all the songs released between start_date and end_date
def add_songs_by_date_range(start_date, end_date):
  for song in get_songs_raw_by_date_range(start_date, end_date):
    add_song(song['mid_name'], song['full_name'], song['game'], song['release'])

# Add the song identified by mid_name
def add_song(mid_name, full_name, game_name, release):
  if not Song.objects.filter(mid_name=mid_name):
    game = Game.objects.get(short_name=game_name)  
    fetch_midi(mid_name, game_name)
    print "Adding song with mid name %s, game %s, full name %s, and release %s" % (mid_name, str(game), full_name, str(release))
    
    # path_genning=3 means not yet queued for pathing. The song is simply added.
    song = Song(game=game,mid_name=mid_name,full_name=full_name,release=release,path_genning=3,mid_file=('mid/%s/%s.mid' % (game.short_name, mid_name)))
    print song.id
    song.save()
    print song.id
  else:
    print "Skipping - song %s already exists" % mid_name

def repair_song(song): 
  print "Repairing %s" % str(song)

  # Redownload midi
  fetch_midi_from_song(song)

  # Set path status to 0
  song.path_genning = 3
  song.save()

def repair_all_songs():
  # Get all songs that have been marked as broken
  songs = Song.objects.filter(path_genning=2)
  for song in songs:
    repair_song(song)

def fetch_midi_from_song(song):
  return fetch_midi(song.mid_name, song.game.short_name)

def fetch_midi(mid_name, game):
  return songdata.fetch_midi(mid_name, game, os.path.join(settings.MIDI_FOLDER, game))
