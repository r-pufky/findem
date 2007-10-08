#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Formatting / retrieval engine for Findem 2.0
# Copyright 2007, Robert Pufky
#
import urllib
import HTMLParser
import string
import sys
import optparse
import os

alphabet_map = {'a':1,'b':2,'c':3,'d':4,'e':5,'f':6,'g':7,'h':8,'i':9,'j':10,
                'k':11,'l':12,'m':13,'n':14,'o':15,'p':16,'q':17,'r':18,'s':19,
                't':20,'u':21,'v':22,'w':23,'x':24,'y':25,'x':26}

# The word subsititution dictionary
replace_map = {"alwayz":"always",
			   "aint":"ain't",
               "b":"be",
			   "cause":"'cause","cuz":"'cause","coz":"'cause",
			   "didnt":"didn't",
			   "dont":"don't",
			   "eva":"ever",
			   "fa":"for",
			   "i":"I",
               "i'd":"I'd",
               "ill":"I'll","i'll":"I'll",
			   "im":"I'm","i'm":"I'm",
			   "ima":"I'ma","i'ma":"I'ma",
               "i've":"I've",
			   "lov":"love","luv":"love",
			   "n":"and",
			   "nite":"night",
			   "rite":"right",
			   "sho":"sure",
			   "tellin":"telling",
			   "thats":"that's","thas":"that's",
			   "theres":"there's",
			   "ur":"you're",
			   "u":"you",
			   "wit":"with",
			   "yall":"y'all",
			   "yellin":"yelling",
			   "youll":"you'll"}

# any matches in here will be completely removed
replace_remove_all = [".",'"',"É"]
                
cache_dir = "/tmp/"

# Create a wrapper class for stripping html tags
class StripTags(HTMLParser.HTMLParser):
  def __init__(self):
    # reset and clear feed string 
    self.reset()
    self.fed = []
  def handle_data(self,d):
    # set feed data to string passed
    self.fed.append(d)
  def get_fed_data(self):
    # return processed results
    return "".join(self.fed)



def cleanLine(line):
  """ This will clean the specified line, applying the replacement maps to the
  line.
  
  Args:
    string - the line to process
  Returns: 
    string - the processed line
  """
  for search in replace_remove_all:
    line = line.replace(search,"")
  
  line_tokens = string.split(line.lower())
  processed_tokens = []
  
  for x,token in enumerate(line_tokens):
	if token[0] == "(":
	  token = "(" + (map_token_replacements(token[1:])).capitalize()
	if token[0] == "'":
	  token = map_token_replacements(token[1:])
	# only continue if we have something left
	if len(token) > 0:
	  if token[-1] == ")":
	    token = map_token_replacements(token[:-1]) + ")"
	  if token[-1] == ",":
	    token = map_token_replacements(token[:-1]) + ","
	  if token[-1] == "'":
	    token = map_token_replacements(token[:-1])
	
	  token = map_token_replacements(token)
	
	  if x == 0 and token[0] != "(":
	    token = token.capitalize()

	  processed_tokens.append(token)
	
  return ' '.join(processed_tokens)
  
  
  
def map_token_replacements(token):
  """ This will apply the dictionary replacement map to the specified token
  and return that replaced value (if any).  If nothing is found, it will return
  the original token.
  
  Args:
    string - token to map replacements to
  Returns:
    string - token with replacements mapped, or original token
  """
  try:
    token = replace_map[token]
  except:
    pass

  return token



def keepCharacters(processString, charactersToKeep):
  """ This will go through the string, and only keep the characters listed in
  the 'keep character' string.  If they are not in the string, it will be
  removed.

  Returns:
    string - only the 'keep' characters
  """

  returnString = ""

  for i in range(len(processString)):
    if processString[i] in charactersToKeep:
      returnString = returnString + processString[i]

  return returnString



def getLyrics(artist, title):
  """ This will return the lyrics from a decent lyrical wesbite 
  (www.lyricsdomain.com).

  Args:
    string - the song's album artist
    string - the song's title
  Returns:
    string - formatted lyrics attached or false
  """
  
  URL = "http://www.lyricsdomain.com/" + str(alphabet_map[artist[:1].lower()]) \
        + "/" + cleanArtist(artist) + "/" + cleanSong(title) + ".html"
  
  try:
    request = urllib.urlopen(URL)
  except:
    # we can't request the page.
    return False
  else:
    page = request.read()
    # only return lyrics for actual lyric hits
    if page.count('"cnt"') == 0:
      return ""
    else:
      return cleanLyrics(page.split('<p class="cnt">',1)[1].split('</p>',1)[0])

    

