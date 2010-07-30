///////////////////////////////////////////////////////////////////////////////
// 
// rbopt.java
//
// Optimization subroutine for rbopt.pl script. Takes a .dump file as input
// and determines where to whammy, activate OD and squeeze. Prints a .opt file
// which the script uses to output the path.
//
///////////////////////////////////////////////////////////////////////////////

import java.math.*;
import java.io.*;
import java.util.*;

public class rbopt {
  // State
  static State state;
  static Song song;
  static Actions actions;
  static Settings settings;
  static int maxScore;
  static boolean silent;

  public static void main(String[] args) throws Exception {
    Scanner s = new Scanner(new File(args[0]));
    readSettings(s);
    settings.WHAMMY_CHANGE = Integer.parseInt(args[2]);
    silent = Integer.parseInt(args[3]) == 1;
    readDump(s);
    s.close();
    state = new State(song, settings);
    optimize();
    PrintWriter p = new PrintWriter(args[1]);
    writeDump(p);
    if (args.length == 5) {
      PrintWriter p2 = new PrintWriter(args[4]);
      writeCom(p2);
    }
    p.close();
  }

  static void writeDump(PrintWriter p) {
    for(int i = 0; i < song.Values.length; i++) {
      int whammy = actions.DoWhammy[i]?1:0;
      int activate = actions.DoActivate[i]?1:0;
      int activated = actions.ODActivated[i]?1:0;

      p.println(i + " " + whammy + " " + activate + " " + actions.DoEarlyWhammy[i]
        + " " + activated + " " + actions.Score[i] + " " + actions.ODScore[i]
        + " " + actions.ODTotal[i] + " " + actions.DoSqueeze[i] + " " + actions.Squeezing[i]
        + " " + actions.DoRSqueeze[i]);
    }
  }

  // Writes a list of *commands*
  // Using this because this should not differ at all between experimental and
  // regular versions.
  static void writeCom(PrintWriter p) {
    for(int i = 0; i < song.Values.length; i++) {
      int whammy = actions.DoWhammy[i]?1:0;
      int activate = actions.DoActivate[i]?1:0;
      int activated = actions.ODActivated[i]?1:0;

      p.println(i + " " + whammy + " " + activate + " " + actions.DoEarlyWhammy[i]
        + " " + activated + " " + actions.Score[i] + " " + actions.ODScore[i]
        + " " + " " + actions.DoSqueeze[i] + " " + actions.Squeezing[i]
        + " " + actions.DoRSqueeze[i]);
    }
  }

