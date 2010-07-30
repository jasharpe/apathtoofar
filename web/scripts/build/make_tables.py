# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from django.template.loader import get_template
from django.template import Context
from aptf.paths.models import Path, Song, Game, Difficulty, Instrument, TopScore, Platform, PathSettings
import os, sys, time

def make_table(game, diff, inst, plat, dest_file, regen):
  songs = Song.objects.filter(game=game).order_by('full_name')
  settings = PathSettings.objects.all().order_by('squeeze', 'whammy', '-lazy')

  if not regen and os.path.isfile(dest_file):
    print "Skipping %s!" % dest_file
    return

  print "Generating %s..." % dest_file

  rows = []
  all_paths = list(Path.objects.filter(song__game=game,diff=diff,inst=inst,platform=plat).order_by('song__full_name', 'settings__squeeze', 'settings__whammy', '-settings__lazy').select_related('song__topscore_set'))
  all_paths.append(Path.objects.exclude(song=all_paths[-1].song).filter(song__game=all_paths[-1].song.game)[0])
  cur_song = all_paths[0].song
  cur_release = cur_song.release
  diff_releases = True
  top_score = 0
  top_score_obj = None
  start_time = time.time()
  song_paths = []
  for path in all_paths:
    song = path.song
    
    # Check if we're done a song and put its stuff in a row
    if song != cur_song:
      top_path_score = 0
      if song_paths:
        top_path_score = song_paths[-1]['path'].score
      
      rel_top_score = top_score - top_path_score
      rows.append({'song' : cur_song, 'top_score' : top_score_obj, 'paths' : song_paths, 'use_top_score' : {'neg' : rel_top_score < 0, 'top_score' : rel_top_score}, 'release' : cur_song.release})

      song_paths = []
      top_score = 0
      top_score_obj = None
      cur_song = song
      if cur_song.release != cur_release:
        diff_releases = False
      cur_release = cur_song.release

    if not top_score:
      top_scores = cur_song.topscore_set.filter(inst=inst,diff=diff)
      if top_scores:
        top_score_obj = top_scores[0]
        top_score = top_score_obj.score

    song_paths.append({'greater' : path.score < top_score, 'less' : path.score > top_score, 'path' : path})
    #print song_paths

  #print rows
  print "Time elapsed: %d seconds" % (time.time() - start_time)

  # Render html
  t = get_template('paths_table.html')
  c = Context({'settings' : settings,
               'rows' : rows,
               'diff' : diff,
               'inst' : inst,
               'plat' : plat,
               'diff_releases' : diff_releases,})
  html = t.render(c).encode('utf-8')

  # write this html to a template file for later use
  fp = open(dest_file, 'w')
  fp.write(html)
  fp.close()

def make_tables(games, diffs, insts, plats, template_folder, regen):
  for game in games:
    for diff in diffs:
      for inst in insts:
        for plat in plats:
          dest_file = '_'.join([game.short_name, diff.short_name, inst.short_name, plat.short_name]) + '.html'
          make_table(game, diff, inst, plat, os.path.join(template_folder, dest_file), regen)

if __name__ == "__main__":
  regen = 0
  if len(sys.argv) > 1 and sys.argv[1] == 'regen':
    regen = 1
  if len(sys.argv) > 1 and sys.argv[1] == 'test':
    games = Game.objects.filter(short_name="dlc")
    diffs = Difficulty.objects.filter(short_name='expert')
    insts = Instrument.objects.filter(short_name='guitar')
    plats = Platform.objects.filter(short_name="xbox360")
    regen = 1
  else:
    games = Game.objects.all()
    diffs = Difficulty.objects.all()
    insts = Instrument.objects.all()
    plats = Platform.objects.filter(short_name="xbox360")
  make_tables(games, diffs, insts, plats, settings.STATIC_TEMPLATE_DIR, regen)
