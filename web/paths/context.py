from aptf.paths.models import Song

def add_all_songs(request):
  all_songs = list(Song.objects.filter(path_genning=1))
  return {'all_songs' : all_songs,
          'last_all_song' : all_songs[-1]}