  static void optimize() throws Exception {
    // Initialize tables
    // We only keep two columns for the score to save space. Only need two
    // because we only ever reference the one for the column after the
    // current tick's column. We'll later reconstruct the score.
    int[][][][][] ScoreT = new int[2][2][settings.WHAMMY_CHANGE+1][settings.MAX_SQUEEZE+1][settings.MAX_OD+1];

    // Each entry of PathT stores a compressed version of the path taken from
    // that point until the end of the song to obtain the optimal score from
    // that point. For this reason, we only need to store two ticks at a time.
    Path[][][][][] PathT = new Path[2][2][settings.WHAMMY_CHANGE+1][settings.MAX_SQUEEZE+1][settings.MAX_OD+1];
    for(int i = 0; i < 2; i++) {
      for(int j = 0; j < 2; j++) {
        for(int k = 0; k < settings.WHAMMY_CHANGE+1; k++) {
          for(int l = 0; l < settings.MAX_SQUEEZE+1; l++) {
            for(int m = 0; m < settings.MAX_OD+1; m++) {
              PathT[i][j][k][l][m] = new Path(null);
            }
          }
        }
      }
    }

    boolean[] conds = new boolean[6];
    int[] squeezeAmount = new int[6];
    boolean[] actarr = new boolean[6];
    actarr[0] = actarr[1] = false;
    actarr[2] = actarr[3] = true;
    actarr[4] = actarr[5] = false;
    boolean[] whamarr = new boolean[6];
    whamarr[0] = whamarr[2] = true;
    whamarr[1] = whamarr[3] = false;
    whamarr[4] = whamarr[5] = false;
    int[] order = new int[6];

    // Progress bar stuff
    int longest = 0;
    // Should update about once per percent. Don't want to update too often to save
    // resources and not flicker, but don't want to update too little or it seems
    // jerky.
    int updateinterval = song.Values.length / 100;
    Date curTime = new Date();
    long inittime = curTime.getTime();

    // The main DP loop.
    // tick is the number of the CURRENT tick.
    for(int tick = song.Values.length-1; tick >= 0; tick--) {
      
      if(!silent) {
        // Progress bar stuff
        if(tick % updateinterval == 0 || longest == 0) {
          // Overwrite the last printed statement
          for(int i = 0; i < longest; i++) {
            System.out.print("\b");
          }
          int percent = (int) (100.0 * (double) (song.Values.length - tick) / (double) song.Values.length);
          String msg = "% Complete - Estimated time remaining ";
          String timerem;
          // Calculate time remaining
          Date tickTime = new Date();
          long diffTime = tickTime.getTime() - inittime;
          diffTime = (long) (((double) tick / (double) (song.Values.length - tick)) * diffTime);
          int hour = 3600000;
          int minute = 60000;
          int second = 1000;
          long hours = diffTime / hour;
          diffTime -= hours * hour;
          long minutes = diffTime / minute;
          diffTime -= minutes * minute;
          long seconds = diffTime / second;
          diffTime -= seconds * second;
          timerem = new Formatter().format("%02d:%02d:%02d", hours, minutes, seconds).toString();
          System.out.print(percent + msg + timerem);
          int length = Integer.toString(percent).length() + msg.length() + timerem.length();
          for(int i = 0; i < longest - length; i++) {
            System.out.print(" ");
          }
          longest = Math.max(length, longest);
          if(tick == 0) {
            System.out.println();
          }
        }
        // End of progress bar stuff
      }

      // OD is the amount of OD that we have on the CURRENT tick.
      for(int OD = 0; OD <= settings.MAX_OD; OD++) {
        // act is whether we were activated at the END of the PREVIOUS tick.
        // That is, we may have received points for an activation on the
        // previous tick, but had OD = 0, so it ran out.
        // Conversely, we may have NOT earned points for an activation on the
        // previous tick, but have squeeze -> 0, starting an activation on this
        // tick.
        for(int act = 0; act <= 1; act++) {
          // Do some quick elimination of cases in order to cut down
          // run time significantly. You cannot possible be squeezing
          // if you are not activated and you have less than the OD
          // necessary for an activation (but more than 0).
          byte squeezemax;
          byte rsqueezemax = 0;
          boolean canrbacksqueeze = (act == 1 && OD > 0 && OD <= song.ODUses[tick]*song.FrontSqueezeOD[tick] && OD > song.ODUses[tick] && !song.Sustain[tick]);
          if(OD >= settings.OD_ACTIVATE && act == 0) {
            squeezemax = song.FrontSqueezeOD[tick];
            rsqueezemax = song.BackSqueezeOD[tick];
          } else if(OD == 0) {
            squeezemax = song.BackSqueezeOD[tick];
          } else {
            squeezemax = 0;
          }

          if (canrbacksqueeze) {
            int intm1 = OD / song.ODUses[tick];
            int intm2 = OD % song.ODUses[tick];
            rsqueezemax = (byte)(intm1 - (intm2 == 0 ? 1 : 0));
          }

          for(int squeeze = 0; squeeze <= squeezemax; squeeze++) {
            for(int wuse = 0; wuse <= settings.WHAMMY_CHANGE; wuse++) {
              // Maximize scoreC across all possible actions on this tick.
              int scoreC = -1;
              boolean whammyC = false;
              boolean activateC = false;
              byte earlyC = 0;
              byte squeezeC = 0;
              byte rSqueezeC = 0;
              Path pathC = new Path(null);

              // Fills the condition array with boolean indicating whether each set of actions is possible.
              // not activating + whammy
              conds[0] = song.Sustain[tick] && song.InOD[tick] && song.Whammyable[tick];
              // not activating + no whammy
              conds[1] = !(song.Sustain[tick] && song.InOD[tick]) || (song.Sustain[tick] && song.InOD[tick] && wuse <= 1);
              // activating + whammy
              conds[2] = song.InOD[tick] && song.Sustain[tick] && OD >= settings.OD_ACTIVATE && !(act == 1) && squeeze == 0 && song.Whammyable[tick];
              // activating + no whammy
              conds[3] = OD >= settings.OD_ACTIVATE && act != 1 && wuse <= 1 && squeeze == 0;
              // squeezing implies no whammy, not activating
              // squeezing (at start of activation)
              conds[4] = squeeze == 0 && OD >= settings.OD_ACTIVATE && act != 1 && song.Note[tick];
              // squeezing (at end of activation)
              conds[5] = squeeze == 0 && OD == 0 && act == 1 && wuse <= 1;

              // The order that the actions are attempted in. Earlier ones will
              // have precedence, all else being equal.
              if(song.Note[tick]) {
                // If on a note, then try activating first, then try squeezing.
                // Also do whammy first
                order[0] = 2;
                order[1] = 3;
                order[2] = 4;
                order[3] = 0;
                order[4] = 1;
              } else {
                // If not on a note, then try not activating, then try activating, then
                // try squeezing.
                // Also do whammy first.
                order[0] = 0;
                order[1] = 1;
                order[2] = 2;
                order[3] = 3;
                order[4] = 4;
              }
              order[5] = 5;
              
              for(int i = 0; i < order.length; i++) {
                int maxEarly = song.EarlyWhammyOD[tick];
                if (!whamarr[order[i]]) {
                  maxEarly = 0;
                }
                for(byte early = 0; early <= maxEarly; early++) {
                  if(conds[order[i]]) {
                    byte minsqueeze = 0;
                    byte trysqueeze = 0;
                    if(order[i] == 4 || order[i] == 5) {
                      minsqueeze = 1;
                      trysqueeze = squeezemax;
                    }
                    for(byte toSqueeze = minsqueeze; toSqueeze <= trysqueeze; toSqueeze++) {
                      // Allow player to drop small amounts of OD
                      byte minrsqueeze = 0;
                      byte tryrsqueeze = 0;
                      int increment = 1;
                      if (toSqueeze == 0) {
                        if (actarr[order[i]]) { // Reverse squeeze front of activation
                          tryrsqueeze = rsqueezemax;
                        } else if (canrbacksqueeze && early == 0) { // Reverse squeeze end of activation, but CAN'T do this if early whammying this tick too.
                          tryrsqueeze = rsqueezemax;
                          increment = tryrsqueeze;
                        }
                      }
                      for (byte toRSqueeze = minrsqueeze; toRSqueeze <= tryrsqueeze; toRSqueeze += increment) {
                        state.tick = tick;
                        state.OD = OD;
                        state.activated = act;
                        state.wuse = wuse;
                        state.squeeze = squeeze;
                        state.nowSqueezing = squeeze > 0;
                        state.ODScore = 0;
                        state.score = 0;
                        state.nextState(actarr[order[i]], whamarr[order[i]], early, toSqueeze, toRSqueeze);
                        int points = state.ODScore + ScoreT[state.activated][state.tick%2][state.wuse][state.squeeze][state.OD];
                        if(points > scoreC) {
                          scoreC = points;
                          whammyC = whamarr[order[i]];
                          activateC = actarr[order[i]];
                          earlyC = early;
                          squeezeC = toSqueeze;
                          rSqueezeC = toRSqueeze;
                          pathC = PathT[state.activated][state.tick%2][state.wuse][state.squeeze][state.OD];
                        }
                      }
                    }
                  }
                }
              }

              ///////////////////////
              // Fill in DP tables //
              ///////////////////////

              // The maximum score obtainable from this point onwards,
              // including the CURRENT tick.
              ScoreT[act][tick%2][wuse][squeeze][OD] = scoreC;
              // Print out debug information indicating the score that
              // the optimization phase believes to be optimal.
              if(tick == 0 && act == 0 && OD == 0 && wuse == 0 && squeeze == 0) {
                maxScore = scoreC;
              }
              PathT[act][tick%2][wuse][squeeze][OD].addAction(tick, whammyC, activateC, earlyC, squeezeC, rSqueezeC, song.Sustain[tick], song.InOD[tick], pathC);
            }
          }
        }
      }
    }

    for(int tick = 0; tick < song.Values.length; tick++) {
      if(song.Sustain[tick] && song.InOD[tick]) {
        actions.DoWhammy[tick] = true;
      } else {
        actions.DoWhammy[tick] = false;
      }
      actions.DoActivate[tick] = false;
      actions.DoEarlyWhammy[tick] = 0;
      actions.DoSqueeze[tick] = 0;
      actions.DoRSqueeze[tick] = 0;
    }
    Path path = PathT[0][0][0][0][0];
    while(true) {
      Action action = path.getAction();
      if(action == null) break; 
      actions.DoWhammy[action.tick] = action.whammy;
      actions.DoActivate[action.tick] = action.activate;
      actions.DoEarlyWhammy[action.tick] = action.earlyWhammy;
      actions.DoSqueeze[action.tick] = action.squeeze;
      actions.DoRSqueeze[action.tick] = action.rsqueeze;
    }

    // Gather the path
    // Need to fill in Score, ODScore, ODTotal, DoWhammy, DoActivate, ODActivated arrays
    // Remember, table indexed:
    // 1: activated on the previous tick
    // 3: tick number
    // 3: OD amount
    state.tick = 0;
    state.OD = 0;
    state.score = 0;
    state.ODScore = 0;
    state.wuse = 0;
    state.activated = 0;
    for(int tick = 0; tick < song.Values.length; tick++) {
      //System.out.println(new Integer(state.tick).toString() + ", " + new Integer(state.wuse).toString());
      // Update state
      state.nextState(actions.DoActivate[tick], actions.DoWhammy[tick], actions.DoEarlyWhammy[tick], actions.DoSqueeze[tick], actions.DoRSqueeze[tick]);

      actions.ODTotal[tick] = state.OD;
      actions.Squeezing[tick] = state.squeeze;

      actions.ODActivated[tick] = state.nowActivated == 1;

      actions.ODScore[tick] = state.ODScore;
      actions.Score[tick] = state.score;
    }

    // Print out debug information indicating the score that the
    // reconstruction phase believes to be optimal. MUST MATCH the
    // score printed by the optimization phase OR SOMETHING IS WRONG -
    // either the optimization is filling in a table incorrectly or
    // the path is being incorrectly reconstructed, PROBABLY THE LATTER.
    int calcMax = actions.ODScore[actions.Score.length-1];
    if(calcMax != maxScore) {
      System.err.println("Reconstruction says max score is " +
                         calcMax + " but it should be " + maxScore);
    }
  }

