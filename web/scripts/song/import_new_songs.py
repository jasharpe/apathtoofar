# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

# Rest of the imports
import csv
import sys
from full_name import full_name as get_full_name
from fix_common_release_dates import fix_common_release_dates
from datetime import date
from django.utils.encoding import DjangoUnicodeDecodeError
from aptf.paths.models import Song, Game

def import_new_songs(mid_file):
  mid_file_reader = csv.reader(open(mid_file), delimiter=",")
  for row in mid_file_reader:
    mid_name = row[0]
    game = row[1]
    if not Song.objects.filter(mid_name=mid_name):
      game = Game.objects.get(short_name=game)
      full_name = get_full_name(mid_name)
      try:
        song = Song(game=game,mid_name=mid_name,full_name=full_name,release=date(year=2000,month=1,day=1))
        song.save()
      except DjangoUnicodeDecodeError:
        song = Song(game=game,mid_name=mid_name,full_name=mid_name,release=date(year=2000,month=1,day=1))
        print mid_name + " failed, wtf"
        song.save()

if __name__ == "__main__":
  print sys.argv
  import_new_songs(sys.argv[1])
  fix_common_release_dates()
