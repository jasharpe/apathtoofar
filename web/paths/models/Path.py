from django.db import models
from aptf.paths.models import Song, Difficulty, Instrument, Platform

###
# Path models - represent path objects
###

class PathSettings(models.Model):
  name = models.CharField(max_length=50)
  short_name = models.CharField(max_length=100)
  squeeze = models.PositiveSmallIntegerField()
  whammy = models.PositiveSmallIntegerField()
  lazy = models.BooleanField()
 
  def __unicode__(self):
    return self.name

  class Meta:
    app_label = 'paths'

class Path(models.Model):
  song = models.ForeignKey(Song)
  diff = models.ForeignKey(Difficulty)
  inst = models.ForeignKey(Instrument)
  platform = models.ForeignKey(Platform)
  settings = models.ForeignKey(PathSettings)
  score = models.PositiveIntegerField()
  img = models.ImageField(upload_to='path/img/')
  txt = models.FileField(upload_to='path/txt/')
  added = models.DateTimeField(auto_now=False, auto_now_add=True)
  updated = models.DateTimeField(auto_now=True, auto_now_add=True)
  
  def __unicode__(self):
    return ', '.join(map(str, [self.song, self.inst,
                               self.diff, self.settings,
                               self.score]))

  class Meta:
    app_label = 'paths'
