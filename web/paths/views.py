from aptf.paths.models import *

from django.core.paginator import Paginator, EmptyPage, InvalidPage
from django.http import HttpResponseRedirect
from django.shortcuts import render_to_response, get_object_or_404
from django.template import RequestContext
from django.contrib.auth.views import login
from django.contrib.auth.forms import AuthenticationForm
from django.contrib.auth.models import User
from django.core.urlresolvers import reverse
from django import forms
from django.db.models import Count

def home(request):
  return HttpResponseRedirect('/news/')

def news(request, news_page="1", news_post="1", single=False):
  if single:
    # normalize string news_post
    try:
      post_num = int(news_post)
    except ValueError:
      post_num = 1
    page = 1
    posts = NewsPost.objects.filter(id=post_num)
    posts_pages = Paginator(posts, 4)
    post = get_object_or_404(NewsPost, id=post_num)
  else:
    # normalize string news_page
    try:
      page = max(int(news_page), 1)
    except ValueError:
      page = 1
    posts = NewsPost.objects.order_by('-pub_date')
    posts_pages = Paginator(posts, 3)
    post = None

  # get posts page
  try:
    posts_page = posts_pages.page(page)
  except (EmptyPage, InvalidPage):
    posts_page = posts_pages.page(posts_pages.num_pages)

  songs = Song.objects.all()

  return render_to_response('news.html', {'page' : posts_page,
                                          'post' : post}, 
                            context_instance=RequestContext(request))

def faq(request):
  faqs = FaqEntry.objects.order_by('yindex')
  songs = Song.objects.all()
  return render_to_response('faq.html', {'faqs' : faqs},
           context_instance=RequestContext(request))

def default_paths(request, game_str=None):
  if 'paths' in request.COOKIES:
    prefs = request.COOKIES['paths']
    [alt_game_str, diff_str, inst_str] = prefs.split('-')
    if not game_str:
      game_str = alt_game_str
    if game_str and diff_str and inst_str:
      return HttpResponseRedirect(reverse('paths', kwargs={'game_str' : game_str, 'diff_str' : diff_str, 'inst_str' : inst_str}))
  elif game_str:
    return HttpResponseRedirect(reverse('paths', kwargs={'game_str' : game_str, 'diff_str' : 'expert', 'inst_str' : 'guitar'}))
  else:
    return HttpResponseRedirect(reverse('paths', kwargs={'game_str' : 'rb2', 'diff_str' : 'expert', 'inst_str' : 'guitar'}))

def paths(request, game_str="rb2", diff_str="expert", inst_str="expert", plat_str="xbox360"):
  game = get_object_or_404(Game, short_name=game_str)
  diff = get_object_or_404(Difficulty, short_name=diff_str)
  inst = get_object_or_404(Instrument, short_name=inst_str)
  plat = get_object_or_404(Platform, short_name=plat_str)

  games = Game.objects.order_by('order_index')
  diffs = Difficulty.objects.all()
  insts = Instrument.objects.all()
  plats = Platform.objects.filter(short_name="xbox360")

  table_template = '_'.join([game.short_name, diff.short_name, inst.short_name, plat.short_name]) + '.html'

  response = render_to_response('paths.html', {'table_template' : table_template,
                                               'sel_game' : game,
                                               'games' : games,
                                               'sel_diff' : diff,
                                               'diffs' : diffs,
                                               'sel_inst' : inst,
                                               'insts' : insts,
                                               'plat' : plat,
                                               'plats' : plats},
           context_instance=RequestContext(request))
  
  response.set_cookie('paths',value='-'.join(map(str, [game_str, diff_str, inst_str])),max_age=3600*24*7) 
  return response

def default_path(request, song_str="charlene"):
  if 'path_single' in request.COOKIES:
    prefs = request.COOKIES['path_single']
    [diff_str, inst_str, settings_str, plat_str] = prefs.split('-')
    if diff_str and inst_str and settings_str and plat_str:
      return HttpResponseRedirect(reverse('path', kwargs={'song_str' : song_str, 'diff_str' : diff_str, 'inst_str' : inst_str, 'settings_str' : settings_str, 'plat_str' : plat_str}))

  return HttpResponseRedirect(reverse('path', kwargs={'song_str' : song_str, 'diff_str' : 'expert', 'inst_str' : 'guitar', 'settings_str' : 'upper_bound', 'plat_str' : 'xbox360'}))
  
def path(request, song_str="charlene", diff_str="expert", inst_str="guitar", settings_str="lazy_whammy", plat_str="xbox360", template="img"):
  song = get_object_or_404(Song, mid_name=song_str)
  diff = get_object_or_404(Difficulty, short_name=diff_str)
  inst = get_object_or_404(Instrument, short_name=inst_str)
  settings = get_object_or_404(PathSettings, short_name=settings_str)
  plat = get_object_or_404(Platform, short_name=plat_str)
  path = get_object_or_404(Path, song=song, diff=diff, inst=inst, settings=settings, platform=plat)

  games = Game.objects.all()
  diffs = Difficulty.objects.all()
  insts = Instrument.objects.all()
  settings = PathSettings.objects.order_by('squeeze', 'whammy')
  plats = Platform.objects.filter(short_name="xbox360")

  path_types = [{'full_name' : 'Image', 'short_name' : 'img'},
                {'full_name' : 'Text', 'short_name' : 'txt'}]

  optimal = False
  top_score = None
  top_score_differential = 0
  top_score_date_str = ''
  top_score_over = 0
  try:
    top_score = TopScore.objects.get(song=song,diff=diff,inst=inst)
    top_score_differential = top_score.score - path.score
    if top_score_differential > 0:
      top_score_over = 0
    elif top_score_differential == 0:
      top_score_over = 1
    else:
      top_score_differential = -top_score_differential
      top_score_over = 2
    top_score_date_str = top_score.date.strftime("%B %d, %Y").replace(' 0', ' ')

    # Optimal
    upper_bound_settings = PathSettings.objects.get(short_name='upper_bound')
    optimal_path = Path.objects.get(song=song,diff=diff,inst=inst,settings=upper_bound_settings,platform__short_name='xbox360')
    optimal = (top_score.score >= optimal_path.score)
  except:
    pass

  if template == "txt":
    full_text = path.txt.read()
    type = 'txt'
    template_to_render = 'txt_path.html'
  else:
    full_text = ''
    type = 'img'
    template_to_render = 'img_path.html'

  response = render_to_response(template_to_render, 
                                {'type' : type,
                                 'path' : path,
                                 'text' : full_text,
                                 'games' : games,
                                 'diffs' : diffs,
                                 'insts' : insts,
                                 'settings' : settings,
                                 'plats' : plats,
                                 'path_types' : path_types,
                                 'top_score' : top_score,
                                 'top_score_differential' : top_score_differential,
                                 'top_score_over' : top_score_over,
                                 'top_score_date_str' : top_score_date_str,
                                 'optimal' : optimal},
                                 context_instance=RequestContext(request))

  response.set_cookie('path_single',value='-'.join(map(str, [diff_str, inst_str, settings_str, plat_str])),max_age=3600*24*7)
  return response

INSTS = {'guitar' : 'Guitar', 'bass' : 'Bass', 'all' : 'Guitar and Bass'}
DIFFS = {'easy' : 'Easy', 'medium' : 'Medium', 'hard' : 'Hard', 'expert' : 'Expert', 'all' : 'All'}

def stats(request, type="firsts"):
  return render_to_response(
           'stats.html',
           {'type' : type,
            'stats_template' : type + '_leaderboard.html'},
           context_instance=RequestContext(request))
