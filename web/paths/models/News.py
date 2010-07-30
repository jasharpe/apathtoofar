from django.db import models
from django.contrib.auth.models import User

###
# News models - represent objects for the front page news
###

class NewsPost(models.Model):
  pub_date = models.DateTimeField(auto_now=False, auto_now_add=True)
  edit_date = models.DateTimeField(auto_now=True, auto_now_add=True)
  author = models.ForeignKey(User)
  title = models.CharField(max_length=200)
  body = models.TextField()

  def comments(self):
    return NewsComment.objects.filter(post=self)

  def __unicode__(self):
    return self.title

  class Meta:
    app_label = 'paths'

class NewsComment(models.Model):
  post = models.ForeignKey(NewsPost)
  author = models.ForeignKey(User)
  pub_date = models.DateTimeField(auto_now=False, auto_now_add=True)
  body = models.TextField()

  def __unicode__(self):
    return self.body

  class Meta:
    app_label = 'paths'
