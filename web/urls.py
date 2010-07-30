from django.conf.urls.defaults import *
from django.conf import settings

# Uncomment the next two lines to enable the admin:
from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
  # default
    
  (r'^$', 'aptf.paths.views.home'),

  # news/faq
  
  (r'^news/$', 'aptf.paths.views.news'),
  (r'^faq/$', 'aptf.paths.views.faq'),
  (r'^news/(?P<news_page>\d+)/$', 'aptf.paths.views.news'),
  (r'^news/(?P<news_post>\d+)/.+$', 'aptf.paths.views.news', {'single' : True}),

  (r'^stats/$', 'aptf.paths.views.stats'),
  (r'^stats/firsts/$', 'aptf.paths.views.stats', {'type' : 'firsts'}),
  (r'^stats/optimals/$', 'aptf.paths.views.stats', {'type' : 'optimals'}),

  # paths page
  (r'^paths/$', 'aptf.paths.views.default_paths'),
  (r'^paths/(?P<game_str>[_0-9a-zA-Z]*)/$', 'aptf.paths.views.default_paths'),
  url(r'^paths/(?P<game_str>[_0-9a-zA-Z]*)/(?P<diff_str>[_0-9a-zA-Z]*)/(?P<inst_str>[_0-9a-zA-Z]*)/$', 'aptf.paths.views.paths', name='paths'),

  # individual path, e.g. 
  # path/charlene/expert/guitar/lazy_whammy/xbox360/img/
  # path/charlene/expert/guitar/lazy_whammy/xbox360/txt/
  url(r'^path/(?P<plat_str>[_0-9a-z0-9A-Z]*)/(?P<diff_str>[_0-9a-z0-9A-Z]*)/(?P<inst_str>[_0-9a-z0-9A-Z]*)/(?P<settings_str>[_0-9a-z0-9A-Z]*)/(?P<song_str>[_0-9a-z0-9A-Z]*)/img/$', 'aptf.paths.views.path', {'template' : 'img'}, name='path'),
  url(r'^path/(?P<plat_str>[_0-9a-z0-9A-Z]*)/(?P<diff_str>[_0-9a-z0-9a-z]*)/(?P<inst_str>[_0-9a-z0-9A-Z]*)/(?P<settings_str>[_0-9a-z0-9A-Z]*)/(?P<song_str>[_0-9a-z0-9A-Z]*)/txt/$', 'aptf.paths.views.path', {'template' : 'txt'}),
  url(r'^path/(?P<song_str>[_0-9a-zA-Z]*)/', 'aptf.paths.views.default_path'),

  # Uncomment the admin/doc line below and add 'django.contrib.admindocs' 
  # to INSTALLED_APPS to enable admin documentation:
  # (r'^admin/doc/', include('django.contrib.admindocs.urls')),

  # Uncomment the next line to enable the admin:
  (r'^admin/', include(admin.site.urls)),  
  (r'^static/(?P<path>.*)$', 'django.views.static.serve',
    {'document_root': settings.STATIC_DOC_ROOT}),
  
)
