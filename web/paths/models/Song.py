from django.db import models

###
# Song models - represent objects for the front page news
###

class Game(models.Model):
  short_name = models.CharField(max_length=50)
  long_name = models.CharField(max_length=50)
  short_long_name = models.CharField(max_length=100)
  order_index = models.IntegerField()

  def __unicode__(self):
    return self.long_name

  class Meta:
    app_label = 'paths'

# Note, the three below models are identical, but there are obvious ways in
# in which they could differ, so they'll stay separate.

class Platform(models.Model):
  short_name = models.CharField(max_length=100)
  full_name = models.CharField(max_length=100)

  def __unicode__(self):
    return self.full_name

  class Meta:
    app_label = 'paths'

class Instrument(models.Model):
  short_name = models.CharField(max_length=100)
  full_name = models.CharField(max_length=100)

  def __unicode__(self):
    return self.full_name

  class Meta:
    app_label = 'paths'

class Difficulty(models.Model):
  short_name = models.CharField(max_length=100)
  full_name = models.CharField(max_length=100)

  def __unicode__(self):
    return self.full_name

  class Meta:
    app_label = 'paths'

def song_upload_location(instance, filename):
  return 'mid/%s/%s' % (instance.game.short_name, filename)

class Song(models.Model):
  game = models.ForeignKey(Game)
  mid_name = models.CharField(max_length=100, unique=True)
  full_name = models.CharField(max_length=100)
  release = models.DateField()
  mid_file = models.FileField(upload_to=song_upload_location, blank=True)
  path_genning = models.IntegerField()
  
  def __unicode__(self):
    return ', '.join(map(unicode, [self.full_name, self.game]))
  
  class Meta:
    app_label = 'paths'

class TopScore(models.Model):
  song = models.ForeignKey(Song)
  updated = models.DateTimeField(auto_now=True, auto_now_add=True)
  user = models.CharField(max_length=100)
  score = models.PositiveIntegerField()
  date = models.DateTimeField()
  platform = models.ForeignKey(Platform)
  inst = models.ForeignKey(Instrument)
  diff = models.ForeignKey(Difficulty)

  def __unicode__(self):
    return ', '.join(map(unicode, [self.song, self.user, self.score, self.platform]))

  class Meta:
    app_label = 'paths'
