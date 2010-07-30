import os, urllib, csv, re
from datetime import datetime
from aptf.lib.download import download
from private import MIDI_FOLDER_URL, BRB_MIDI_FOLDER_URL

SEARCH_DATA_URL = 'http://rockband.yajags.com/songinfo/searchdata.txt'
SEARCH_DATA_FILE = 'searchdata.txt'
OFFICIAL_SONG_LIST_URL = 'http://rockband.yajags.com/officialsonglist.txt'
OFFICIAL_SONG_LIST_FILE = 'officialsonglist.txt'

DATA_FOLDER = 'data'

GAME_MAP = {'Rock Band DLC' : 'dlc',
            'AC/DC Live Track Pack' : 'acdc',
            'Green Day: Rock Band' : 'greenday',
            'LEGO Rock Band' : 'lrb',
            'The Beatles: Rock Band' : 'brb',
            'The Beatles: Rock Band DLC' : 'brbdlc',
            'Rock Band 2' : 'rb2',
            'Rock Band 1' : 'rb1'}

# Returns an array with one row for each song, each row containing info
def get_song_data():
  # Get raw data from searchdata.txt
  file = os.path.join(DATA_FOLDER, SEARCH_DATA_FILE)
  reader = csv.reader(open(file), delimiter="\t")
  raw_data = []
  for row in reader:
    data_row = []
    for datum in row:
      # Classify 
      try:
        try:
          append = int(datum)
        except:
          append = float(datum)
      except:
        append = datum
      data_row.append(append)
    raw_data.append(data_row)
  data = []
  
  # Get data from officialsonglist.txt (i.e. release dates)
  file = os.path.join(DATA_FOLDER, OFFICIAL_SONG_LIST_FILE)
  reader = csv.reader(open(file), delimiter="\t")
  release_map = {}
  p = re.compile(' \(Cover version\)$')
  for row in reader:
    full_name = row[0]
    # get rid of " (Cover version)" if it's at the end of the title
    full_name = p.sub('', full_name)
    band = row[1]
    try:
      release = datetime.strptime(row[7], "%m/%d/%Y") # MM/DD/YYYY
    except:
      print row
    release_map[(full_name, band)] = release
  
  # Put data in usable form
  for raw_datum in raw_data:
    mid_name = raw_datum[0]
    full_name = raw_datum[2]
    band = raw_datum[4]
    game_long_str = raw_datum[70]
    try:
      release = release_map[(full_name, band)]
    except:
      print "Couldn't find (%s, %s) in release_map" % (full_name, band)
      release = datetime.min

    game = GAME_MAP[game_long_str]

    data.append({
      'mid_name'  : mid_name,
      'full_name' : full_name,
      'release'   : release,
      'game'      : game,
    })
  return data

# Redownloads song data files
def refresh_song_data():
  download(SEARCH_DATA_URL, os.path.join(DATA_FOLDER, SEARCH_DATA_FILE))
  download(OFFICIAL_SONG_LIST_URL, os.path.join(DATA_FOLDER, OFFICIAL_SONG_LIST_FILE))

def fetch_midi(mid_name, game_name, dest_folder):
  url_folder = MIDI_FOLDER_URL
  if game_name == 'brb' or game_name == 'brbdlc':
    url_folder = BRB_MIDI_FOLDER_URL
  download(url_folder + mid_name + '.mid', os.path.join(dest_folder, mid_name + '.mid'), 1)

if __name__ == "__main__":
  refresh_song_data()
