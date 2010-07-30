#!/usr/bin/python

##
# A script to use Amazon Web Services to generate paths for a batch of songs.
#
# Takes as an argument a file containing a path to a midi file on each line.
##

__author__ = "Jeremy Sharpe"
__copyright__ = "Copyright 2010, Jeremy Sharpe"

# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import Song, Game
import os
import shutil
import sys
from datetime import datetime
import time
import urllib
import re
import pexpect
import random
from auth import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, KEY_NAME
from boto.ec2.connection import EC2Connection

SSH_OPTS = '-i ./key/' + KEY_NAME + '.pem'
#---------------------------------------

# Timestamp to mark the current bechmark run
TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")

# Name of the image that should be used
# Fedora 32-bit with svn/java/perl modules
IMAGE = 'ami-3a9a7753'
# Instance type that should be used
INSTANCE_TYPE = 'c1.medium'

##
# Runs the selected midis on the given image and instance type
# - conn is an EC2Connection
# - midis is a list of paths to midis
#
def run_paths(conn):
  print "Starting the instance"
  reservation = conn.run_instances(IMAGE, instance_type=INSTANCE_TYPE, key_name=KEY_NAME,
                                   security_groups=['ssh'])
  instance = reservation.instances[0]
 
  time.sleep(10)
  while not instance.update() == 'running':
    time.sleep(5)
 
  print "Started the instance: %s..." % instance.dns_name
 
  # sleep a bit more, just to make sure the instance is ready to run
  print "Started up - pausing for 30 seconds to make sure..."
  time.sleep(30)

  songs_used = []
  try:
    # Do initial ssh to authenticate shit
    ssh_command = "ssh %s root@%s" % (SSH_OPTS, instance.dns_name)
    print ssh_command
    tries = 0
    while tries < 5:
      try:
        child = pexpect.spawn(ssh_command)
        child.expect('Are you sure you want to continue connecting (yes/no)?')
        child.sendline('yes')
        child.expect('.*')
        child.close()
        break
      except pexpect.TIMEOUT:
        print "Timed out, waiting 10 seconds and trying again..."
      except pexpect.EOF:
        print "Something went wrong, waiting 10 seconds and trying again..."
      time.sleep(10)
      tries = tries + 1

    # update svn so we're running on the latest code
    svn_command = "cd odopt && svn update"
    os.system("ssh %s root@%s \"%s\"" % (SSH_OPTS, instance.dns_name, svn_command))

    print "Running paths"

    # Makes list of mids
    mid_dir = 'mid_folder%d' % int(time.time())
    remote_mid_dir = 'mid_folder'
    mid_list = 'mid_list%d' % int(time.time())
    remote_mid_list = 'mid_list'      
    while 1:
      try:
        os.makedirs(mid_dir)
        break
      except:
        time.sleep(random.randint(5, 30))
        mid_list = 'mid_list%d' % int(time.time())
        mid_dir = 'mid_folder%d' % int(time.time())
    
    while 1:
      try:
        mid_list_file = open(mid_list, 'w')
        break
      except:
        time.sleep(random.randint(5, 30))
        mid_list = 'mid_list%d' % int(time.time())

    for song in Song.objects.filter(path_genning=0).order_by('mid_name')[:1]:
      song.path_genning = 1
      song.save()
      songs_used.append(song)
      shutil.copy2(settings.MEDIA_ROOT + '/' + str(song.mid_file), mid_dir)
      mid_list_file.write("%s,%s\n" % (song.mid_name, song.game.short_name))
      print song.mid_name

    mid_list_file.close()

    # copy over dir and list
    copy_command = "scp -r %s \"%s\" root@%s:~/%s" % \
      (SSH_OPTS, mid_dir, instance.dns_name, remote_mid_dir)
    os.system(copy_command)

    copy_command = "scp %s \"%s\" root@%s:~/%s" % \
      (SSH_OPTS, mid_list, instance.dns_name, remote_mid_list)
    os.system(copy_command)

    # Copy over script that runs paths and copies around stuff
    script_file = 'runpaths'
    copy_command = "scp %s \"%s\" root@%s:~/%s" % \
      (SSH_OPTS, script_file, instance.dns_name, script_file)
    os.system(copy_command)
    perm_command = "chmod 777 ./mid_folder/* && chmod 777 ./runpaths"
    os.system("ssh %s root@%s \"%s\"" % (SSH_OPTS, instance.dns_name, perm_command))

    run_command = "./runpaths"
    os.system("ssh %s root@%s \"%s\"" % (SSH_OPTS, instance.dns_name, run_command))

  except Exception, e:
    # Try to put songs used back into pool that need paths
    for song in songs_used:
      song.path_genning = 0
      song.save()
    print e
    print "Stopping the instance on failure" 
    instance.stop()

if __name__ == '__main__':
  conn = EC2Connection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
  try:
    run_paths(conn)
  except Exception, e:
    print e
