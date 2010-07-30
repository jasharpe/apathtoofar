from aptf.paths.models import *
from django.contrib import admin

class NewsCommentInline(admin.StackedInline):
  model = NewsComment
  extra = 3

class NewsPostAdmin(admin.ModelAdmin):
  pass

class FaqCommentInline(admin.StackedInline):
  model = FaqComment
  extra = 3

class FaqEntryAdmin(admin.ModelAdmin):
  pass

class SongAdmin(admin.ModelAdmin):
  ordering = ['mid_name']
  list_per_page = 1000
  search_fields = ['mid_name', 'full_name']
  list_filter = ['game']
  list_display = ['__unicode__', 'mid_name', 'release']

class TopScoreAdmin(admin.ModelAdmin):
  list_per_page = 1000
  search_fields = ['song__mid_name']
  list_display = ['__unicode__', 'date', 'song']

class PathAdmin(admin.ModelAdmin):
  order = ['song__mid_name']
  list_per_page = 1000
  search_fields = ['song__mid_name', 'song__full_name']

admin.site.register(NewsPost, NewsPostAdmin)
admin.site.register(FaqEntry, FaqEntryAdmin)
admin.site.register(Song, SongAdmin)
admin.site.register(PathSettings)
admin.site.register(Path, PathAdmin)
admin.site.register(Game)
admin.site.register(TopScore, TopScoreAdmin)
admin.site.register(Platform)
admin.site.register(Instrument)
admin.site.register(Difficulty)
