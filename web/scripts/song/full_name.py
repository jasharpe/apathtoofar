from urllib2 import urlopen

# look up full_name on ajanata's site:
# http://174.143.27.23/~ajanata/phpspopt/web/songname.php?SONG_NAME
def full_name(mid_name):
  return urlopen('http://174.143.27.23/~ajanata/phpspopt/web/songname.php?'+mid_name).read()

def wiki_songs():
  return open('wiki_songs.htm', 'r').read().replace('\n','').replace('\r','')

if __name__ == '__main__':
  print wiki_songs()
