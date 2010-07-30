# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from django.template.loader import get_template
from django.template import Context
from django.db.models import Count

from aptf.paths.models import *
import os, sys, time

leaderboard_length = 10

INSTS = {'guitar' : 'Guitar', 'bass' : 'Bass', 'all' : 'Guitar and Bass'}
DIFFS = {'easy' : 'Easy', 'medium' : 'Medium', 'hard' : 'Hard', 'expert' : 'Expert', 'all' : 'All'}

def count_compare(x, y):
  if x['user__count'] > y['user__count']:
    return -1
  elif x['user__count'] == y['user__count']:
    return 0
  else:
    return 1

def make_leaderboard(type, template_folder):
  dest_file = os.path.join(template_folder, type + '_leaderboard.html')

  leaderboard_length = 10
  if type == "optimals":
    opt_scores = {}
    for path in Path.objects.filter(settings__short_name="upper_bound"):
      opt_scores[(path.song,path.inst,path.diff)] = path.score
  leaderboard_columns = []
  for inst_str in ['all', 'guitar', 'bass']:
    leaderboard_column = []
    for diff_str in ['all', 'expert', 'hard', 'medium', 'easy']:
      if type == 'firsts':
        leaderboard = TopScore.objects.values('user').annotate(Count('user')).order_by('-user__count')
      else:
        leaderboard = TopScore.objects.filter(song__path_genning=1)

      if inst_str != 'all':
        leaderboard = leaderboard.filter(inst__short_name=inst_str)
      if diff_str != 'all':
        leaderboard = leaderboard.filter(diff__short_name=diff_str)
      if type == 'optimals':
        leaderboard_dict = {}
        for top_score in leaderboard:
          if (top_score.song,top_score.inst,top_score.diff) in opt_scores and top_score.score >= opt_scores[(top_score.song,top_score.inst,top_score.diff)]:
            if not top_score.user in leaderboard_dict:
              leaderboard_dict[top_score.user] = 1
            else:
              leaderboard_dict[top_score.user] += 1
        leaderboard = []
        for (user, optimals) in leaderboard_dict.items():
          leaderboard.append({'user' : user, 'user__count' : optimals})
        leaderboard.sort(count_compare)
        while len(leaderboard) < leaderboard_length:
          leaderboard.append({'user' : 'N/A', 'user__count' : 'N/A'})
      leaderboard_column.append({'title' : DIFFS[diff_str] + ' ' + INSTS[inst_str], 'leaderboard' : leaderboard[:leaderboard_length]})
    leaderboard_columns.append(leaderboard_column)

  type_str = "Firsts"
  if (type == 'optimals'):
    type_str = "Optimals"

  t = get_template('stats_table.html')
  c = Context({'leaderboard_columns' : leaderboard_columns,
              'type' : type,
              'type_str' : type_str})
  html = t.render(c).encode('utf-8')

  fp = open(dest_file, 'w')
  fp.write(html)
  fp.close()

def make_leaderboards(template_folder):
  make_leaderboard('firsts', template_folder)
  make_leaderboard('optimals', template_folder)

if __name__ == "__main__":
  make_leaderboards(settings.STATIC_TEMPLATE_DIR)