  static void readDump(Scanner s) {
    // Get the number of ticks
    int size = s.nextInt();
    song = new Song(size);
    actions = new Actions(size);

    // Collect ticks data
    for(int i = 0; i < size; i++) {
      try {
      song.Note[i] = (s.nextInt() != 0);
      song.Sustain[i] = (s.nextInt() != 0);
      song.InOD[i] = (s.nextInt() != 0);
      song.EndOD[i] = (s.nextInt() != 0);
      song.SoloBonuses[i] = s.nextInt();
      song.Whammy[i] = (s.nextInt() != 0);
      song.WhammyOD[i] = s.nextInt();
      s.nextDouble(); // Value here only useful for path output, realwhammy
      song.Whammyable[i] = (s.nextInt() != 0);
      song.Fill[i] = (s.nextInt() != 0);
      song.FillBonus[i] = s.nextInt();
      song.ODUses[i] = s.nextInt();
      song.Mults[i] = s.nextInt();
      song.ticksToEndOfSustain[i] = s.nextInt();
      song.Values[i] = s.nextInt();
      song.SusVals[i] = s.nextInt();
      song.NoteVals[i] = s.nextInt();
      song.FrontSqueezeOD[i] = (byte)s.nextInt();
      s.nextInt();
      song.BackSqueezeOD[i] = (byte)s.nextInt();
      s.nextInt();
      song.EarlyWhammyOD[i] = s.nextInt();
      s.nextInt();
      song.WhammyChange[i] = s.nextInt();
      s.nextInt();
      for (int j = 0; j < 7; j++) {
        s.nextInt();
      }

      for (int j = 0; j <= song.EarlyWhammyOD[i]; j++) {
        song.EarlyWhammyODAmount[i][j] = s.nextInt();
      }
      } catch(Exception e) {
        System.err.println(i);
        System.exit(0);
      }
    }
  }

