from songdata import get_song_data
from addsong import add_songs_by_date_range, repair_all_songs

from datetime import datetime

if __name__ == "__main__":
  start_date = datetime(year=2010,month=1,day=4)
  end_date = datetime(year=2010,month=1,day=6)
  add_songs_by_date_range(start_date,end_date)
