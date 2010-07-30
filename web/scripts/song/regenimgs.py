# Set up django environment
from django.core.management import setup_environ
from aptf import settings as aptf_settings
setup_environ(aptf_settings)

from aptf.paths.models import Song, Instrument, Platform, Difficulty, Path, PathSettings
import os, shutil

OPTIMIZE_DIR = '/cygdrive/c/proj/odopt/'
TMP_DIR = OPTIMIZE_DIR + 'tmp/'
AMAZON_DIR = '../amazon/'
RESULTS_DIR = AMAZON_DIR + 'resultss/'

def regen_img(song, inst, diff, settings, plat):
  path = Path.objects.get(song=song,inst=inst,diff=diff,settings=settings,platform=plat)
  opt_file = aptf_settings.MEDIA_ROOT + path.txt.name.replace('txt', 'opt')
  opt_file_end = os.path.basename(opt_file)
  print opt_file
  txt_file_end = opt_file_end.replace('.opt', '.txt')
  img_file_end = opt_file_end.replace('.opt', '.png')
  if os.path.isfile(opt_file):
    shutil.copy(opt_file, TMP_DIR)
    os.system('cd %s && perl rbopt.pl -e --noopt -l %d -s %d -w %d -d %s -i %s %s' % (OPTIMIZE_DIR, settings.lazy * 100, settings.squeeze, settings.whammy, diff.full_name, inst.full_name, song.mid_name))
    shutil.copy(os.path.join(TMP_DIR, opt_file_end), RESULTS_DIR)
    shutil.copy(os.path.join(TMP_DIR, txt_file_end), RESULTS_DIR)
    shutil.copy(os.path.join(TMP_DIR, img_file_end), RESULTS_DIR)
    os.system('cd %s && python getpaths.py 0 resultss' % AMAZON_DIR)

def regen_imgs(songs, insts, diffs, settingss, plats):
  for song in songs:
    for inst in insts:
      for diff in diffs:
        for settings in settingss:
          for plat in plats:
            regen_img(song, inst, diff, settings, plat)

if __name__ == "__main__":
  songs = Song.objects.filter(game__short_name="brbdlc",path_genning__lt=2)

  print songs

  insts = Instrument.objects.all()
  diffs = Difficulty.objects.all()
  settingss = PathSettings.objects.all()
  plats = Platform.objects.filter(short_name="xbox360")

  regen_imgs(songs, insts, diffs, settingss, plats)