  static void readSettings(Scanner s) {
    settings = new Settings();
    settings.WHAMMY_PER_TICK = s.nextInt();
    settings.OD_MULT = s.nextInt();
    settings.OD_PHRASE_VALUE = s.nextInt();
    settings.OD_ACTIVATE = s.nextInt();
    settings.MAX_OD = s.nextInt();
    settings.MAX_SQUEEZE = s.nextInt();
    settings.VERBOSE = (s.nextInt() == 1);
    s.nextInt();
    s.nextInt();
    s.nextInt();
  }
}

class ActionList {
  ActionList rest;
  Action head;
  ActionList(Action head, ActionList rest) {
    this.head = head;
    this.rest = rest;
  }
}

class Path {
  Path(ActionList actionList) {
    this.actionList = actionList;
  }

  void addAction(int tick, boolean whammy, boolean activate, byte earlyWhammy, byte squeeze, byte rsqueeze, boolean sustain, boolean inOD, Path rest) {
    if((!whammy && sustain && inOD) ||
       activate ||
       earlyWhammy != 0 ||
       squeeze != 0 ||
       rsqueeze != 0) {
      actionList = new ActionList(new Action(tick, whammy, activate, earlyWhammy, squeeze, rsqueeze), rest.actionList);
    } else {
      actionList = rest.actionList;
    }
  }
  
