# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

# Rest of the imports
from aptf.paths.models import Song, Game
from datetime import date

def fix_common_release_dates():
  # giant override list if I'm not smart enough to figure this out
  song_map = {('allyouneedislove') : date(year=2009,month=9,day=9),
              ('maxwells', 'ohdarling', 'because', 'younevergive', 'sunkingmeanmr', 'polythenebathroom', 'goldencarrytheend', 'hermajesty', 'abbeyroadmedley') : date(year=2009,month=10,day=20),
              ('fixingahole', 'shesleavinghome', 'beingformrkite', 'withinyouwithoutyou', 'whenim64', 'lovelyrita', 'sgtpepperreprise', 'adayinthelife') : date(year=2009,month=11,day=17),
              ('norwegianwood', 'youwontseeme', 'nowhereman', 'thinkforyourself', 'theword', 'michelle', 'whatgoeson', 'girl', 'inmylife', 'wait', 'runforyourlife') : date(year=2009,month=12,day=15),
              ('gone_mg', 'meandmygang', 'ontheroadagain', 'shethinksmytractorssexy', 'sudsinabucket', 'swing') : date(year=2009,month=7,day=21)}

  for songs, timestamp in song_map.items():
    for mid_name in songs:
      if Song.objects.filter(mid_name=mid_name):
        song = Song.objects.get(mid_name=mid_name)
        if song.release != timestamp:
          song.release = timestamp
          song.save()

  songs = Song.objects.filter(game__short_name='rb1')
  release = date(year=2007, month=11, day=20)
  for song in songs:
    if song.release != release:
      song.release = release
      song.save()

  songs = Song.objects.filter(game__short_name='rb2')
  release = date(year=2008, month=9, day=14)
  for song in songs:
    if song.release != release:
      song.release = release
      song.save()

  songs = Song.objects.filter(game__short_name='acdc')
  release = date(year=2008, month=11, day=2)
  for song in songs:
    if song.release != release:
      song.release = release
      song.save()

  songs = Song.objects.filter(game__short_name='brb')
  release = date(year=2009, month=9, day=9)
  for song in songs:
    if song.release != release:
      song.release = release
      song.save()

  songs = Song.objects.filter(game__short_name='lrb')
  release = date(year=2009, month=11, day=3)
  for song in songs:
    if song.release != release:
      song.release = release
      song.save()

if __name__ == "__main__":
  fix_common_release_dates();
