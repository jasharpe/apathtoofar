# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import Song, TopScore, Game, Instrument, Platform, Difficulty
from get_top_scores import get_top_scores
from django.db import transaction

import time

# These lists govern which games pages can contain scores for
page_to_game = {'rb1' : ['rb1', 'rb2', 'dlc', 'acdc', 'lrb'],
                'rb2' : ['rb1', 'rb2', 'dlc', 'acdc', 'lrb'],
                'brb' : ['brb', 'brbdlc']}

exception_list = {'Polythene Pam/She Came In Through The...' : 'Polythene Pam/She Came in Through the Bathroom Window'}

def update_top_scores(inst_label_input, diff_label_input, game_label_input):
  transaction.enter_transaction_management()
  transaction.managed(True)
  all_top_scores = get_top_scores(inst_label_input, diff_label_input, game_label_input)
  for (game_label, inst_label, diff_label), top_scores in all_top_scores.items():
    game = Game.objects.get(short_name=game_label)
    inst = Instrument.objects.get(short_name=inst_label)
    diff = Difficulty.objects.get(short_name=diff_label)
    for top_score in top_scores.values():
      song = None
      songs_allowed = Song.objects.filter(game__short_name__in=page_to_game[game_label_input])
      if top_score['song'] in exception_list.keys():
        top_score['song'] = exception_list[top_score['song']]

      if not songs_allowed.filter(full_name__iexact=top_score['song']):
        print "Song " + top_score['song'] + " doesn't exist"
      else:
        song = songs_allowed.get(full_name__iexact=top_score['song'])
        
      if song:
        platform = Platform.objects.get(short_name=top_score['platform'])
        new_top_score, created = \
          TopScore.objects.get_or_create(
            song=song, diff=diff, inst=inst,
            defaults={'user' : top_score['user'],
                      'score' : top_score['score'],
                      'date' : top_score['timestamp'],
                      'platform' : platform})
        # Always take the earliest achieved top score if they're equal
        if not created:
          new_top_score.user = top_score['user']
          new_top_score.score = top_score['score']
          new_top_score.date = top_score['timestamp']
          new_top_score.platform = platform
          try_count = 3
          # .save() might fail, so try it a few times. If it still fails, we
          # can just skip this update. It doesn't really matter.
          while try_count > 0:
            try:
              new_top_score.save()
              try_count = 0
            except:
              print "Failed to save song, trying again"
              time.sleep(5)
              try_count -= 1
      #print new_top_score
  try_count = 10
  while try_count > 0:
    try:
      transaction.commit()
      try_count = 0
    except:
      print "Failed to commit transaction, trying again"
      time.sleep(5)
      try_count -= 1
  transaction.leave_transaction_management() 

if __name__ == "__main__":
  for game_label in ['brb', 'rb1', 'rb2']:
    for inst_label in ['guitar', 'bass']:
      for diff_label in ['easy', 'medium', 'hard', 'expert']:
        print "running "+(",".join([game_label, inst_label, diff_label]))
        update_top_scores(inst_label, diff_label, game_label)