  Action getAction() {
    Action ret = null;
    if(actionList != null) {
      ret = actionList.head;
      actionList = actionList.rest;
    }
    return ret;
  }
  
  ActionList actionList;
}

class Action {
  int tick;
  boolean whammy;
  boolean activate;
  byte earlyWhammy;
  byte squeeze;
  byte rsqueeze;

  Action(int tick, boolean whammy, boolean activate, byte earlyWhammy, byte squeeze, byte rsqueeze) {
    this.tick = tick;
    this.whammy = whammy;
    this.activate = activate;
    this.earlyWhammy = earlyWhammy;
    this.squeeze = squeeze;
    this.rsqueeze = rsqueeze;
  }
}

// Contains the actions that the player must perform to obtain the optimal
// score.
class Actions {
  // Tick arrays to be filled.
  static boolean[] DoWhammy;
  static boolean[] DoActivate;
  static int[] DoEarlyWhammy;
  static int[] DoSqueeze;
  static int[] DoRSqueeze;
  static int[] Squeezing;
  static boolean[] ODActivated;
  static int[] Score;
  static int[] ODScore;
  static int[] ODTotal;

  Actions(int size) {
    // Initialize these but don't populate them yet.
    DoWhammy = new boolean[size];
    DoActivate = new boolean[size];
    DoEarlyWhammy = new int[size];
    DoSqueeze = new int[size];
    DoRSqueeze = new int[size];
    Squeezing = new int[size];
    ODActivated = new boolean[size];
    Score = new int[size];
    ODScore = new int[size];
    ODTotal = new int[size];
  }
}

// Contains the processed song's settings. It is simply a container so
// that State can access it.
class Song {
  // Tick arrays to be gathered.
  static boolean[] Note;
  static boolean[] Sustain;
  static boolean[] InOD;
  static boolean[] EndOD;
  static int[] SoloBonuses;
  static boolean[] Whammy;
  static int[] WhammyOD;
  static boolean[] Whammyable;
  static boolean[] Fill;
  static int[] FillBonus;
  static int[] ODUses;
  static int[] Mults;
  static int[] ticksToEndOfSustain;
  static int[] Values;
  static int[] SusVals;
  static int[] NoteVals;
  static byte[] FrontSqueezeOD;
  static byte[] BackSqueezeOD;
  static int[] EarlyWhammyOD;
  static int[][] EarlyWhammyODAmount;
  static int[] WhammyChange;

  Song(int size) {
    // Initialize ticks arrays
    Note = new boolean[size];
    Sustain = new boolean[size];
    InOD = new boolean[size];
    EndOD = new boolean[size];
    SoloBonuses = new int[size];
    Whammy = new boolean[size];
    WhammyOD = new int[size];
    Whammyable = new boolean[size];
    Fill = new boolean[size];
    FillBonus = new int[size];
    ODUses = new int[size];
    Mults = new int[size];
    ticksToEndOfSustain = new int[size];
    Values = new int[size];
    SusVals = new int[size];
    NoteVals = new int[size];
    FrontSqueezeOD = new byte[size];
    BackSqueezeOD = new byte[size];
    EarlyWhammyOD = new int[size];
    EarlyWhammyODAmount = new int[size][10];
    WhammyChange = new int[size];
  }
}

// Contains the song's settings
class Settings {
  // Settings
  static int WHAMMY_PER_TICK;
  static int OD_MULT;
  static int OD_PHRASE_VALUE;
  static int OD_ACTIVATE;
  static int MAX_OD;
  static int MAX_SQUEEZE;
  static boolean VERBOSE;
  static int WHAMMY_CHANGE = 0;
}

// This class represents the current state and calculates the next state
// given certain actions.
class State {

  // Information
  static private Song song;
  static private Settings settings;

  // Current parameters.
  static int tick;
  // activated on the current tick?
  static int nowActivated;
  static boolean nowSqueezing;
  static boolean activatedThisTick;
  // activated at END of current tick?
  static int activated;
  static int OD;
  static int wuse;
  static int squeeze;
  static int score;
  static int ODScore;

  // Public methods
  State(Song song, Settings settings) {
    tick = 0;
    OD = 0;
    wuse = 0;
    squeeze = 0;
    activated = 0;
    score = 0;
    ODScore = 0;
    nowSqueezing = false;
    this.song = song;
    this.settings = settings;
  }

