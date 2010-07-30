from django.db import models
from django.contrib.auth.models import User

###
# Faq models - represent objects for the FAQ page
###

class FaqEntry(models.Model):
  pub_date = models.DateTimeField(auto_now=False, auto_now_add=True)
  edit_date = models.DateTimeField(auto_now=True, auto_now_add=True)
  author = models.ForeignKey(User)
  title = models.CharField(max_length=200)
  body = models.TextField()
  yindex = models.IntegerField()
  
  def __unicode__(self):
    return self.title
  
  class Meta:
    app_label = 'paths'

class FaqComment(models.Model):
  post = models.ForeignKey(FaqEntry)
  author = models.ForeignKey(User)
  pub_date = models.DateTimeField(auto_now=False, auto_now_add=True)
  body = models.TextField()
  
  def __unicode__(self):
    return self.body
  
  class Meta:
    app_label = 'paths'
