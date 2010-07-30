import urllib

def download(url, file, binary=0):
  """Copy the contents of a file from a given URL
  to a local file.
  """
  webFile = urllib.urlopen(url)
  if binary:
    localFile = open(file, 'wb')
  else:
    localFile = open(file, 'w')
  localFile.write(webFile.read())
  webFile.close()
  localFile.close()