  // Advances the state's parameters to their next values according
  // to the actions specified and the position in the song.
  public static void nextState(boolean activate, boolean whammy, int early, int squeeze, int rsqueeze) {
    // set wuse, doesn't depend on anything but the whammy parameter.
    if (settings.WHAMMY_CHANGE > 0) {
      setWuse(whammy, early);
    }

    // set activated (also sets squeeze)
    setActivated(activate, squeeze);

    // set OD
    setOD(whammy, early, rsqueeze);

    // set score and ODScore
    setScore();

    // Increment tick number
    tick++;
  }

  // If nowSqueezing and this.squeeze -> 0 and OD >= OD_ACTIVATE, then start an
  // activation and stop squeezing. Decrement this.squeeze.
  // If nowSqueezing and this.squeeze -> 0 and OD == 0, then 
  private static void setActivated(boolean activate, int squeeze) {
    // Squeezing
    if(squeeze > 0) {
      State.squeeze = squeeze;
      nowSqueezing = true;
    } else if(State.squeeze > 0) {
      State.squeeze--;
      if(State.squeeze == 0) {
        if(OD >= settings.OD_ACTIVATE) {
          activate = true;
        }
        nowSqueezing = false;
      }
    }
    
    // Activating
    boolean act = activated == 1;
    if(activate) {
      activated = 1;
    } else if(OD == 0) {
      activated = 0;
    }
    nowActivated = activated;
    // Uncomment this for 1-tick extra of activation.
    /*if(OD == 0 && act) {
      nowActivated = 1;
    }*/
  }

  private static void setOD(boolean whammy, int early, int rsqueeze) {
    deltaOD(whammy, activated==1, early, rsqueeze, tick);
    // Kind of hackish for this to go here, but have to set activated before OD
    // so in this exceptional circumstance it falls to this function to deal
    // with it.
    if (nowSqueezing && OD < settings.OD_ACTIVATE && OD > 0) {
      nowActivated = 1;
      nowSqueezing = false;
      squeeze = 0;
      OD -= song.FrontSqueezeOD[tick] * song.ODUses[tick];
      OD = Math.max(0, OD);
    }
    if(nowActivated == 1 && OD > 0) {
      activated = 1;
    }
  }

  private static void setScore() {
    int extraScore = song.SoloBonuses[tick] + song.FillBonus[tick];
    int addScore = song.Values[tick] * song.Mults[tick];
    // Receive extra points if currently activated OR squeezing
    if(nowActivated == 1 || (nowSqueezing && OD >= settings.OD_ACTIVATE)) {
      ODScore += settings.OD_MULT * addScore + extraScore;
    } else if(nowSqueezing) {
      ODScore += (settings.OD_MULT * song.NoteVals[tick] + song.SusVals[tick]) * song.Mults[tick] + extraScore;
    } else {
      ODScore += addScore + extraScore;
    }
    score += addScore + extraScore;
  }

  // Sets wuse (whammy use) parameter given whammy.
  private static void setWuse(boolean whammy, int early) {
    if (whammy || early > 0) {
      if (wuse == 0) {
        wuse = song.WhammyChange[tick];
      } else {
        wuse = Math.max(1, wuse - 1);
      }
    } else {
      wuse = 0;
    }
  }

  // Input the current OD, the action, and get the new OD after this tick.
  private static void deltaOD(boolean whammy, boolean activated, int early, int rsqueeze, int tick) {
    // Take away OD if activated.
    if(activated) {
      OD -= song.ODUses[tick];
    }
    // Add OD for whammy
    if(whammy && song.Sustain[tick] && song.InOD[tick] && !(squeeze > 0 && OD >= settings.OD_ACTIVATE)) {
      //OD += settings.WHAMMY_PER_TICK;
      OD += song.WhammyOD[tick];
    }
    // Give points for completing an OD phrase.
    if(song.EndOD[tick]) {
      OD += settings.OD_PHRASE_VALUE;
    }
    // Give early whammy. Checking conditions has already been done.
    //OD += early * settings.WHAMMY_PER_TICK;
    OD += song.EarlyWhammyODAmount[tick][early];
    // Take reverse squeeze OD.
    OD -= rsqueeze * settings.WHAMMY_PER_TICK;

    // Minimum OD is 0, max is MAX_OD
    OD = (int)Math.max(0, OD);
    OD = (int)Math.min(settings.MAX_OD, OD);
  }
}
