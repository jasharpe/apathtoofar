from addsong import repair_all_songs, add_songs_by_date_range
from datetime import datetime, date

if __name__ == "__main__":
  repair_all_songs()
  add_songs_by_date_range(datetime(year=2009,month=12,day=31), datetime.now())
  # Songs that we couldn't get a release date for cause we're lame
  add_songs_by_date_range(datetime.min, datetime.min)
