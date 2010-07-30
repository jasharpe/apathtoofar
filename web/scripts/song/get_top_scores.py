# sweet little python web scraper gizmod
from scrapemark import scrape
from datetime import datetime

# scorehero url base for the scores page
scorehero_url_base = 'http://rockband.scorehero.com/top_scores.php'

# some constants that scorehero uses in its urls
insts = {'guitar' : '1', 'bass' : '2'}
diffs = {'easy' : '1', 'medium' : '2', 'hard' : '3', 'expert' : '4'}
games = {'rb1' : '1', 'rb2' : '2', 'brb' : '4'}
# leaving out ps2 because it's too weird
platforms = {'xbox360' : '2', 'ps3' : '3', 'wii' : '4'}

# Goes to scorehero and gets all top scores for solo guitar and bass for
# Rock Band and Rock Band 2. Looks at PS3, Xbox 360 and Wii scores.
def get_top_scores(inst_label, diff_label, game_label):
  # dict where the keys are a tuple (game, inst, diff) and the values are a
  # list of 
  top_scores = {}
  game = games[game_label]
  inst = insts[inst_label]
  diff = diffs[diff_label]
  index_tuple = (game_label, inst_label, diff_label)
  top_scores[index_tuple] = {}
  for (platform_label, platform) in platforms.items():
    print platform_label
    url = scorehero_url_base + '?' + \
          "game=" + game + \
          "&platform=" + platform + \
          "&size=1" + \
          "&group=" + inst + \
          "&diff="  + diff
    
    # grab top scores. So easy, thanks scrapemark!
    page_top_scores = scrape(
      """
      <table>
        <table cellspacing="0" border="0">
        {*
          <tr>
            <td>{{ [top_scores].user|string }}</td>
            <td>{{ [top_scores].song|string }}</td>
            <td>{{ [top_scores].score|string }}</td>
            <td></td>
            <td></td>
            <td></td>
            <td>{{ [top_scores].timestamp|string }}</td>
          </tr>
        *}
        </table>
      </table>
      """,
      url=url)

    # massage data into a useable form, and add a platform field
    page_top_scores_dict = {}
    for top_score in page_top_scores['top_scores']:
      # get rid of comma in score (if necessary) and convert to int
      top_score['score'] = int(top_score['score'].replace(',', ''))
      # convert timestamp to datetime object
      top_score['timestamp'] = \
        datetime.strptime(top_score['timestamp'], '%b. %d, %Y, %I:%M%p')
      top_score['platform'] = platform_label
      page_top_scores_dict[top_score['song']] = top_score

    # Try to add to the true top score list (which doesn't care about
    # platform)
    for top_score in page_top_scores_dict.values():
      if top_score['song'] not in top_scores[index_tuple]:
        top_scores[index_tuple][top_score['song']] = top_score
      else:
        other_top_score = top_scores[index_tuple][top_score['song']]
        # Always take earliest acheived top score if they have equal score.
        if top_score['score'] > other_top_score['score'] or \
           (top_score['score'] == other_top_score['score'] and \
            top_score['timestamp'] < other_top_score['timestamp']):
          top_scores[index_tuple][top_score['song']] = top_score

  return top_scores