def cleanLyrics(lyrics):
  """ This will 'clean' the lyrics from the website, effectively removing or
  converting the html to a plain text format.  As well as:

  - First character uppercase only
  - Capitalizing ' I '/'Im'/'I'm'
  - split the song into a list based on newlines.
  
  Args:
    string - the string of lyrics to convert
  Returns:
    list - lyrics converted from html, as well as line massaging
  """

  stripper = StripTags()
  stripper.feed(lyrics)
  
  # split into a list, and apply capitalization and text modifiers in one set
  # convert back to a \n ended string; apply formatting 3 times to catch edge
  # cases
  return string.join([cleanLine(line) for line in stripper.get_fed_data().split("\n")],"\n")
  


def cleanArtist(artist):
  """ This will 'clean' the artist name and convert it to the style used on 
  lyricsdomain, returning a string that is able to be used in url building.

  Formatting:  
  all lower case
  spaces -> _
  all non-alphabetic characters removed: & * - ' , ? ... etc
  -> for all intents and purposes, this includs "and" in the artist
    (i.e. k-ci and jojo -> k-ci & jojo -> kci_jojo)
  any non-ascii characters are removed
      
  Args:
    string - the album artist name
  Returns:
    string - the converted / cleaned artist name
  """

  # lowercase, strip leading/trailing whitespace, remove optional 'and', 
  #remove double spaces, keep only legal characters
  artist = keepCharacters( ( (artist.lower().strip()).replace(" and "," ") ).replace("  "," "),string.ascii_letters+string.digits+" ")
  
  # return artist removing any extra space from deletion, translate spaces to _
  return (artist.replace("  "," ")).replace(" ","_")
 


def cleanSong(title):
  """ This will 'clean' the song title and convert it to the style used on 
  lyricsdomain, returning a string that is able to be used in url building.

  Formatting:  
  all lower case
  spaces -> _
  () allowed
  all non-alphabetic characters removed: & * - ' , ? ... etc
  any non-ascii characters are removed
    
  Args:
    string - the song title
  Returns:
    string - the converted / cleaned title name
  """

  # lowercase, strip leading/trailing whitespace, remove optional 'and', 
  # remove double spaces, keep only legal characters
  title = keepCharacters( (title.lower().strip()).replace("  "," "),string.ascii_letters+string.digits+" ")
  
  # return artist removing any extra space from deletion, translate spaces to _
  return (title.replace("  "," ")).replace(" ","_")



def parseArgs(arguments):
  """ Parse script arguments
  
  Args:
    arguments - python arguments object to parse
  Returns:
    opts - the options object
  """
  
  parser = optparse.OptionParser()
  parser.add_option("-d","--databaseid",help="database id of the file to lookup")
  parser.add_option("-f","--format",action="store_true",dest="format",
                    help="formats a given set of lyrics")
  
  (opts, args) = parser.parse_args(arguments)
  
  if opts.format and not os.path.isfile(cache_dir + str(opts.databaseid) + ".lyrics"):
    parser.error("database ID must be specified")
  if not opts.format and not os.path.isfile(cache_dir + str(opts.databaseid) + ".lyrics.control"):
    parser.error("a control file was not specified for web lookup")
    
  return opts



def readFile(database_id,extension):
  """ Loads and returns list from a file specified by database id and extension
  
  (control = lyrics.control, lyrics = .lyrics)
  
  This takes care of all file opening / closing
  
  Args:
    integer - the database id of the lyrics file to load
    string - extension to use
  Returns:
    list - of all the lines in the lyrics file
  """
  file_handle = open(cache_dir + database_id + extension,"rU")
  file_contents = file_handle.readlines()
  file_handle.close()
  
  return file_contents



def writeLyricsCache(database_id, lyrics):
  """ Writes lyrics to a file
  
  This takes care of all file opening / closing
  
  Args:
    integer - the database id of the song
    string - the lyrics to be written
  Returns:
    boolean - true if success
  """
  file_handle = open(cache_dir + database_id + ".lyrics","w")
  if not file_handle.write(lyrics):
    return False
  if not file_handle.close():
    return False
    
  return True
  
  

def main():
  opts = parseArgs(sys.argv)

  # resolve only if not in cache
  if not opts.format and not os.path.isfile(cache_dir + opts.databaseid + ".lyrics"):
    song_info = readFile(opts.databaseid,".lyrics.control")
    formatted_lyrics = getLyrics(song_info[0],song_info[1])
  else:
    formatted_lyrics = cleanLyrics(string.join(readFile(opts.databaseid,".lyrics")))

  writeLyricsCache(opts.databaseid,formatted_lyrics)
  print formatted_lyrics
  


if __name__ == "__main__":
  main()
