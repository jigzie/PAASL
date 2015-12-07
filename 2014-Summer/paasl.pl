#!/Usr/bin/perl -w

####### CONFIGURATION 
# From here to END CONFIGURATION are variables that you may want to
# edit to change various properties of the script from season to season.

# Dumps for the A league can be obtained via something like:
#  # http://paasl.us/Admin/DumpRegistration.cfm?SessionRegistrationID=4
# (Actual id number varies from season to season).
my $dir = "";

my $fulldata_name = "SummerSunday_2014.xls";
##NOTE: If PA residents have priority set to 1 you need a percentage allocation (zero not allowed)

#########	PA Policy Setup Start #############
my $pa_residents_have_priority = 1; #PA resident gets priority=1; no priority=0;
my $pa_percent_reqd = 30; #Percentage required for PA policy currently 36%
#########	PA Policy Setup End   #############

# The real ratings file is stored as a Google Docs spreadsheet.  The URL for jeff to access it is:
#    http://spreadsheets.google.com/a/google.com/ccc?key=p320mXC1FYKxANb2E7jeACQ&inv=jeff@google.com
#my $ratings_file ="BPlayerRatings-corrected 3.csv";
#my $ratings_file ="BP-Corrected1.csv";
my $ratings_file ="BCorrected.csv";

# The number of teams we are trying to build
my $am_teams = 6;
my $dont_care_teams = 6;
my $pm_teams = 0;
my $players_per_team = 17;

#B-Division MAX group Size
my $max_group_size = 4;

# Often some people register multiple times (argh!).  To deal with this, we
# print out a list of potential duplicate registrations (registrations with the
# same name), along with the Sporg registration id for each of the duplicated
# entries.  We then die if there are any duplicated entries (after printing
# this info).  To avoid the duplicates, enter the registration ids of the
# registrations to ignore.
my @registration_ids_to_ignore = (9046,9439);

# Sometimes people enter their group codes incorrectly and then later
# send you e-mail asking that their registration be fixed up.  You can
# use the 'group_fixups' map to map one group code to another (as in
# 'broken_group' => 'correct_group'), (and matching by name or email
# also works, as in 'name' => 'correct_group', or 'email' =>
# 'correct_group').
my %group_fixups = (
   'jnoghrey@gmail.com' => 'ducks123',
   'sofiabg89@yahoo.com' => 'cska1234',
   'edward.d.gibson@gmail.com' => 'Bitondo2',
   'sean.giese@gmail.com' => 'Bitondo2',
   'jesslynnerose@yahoo.com' => 'campos',
   'efrengarciacampos@yahoo.com' => 'campos'
   );

my %time_fixups = (
    'nfayan@gmail.com' => 'No',
    'rgardner1@gmail.com' => 'No',
    'monte.montgomery@kaipharma.com' => 'No',
    'dbereket@gmail.com' => 'No',
    'cheaadolphus@yahoo.com' => 'No',
    'sirak_brook@hotmail.com' => 'No',
    'gerard_ho@sbcglobal.net' => 'No',
    'jrowe11@hotmail.com' => 'No',
    'rene@awiwine.com' => 'No',
    'douglas.solomon@gmail.com' => 'No',
    'ahfreedman1@gmail.com' => 'No',
    'jamie_lutton@yahoo.com' => 'No',
    'aleibovich@hotmail.com' => 'No',
    'sandipgupta1@gmail.com' => 'No',
    'derekcpleung@yahoo.com' => 'No',
    'jeff@google.com' => 'AM',
    'gabriel.meza@gmail.com' => 'AM',
    'cassio_conceicao@amat.com' => 'AM',
    );

# Mapping from email to "1" if the person should not be picked to be a coordinator (for whatever reason)
my %coordinators_to_avoid = (
    # Board members actively involved in various duties already
    'jeff@google.com' => 1,   
    'greicius@stanford.edu' => 1,
    'loicv@vandereyken.com' => 1,
    'daring@yahoo.com' => 1,
    'kev-barb@pacbell.net' => 1,
    'jeffg13@gmail.com' => 1,
    'patrick.metzger@gmail.com' => 1,

    # Other misc. reasons
    'fran3x1@aol.com' => 1,  # Marco Franco: checked willing to coordinator, but did a horrible job starting the Spring 2010 season
    # Current evening coordinators
    'jonathan.nicolas@sbcglobal.net' => 1,  # Already doing evening coordinator duties

    'sandrob@stanford.edu' => 1,
    'atse@interorealestate.com' => 1,
    'robinpeatfield@yahoo.com' => 1,
    'jigziee@gmail.com' => 1
    );

##### END CONFIGURATION

# Set to > 0 for more verbose messages
my $v = 0;

my $num_teams = $am_teams + $dont_care_teams + $pm_teams;
my $num_from_wait_list = 0;
my $players_to_place = $num_teams * $players_per_team + $num_from_wait_list;

# If we're doing a mixed A/B league, we downgrade the B registrants by this number
my $skill_adjustment_for_b_players = 1;


my $original_headers = "";
my $original_players = ();

# Map from player number to full line about player
my %players = ();
my %eligible = ();   # Players eligible for placing on teams

# Mapping from level to # of players at that level
my %players_at_level = ();

my $max_skill_level = 5;
my @skill_weights = (5, 4, 1.5, 1, 0.5, 0.01);

# Mapping from group name to ';' separated list of pids in the group
my %groups = ();

my $num_players = 0;
my %fields = ();

# Mapping from $pid to team number
my %pid_to_team = ();

# Partial team assignments read from file
my %name_to_team = ();

# Mapping from team number to ';' separated list of $pids 
my %teams = ();

# Mapping from team number to player id of coordinator for team
my %chosen_coordinators = ();

# Mapping from pid to team for which they are coordinator (if they are a coordinator)
my %pid_to_coordinator = ();

# Mapping from email+name to "1" if they are pre-selected as a coordinator
my %preset_coordinators = (
);

# Some per-team stats (indexed by $team) kept up to date when players are added
my %player_count = ();
my %goalies = ();
my %coordinators = ();
my %defenders = ();
my %forwards = ();
my %total_age = ();
my %total_games = ();
my %team_strength = ();
my %team_players_at_level = ();
my $total_players_placed = 0;

for (my $team = 1; $team <= $num_teams; $team++) {
    $player_count{$team} = 0;
    $goalies{$team} = 0;
    $coordinators{$team} = 0;
    $defenders{$team} = 0;
    $forwards{$team} = 0;
    $total_age{$team} = 0;
    $team_strength{$team} = 0;
    $teams{$team} = "";
}

# Map from name or e-mail address to corrected rating
my %ratings = ();
my %ratings_info = ();

### Main program logic

# Parse arguments
my $interactive = 1;
my $automatically_place_players = 1;
while ($#ARGV >= 0 && $ARGV[0] =~ m/^-/) {
    if ($ARGV[0] =~ m/-interactive/) {
	$interactive = 1;
	shift(@ARGV);
    } elsif ($ARGV[0] =~ m/-noplace/) {
	$automatically_place_players = 0;
	shift(@ARGV);
    } else {
	die "Unknown argument: $ARGV[0]";
    }
}

# Read our input files
ReadRatings($ratings_file);
if (defined($ARGV[0])) {
    print "Reading pre-assignments from $ARGV[0]\n";
    ReadPartialTeamAssignments($ARGV[0]);
}
ReadPlayers($fulldata_name);

foreach $g (sort keys %groups) {
    printf "Group %-15s : %s\n", $g, $groups{$g};
}

# Get list of candidate players
my @players_by_skill = GetPlayersByPlacementOrder($players_to_place);
printf "Players by skill: %d\n", $#players_by_skill+1;
    

for (my $i = 0; $i <= $#players_by_skill; $i++) {
    my $pid = $players_by_skill[$i];
#    printf "Skill Place: %d %s : %d\n", $pid, Name($pid), defined($pid_to_team{$pid});
    $players_at_level{CorrectedSkill($pid)}++;
}

if ($automatically_place_players) {
    for (my $i = 0; $i <= $#players_by_skill; $i++) {
	my $pid = $players_by_skill[$i];
#	printf "Place: %s : %d\n", Name($pid), defined($pid_to_team{$pid});
	next if defined($pid_to_team{$pid});
	AssignPlayerToTeam($pid);
    }
}
    
for (my $team = 1; $team <= $num_teams; $team++) {
    ChooseCoordinators($team);
}

VerifyGroups(1);

if ($interactive) {
    InteractiveMode();
}

open(TEAMS, ">teaminfo.txt");
for (my $team = 1; $team <= $num_teams; $team++) {
    PrintTeamRoster(STDOUT, $team);
    PrintTeamRoster(TEAMS, $team);
}

PrintAllTeamsInfo(STDOUT);
PrintAllTeamsInfo(TEAMS);

PrintWaitingList(STDOUT);
PrintWaitingList(TEAMS);

PrintTimePrefs();
PrintEquipmentOrder(STDOUT);
PrintEquipmentOrder(TEAMS);
close(TEAMS);


sub InteractiveMode() {
    print STDERR "InteractiveMode!\n";
    # PrintAllTeamsInfo(STDOUT);
    while (1) {
	print "cmd> ";
	my $cmd = <STDIN>;
	$cmd =~ s/^ *//;
	chop($cmd);
	if ($cmd =~ m/^quit/) {
	    last;
	} elsif ($cmd =~ m/^stats/) {
	    PrintAllTeamsInfo(STDOUT);
	} elsif ($cmd =~ m/^help/) {
	    print "Commands:\n";
	    print "  stats    - Show overall team stats\n";
	    print "  show     - Show team rosters\n";
	    print "  quit     - Quit and save to paasl.output, etc.\n";
	    print "  waitlist - Show waiting list\n";
	    print "  show 7   - Show team roster for team 7\n";
	    print "  move <name> to <team#>  - Move player <name> to team number (e.g. 'move Jeff Dean to 2')\n";
	    print "                            (if <name> is on waiting list, this moves from wait list to that team)\n";
	    print "  swap <name> and <name>  - Swap two players (e.g. 'swap Mayfield and McClaren')\n";
	    print "  coordinator <team#> <name>  - Make <name> the coordinator for the given team)\n";
	    print "\n";
	    print "Note that for the move and swap commands, <name> can either be an exact group\n";
	    print "code, or can be a full or partial player name.\n";            
	} elsif ($cmd =~ m/^show *(\d+|)/) {
	    my $start = ($1 eq "") ? 1 : $1;
	    my $end = ($1 eq "") ? $num_teams : $1;
	    if (($1 <= $num_teams) && ($1 > 0)) {
	    	for (my $team = $start; $team <= $end; $team++) {
			PrintTeamRoster(STDOUT, $team);
	    	}
	    	if ($start != $end) {
			VerifyGroups(0);
	    	}
	    }else {
	        print "Team: $1 does NOT exists\n"
	    }
	} elsif ($cmd =~ m/^waitlist/) {
	    PrintWaitingList(STDOUT);
	} elsif ($cmd =~ m/^groups/) {
	    VerifyGroups(1);
	} elsif ($cmd =~ m/swap team (\d+) with (\d+)/) {
		my $team1 = $1;
		my $team2 = $2;
  		#print "Try to swap teams $team1 with $team2\n";
  	 	SwapTeamNumbers($team1, $team2);	
		i#print "Complete Swap teams\n";
	} elsif ($cmd =~ m/move (.*?) *to *(\d+)/) {
	    my $name = $1;
	    my $new_team = $2;
	    print "Move $name to $new_team\n";
	    my $pids = FindGroupOrPlayerByName($name);
	    print "pids: '$pids'\n";

	    if (!defined($pids)) {
		print "Player and group '$name' not found\n";
	    } else {
		my %old_to_print = ();
		my %new_to_print = ();
		my $print_waiting_list = 0;
		foreach $pid (split(/;/, $pids)) {
		    if (!defined($pid_to_team{$pid})) {
			printf "%s is currently on waiting list\n", Name($pid);
			PrintPlayerToFile(STDOUT, $pid);
			AddPlayerToTeam($pid, $new_team);
			$print_waiting_list = 1;
			$new_to_print{$new_team} = 1
		    } else {
			my $old_team = $pid_to_team{$pid};
			printf "%s is currently on team %d\n", Name($pid), $pid_to_team{$pid};
			PrintPlayerToFile(STDOUT, $pid);
			RemovePlayerFromTeam($pid, $old_team);
			AddPlayerToTeam($pid, $new_team);
			$old_to_print{$old_team} = 1;
			$new_to_print{$new_team} = 1
		    }
		}
		if ($print_waiting_list) {
		    PrintWaitingList(STDOUT);
		}
		foreach $t (keys %old_to_print) {
		    print "old: "; PrintTeamInfo(STDOUT, $t);
		}
		foreach $t (keys %new_to_print) {
		    print "new: "; PrintTeamInfo(STDOUT, $t);
		}
	    }
	    VerifyGroups(0);
	} elsif ($cmd =~ m/coord(|inator) (\d+) (.*)/) {
	    my $team = $2;
	    my $name = $3;
	    my $pid = FindPlayerByName($name);
	    if (!defined($pid)) {
		print "Player '$name' not found\n";
	    } elsif (!defined($pid_to_team{$pid}) ||
		     $pid_to_team{$pid} != $team) {
		printf "%s is not on team %d\n", Name($pid), $team;
	    } else {
		if (Coordinator($pid) == 0) {
		    printf "WARNING: %s said they were not willing to be a coordinator\n", Name($pid);
		}
		if (defined($chosen_coordinators{$team})) {
		    my $old_pid = $chosen_coordinators{$team};
		    $pid_to_coordinator{$old_pid} = undef;
		}
		$chosen_coordinators{$team} = $pid;
		$pid_to_coordinator{$pid} = $team;
	    }

	} elsif ($cmd =~ m/swap (.*?) *(and|with) *(.*)/) {
	    my $n1 = $1;
	    my $n2 = $3;
	    my $pids1 = FindGroupOrPlayerByName($n1);
	    my $pids2 = FindGroupOrPlayerByName($n2);
	    if (!defined($pids1)) {
		print "Player or group not found: $n1\n";
	    } elsif (!defined($pids2)) {
		print "Player or group not found: $n2\n";
	    } else {
		my $old_t1 = -1;
		foreach $pid1 (split(/;/, $pids1)) {
		    my $t = $pid_to_team{$pid1};
		    if ($old_t1 >= 0 && $old_t1 != $t) {
			print "Not all players for $n1 are on the same team\n";
			$old_t1 = -1;
			last;
		    }
		    $old_t1 = $t;
		}
		my $old_t2 = -1;
		foreach $pid2 (split(/;/, $pids2)) {
		    my $t = $pid_to_team{$pid2};
		    if ($old_t2 >= 0 && $old_t2 != $t) {
			print "Not all players for $n2 are on the same team\n";
			$old_t2 = -1;
			last;
		    }
		    $old_t2 = $t;
		}
		if ($old_t1 >= 0 && $old_t2 >= 0) {
		    foreach $pid1 (split(/;/, $pids1)) {
			RemovePlayerFromTeam($pid1, $old_t1);
			AddPlayerToTeam($pid1, $old_t2);
		    }
		    foreach $pid2 (split(/;/, $pids2)) {
			RemovePlayerFromTeam($pid2, $old_t2);
			AddPlayerToTeam($pid2, $old_t1);
		    }
		}

		PrintTeamRoster(STDOUT, $old_t1);
		PrintTeamRoster(STDOUT, $old_t2);
		PrintTeamInfo(STDOUT, $old_t1);
		PrintTeamInfo(STDOUT, $old_t2);
	    }
	    VerifyGroups(0);
	}
    }
}

sub PrintAllTeamsInfo {
    my $file = shift;
    for (my $team = 1; $team <= $num_teams; $team++) {
	PrintTeamInfo($file, $team);
    }
}

#Jigz: SwapTeamNumbers, if required
sub SwapTeamNumbers {
	#print "SwapTeamNumbers Called\n";
	my $team1 = shift;
	my $team2 = shift;
	my $tempTeamID = 99;
	#print "$team1: moving\n";

	my @pFirstTeam = PlayersOnTeam($team1);
    	#Empty the first Team
    	for (my $i = 0; $i <= $#pFirstTeam; $i++) {
        	my $pid = $pFirstTeam[$i];
		RemovePlayerFromTeam($pid, $team1);
        	AddPlayerToTeam($pid,$tempTeamID);
    	}	
	#print "$team2: moving\n";
	my @pSecondTeam = PlayersOnTeam($team2);
    	#Move the Second team players to team one
    	for (my $j=0; $j <= $#pSecondTeam; $j++) {
		my $pid = $pSecondTeam[$j];
		RemovePlayerFromTeam($pid, $team2);
		AddPlayerToTeam($pid, $team1);
   	 }
	#print "$team1: adjust\n";
	my @pTempTeam = PlayersOnTeam($tempTeamID);
    	#Add the First team players to old team
    	for (my $k; $k <= $#pTempTeam; $k++) {
		my $pid = $pTempTeam[$k];
		RemovePlayerFromTeam($pid, $tempTeamID);
		AddPlayerToTeam($pid, $team2);
    	}
	print "Team $team1 is NOW $team2 && $team2 is NOW $team1\n";
}

sub FindPlayerByName {
    my $name = shift;
    for (my $pid = 0; $pid < $num_players; $pid++) {
	my $n = Name($pid);
	if (($n eq $name) || ($n =~ m/$name/i)) {
	    printf "Found match for $name with $n on team %d\n", $pid_to_team{$pid};
	    return $pid;
	} elsif ($n =~ m/Steph/) { print "Name: $n\n"; }
    }
    return undef;
}

sub FindGroupOrPlayerByName {
    my $name = shift;
    if (defined($groups{$name})) {
	return $groups{$name};
    } else {
	return FindPlayerByName($name);
    }
}


my $name = "paasl.output";
# my $date_str = `date +%Y%m%d.%H:%M:%S`;
# my $name2 = "output/paasl.output.$date_str";
GenerateOutput($name);
# GenerateOutput($name2);
#Jigz: create a file open for NewPlayersEmail.csv
open(OUTFNEWPLAYERS, ">NewPlayersEmail.csv");
GenerateWebTeamList("weblist.csv");
GenerateCSV("rosters.csv",
	    "RegistrationID,team,iscoord,FirstName,LastName,goalie,EMail,HomePhone,WorkPhone,shirt,socks",
	    "RegistrationID,Team,Coordinator,First Name,Last Name,Gk,E-mail,Home Phone,Work Phone,Shirt,Socks",
	    0);
GenerateCSV("fulldata.csv", "team,ALL", "", 1);
close(OUTFNEWPLAYERS);

sub TeamForPlayer {
    my $pid = shift;
    if (defined($pid_to_team{$pid})) {
	return $pid_to_team{$pid};
    } else {
	return -1;
    }
}

sub VerifyGroups {
    my $verbose = shift;
    # Make sure that for all assigned players, any player that signed up in a group 
    # has all their groupmates on the same team
    my $error = 0;
    my %group_count = ();
    for (my $pid = 0; $pid < $num_players; $pid++) {
	my $team = TeamForPlayer($pid);
	next if ($team < 0);
	my $gname = GroupCode($pid);
	if ($gname ne "") {
	    $group_count{$gname}++;
	}
	my @x = split(/;/, GroupForPlayer($pid));
	for (my $i = 0; $i <= $#x; $i++) {
	    my $pid2 = $x[$i];
	    my $team2 = TeamForPlayer($pid2);
	    if ($team2 >= 0 && $team != $team2) {
		printf("%s Group %s : %s on %d, %s on %d\n", 
		       ($team != $team2) ? "*** " : "    ",
		       GroupCode($pid),
		       Name($pid), $team, Name($pid2), $team2);
		$error = 1;
	    }
	}
    }

    if ($verbose) {
	foreach $g (sort (keys %group_count)) {
	    printf "group : %-20s members: %d%s\n", $g, $group_count{$g},
 (($group_count{$g} == 1) ? " ** 1 member group" : "");
	}
    }
    
    
#    if ($error) { die "Groups not consistent\n"; }
}


sub GroupForPlayer {
    my $pid = shift;
    if (defined($groups{GroupCode($pid)})) {
	return $groups{GroupCode($pid)};
    } else {
	# Return a list of just this player
	return "$pid";
	
    }
}

sub AddToList {
    my $existing = shift;
    my $pid = shift;
    if (defined($existing) && $existing ne "") {
	return "$existing;$pid";
    } else {
	return "$pid";
    }
}

sub RemoveFromList {
    my $existing = shift;
    my $pid = shift;
    my @players = split(/;/, $existing);
    my @rest = ();
    for ($i = 0; $i <= $#players; $i++) {
	if ($players[$i] != $pid) {
	    push(@rest, $players[$i]);
	}
    }
    my $result = join(';', @rest);
    return $result;
}

sub PlayersOnTeam {
    my $team = shift;
    my @players = split(/;/, $teams{$team});
    return @players;
}

sub AverageNumDefendersOnTeams {
    my $total_defenders = 0;
    for (my $team = 1; $team <= $num_teams; $team++) {
	$total_defenders += $defenders{$team};
    }
    return (1.0 * $total_defenders) / $num_teams;
}

sub AverageNumForwardsOnTeams {
    my $total_defenders = 0;
    for (my $team = 1; $team <= $num_teams; $team++) {
	$total_forwards += $forwards{$team};
    }
    return (1.0 * $total_forwards) / $num_teams;
}

sub AverageGoaliesPerTeam {
    my $total_goalies = 0;
    for (my $team = 1; $team <= $num_teams; $team++) {
	$total_goalies += $goalies{$team};
    }
    return (1.0 * $total_goalies) / $num_teams;
}

sub TeamPlayersAtLevel {
    my $team = shift;
    my $level = shift;
    if (defined($team_players_at_level{"$team;$level"})) {
	return $team_players_at_level{"$team;$level"};
    } else {
	return 0;
    }
}

sub AverageAgeOnTeam {
    my $team = shift;
    if ($player_count{$team} == 0) {
	return -1;	# Ignore this factor until we've place at least one player
    } else {
	return (1.0 * $total_age{$team}) / $player_count{$team};
    }
}

sub GroupSizeForPlayer {
    my $pid = shift;
    my $g = GroupForPlayer($pid);
    my @x = split(/;/, $g);
    return $#x+1;
}

sub AverageAgeOnTeams {
    my $total = 0;
    my $cnt = 0;
    for (my $team = 1; $team <= $num_teams; $team++) {
	my $a = AverageAgeOnTeam($team);
	if ($a >= 0) {
	    $cnt++;
	    $total += $a;
	}
    }
    if ($cnt > 0) {
	return (1.0 * $total) / $cnt;
    } else {
	return 30;
    }
}

sub PosCode {
    my $pid = shift;
    my $pos = Position($pid);
    if ($pos eq "Fullback") { return "D"; }
    if ($pos eq "Forward") { return "F"; }
    if ($pos eq "Midfield") { return "M"; }
    if ($pos eq "Goalie") { return "G"; }
    if ($pos eq "Any") { return "A"; }
    die "Unknown position code: $pos";
}

sub Defender {
    my $pid = shift;
    my $pos = Position($pid);
    if ($pos eq "Fullback") { return 1.0; }
    if ($pos eq "Any" && Goalie($pid) < 1) { return 0.33; }
    return 0.0;
}

sub Forward {
    my $pid = shift;
    my $pos = Position($pid);
    if ($pos eq "Forward") { return 1.0; }
    return 0.0;
}

sub TeamType {
    my $team = shift;
    if (IsAMTeam($team)) {
	return "AM";
    } elsif (IsPMTeam($team)) {
	return "PM";
    } else {
	return "Any";
    }
}

sub IsAMTeam {
    my $team = shift;
    return ($team <= $am_teams);
}
sub IsDontCareTeam {
    my $team = shift;
    return ($team > $am_teams) && ($team <= ($am_teams + $dont_care_teams));
}
sub IsPMTeam {
    my $team = shift;
    return $team > ($am_teams + $dont_care_teams);
}

# Score team "$team" for placing player "$pid"
sub ScoreForTeam {
    my $team = shift;
    my $pid = shift;
    my $defender = Defender($pid);
    my @players = PlayersOnTeam($team);

    my $score = 1.0;
    my $time_pref = TimePref($pid);
    if (IsAMTeam($team) && $time_pref eq "PM") {
	# Afternoon player and morning team
	return -1;
    } elsif (IsAMTeam($team) && $time_pref ne "AM") {
	# Anytime player and morning time.  Slightly bad, but not as bad as AM/PM mismatch
	$score *= 0.01;
    } elsif (IsPMTeam($team) && $time_pref ne "PM") {
	# Morning player and afternoon team
	return -1;
    } elsif (IsDontCareTeam($team) && (($time_pref eq "AM") || ($time_pref eq "PM"))) {
	# Don't care team, and player has a specific preference
	$score *= 0.0003;
    }

    my @group_players = split(/;/, GroupForPlayer($pid));
    my $group_size = $#group_players + 1;
    my $g_defenders = 0;
    my $g_goalies = 0;
    my $g_forwards = 0;
    my %g_level = ();
    for ($i = 0; $i <= 5; $i++) {
	$g_level{$i} = 0;
    }
    foreach $gpid (@group_players) {
	$g_defenders += Defender($gpid);
	$g_goalies += Goalie($gpid);
	$g_forwards += Forward($gpid);
	my $s = CorrectedSkill($gpid);
	$g_level{$s}++;
    }

    if (IsAMTeam($team) && ($time_pref eq "No")) {
	$score *= 0.001;
    }

    my $team_ones = TeamPlayersAtLevel($team, 1);
    my $team_twos = TeamPlayersAtLevel($team, 2);
    my $team_threes = TeamPlayersAtLevel($team, 3);
    my $team_fours = TeamPlayersAtLevel($team, 4);
    my $team_fives = TeamPlayersAtLevel($team, 5);
    if ($g_level{1} > 0) {
	$score *= 0.001 ** $team_ones;
    } elsif ($g_level{2} > 0) {
	$score *= 0.1 ** $team_twos;
    } elsif ($g_level{3} > 0) {
	my $expected_threes = $players_at_level{3} / $num_teams;
	if ($team_threes + $g_level{3} > $expected_threes + 2) {
	    $score *= 0.5;
	} elsif ($team_threes + $g_level{3} > $expected_threes + 1) {
	    $score *= 0.8;
	} elsif ($team_threes + $g_level{3} < $expected_threes - 1) {
	    $score *= 1.5;
	} elsif ($team_threes + $g_level{3} < $expected_threes - 2) {
	    $score *= 2;
	}
    } elsif ($g_level{4} > 0) {
	my $expected_fours = $players_at_level{4} / $num_teams;
	my $expected_ones_and_twos = ($players_at_level{1} + $players_at_level{2}) / $num_teams;
	if (($team_fours + $g_level{4}) >= ($expected_fours + 2)) {
 	    $score *= 0.01;
	} elsif ((($team_fours + $g_level{4}) < ($expected_fours - 2)) || 
		 (($team_ones + $team_twos > $expected_ones_and_twos))) {
	    $score *= 5;
	} elsif (($team_fours + $g_level{4} < ($expected_fours - 1))) {
	    $score *= 2;
	}
    } elsif ($g_level{5} > 0) {
	my $expected_fives = $players_at_level{5} / $num_teams;
	my $expected_ones = $players_at_level{1} / $num_teams;
	if ($team_fives + $g_level{5} >= $expected_fives + 2) {
	    $score *= 0.01;
	} elsif (($team_fives + $g_level{5} < ($expected_fives - 2)) || (($team_ones + $g_level{1} > $expected_ones))) {
	    $score *= 5;
	}
    }
	
#    print "Skill Team $team : $g_level{1} $g_level{2} $g_level{3} $g_level{4} $team_ones $team_twos : $score\n";
	
    # Prevent teams from having more than their fair share of strong players
    $score = $score / (1 + $team_strength{$team});

    # Try to balance team sizes
    my $N = $player_count{$team};
    my $new_N = $N + $group_size;
    my $avg_N_per_team = $total_players_placed / $num_teams;
    my $pre_score = $score;
    my $mult = 1.0;
    if ($avg_N_per_team < $players_per_team / 2) {
	# Team size is not a factor initially: team balance is more important
	$mult = 1.0;
    } elsif ($new_N > $players_per_team) {
	$mult = 0.0000001;   # Very bad
    } elsif ($new_N > $avg_N_per_team) {
	# Exponentiation weights the score more strongly the farther behind this team is
	# in players compared with the average
	$mult = 0.1 ** int($new_N - $avg_N_per_team);
    } elsif ($new_N < ($avg_N_per_team - 1)) {
	$mult = (2 ** int($avg_N_per_team - 1 - $new_N));
    } elsif (($N + $group_size) == $players_per_team) {
	$mult = 2;   # Bonus for perfectly filling a team
    }
    $score *= $mult;
#    printf "Size %3d Team $team : %2d + %d = %2d %6.4f %6.4f %6.4f avg: %4.1f\n", $total_players_placed, $N, $group_size, $new_N, $pre_score, $mult, $score, $avg_N_per_team;

    if ($g_defenders > 0) {
	# Try to balance the defenders
	my $avg_defenders = AverageNumDefendersOnTeams();
	if ($defenders{$team} <= $avg_defenders - 2) {
	    $score *= 10;
	} elsif ($defenders{$team} <= $avg_defenders - 1) {
	    $score *= 5;
	} elsif ($defenders{$team} <= $avg_defenders - 0.5) {
	    $score *= 2;
	} elsif ($defenders{$team} > $avg_defenders + 1) {
	    $score /= 2;
	}
    }

    if ($g_forwards > 0) {
	# Try to balance the forwards
	my $avg_forwards = AverageNumForwardsOnTeams();
	if ($forwards{$team} <= $avg_forwards - 2) {
	    $score *= 10;
	} elsif ($forwards{$team} <= $avg_forwards - 1) {
	    $score *= 5;
	} elsif ($forwards{$team} > $avg_forwards + 1) {
	    $score /= 2;
	}
    }

    if ($g_goalies >= 1 && $goalies{$team} > 0) {
	# Spread out the full-time goalies
	$score *= 0.00001;
    }
    # Part time or full time goalies
    my $avg_goalies = AverageGoaliesPerTeam();
    if ($g_goalies > 0) {
	if ($goalies{$team} < $avg_goalies - 1) {
	    $score *= 2;
	} elsif ($goalies{$team} > $avg_goalies || $goalies{$team} >= 1.0) {
	    $score *= 0.1;
	}
    }
    

    # Adjust for age
    my $avg_age = AverageAgeOnTeams();
    my $team_avg_age = AverageAgeOnTeam($team);
    my $age = Age($pid);
    if ($avg_age > 0 && $team_avg_age > 0) {
	if ($age < $avg_age && ($team_avg_age < $avg_age - 2)) {
	    # Young team and a young player: slight aversion
	    $score /= (1.2 + 0.1 * ($avg_age - $age));  # Smaller score for wider age gap
	} elsif ($age < $avg_age && ($team_avg_age > $avg_age + 2)) {
	    # Old team and a young player: slight preference
	    $score *= (1.2 + 0.1 * ($avg_age - $age)); # Larger score for wider age gap
	}
    }
    
    my $coord = Coordinator($pid);
    if ($coordinators{$team} == 0.0 && $coord > 0) {
	# Team has no coordinators yet, and this person is willing.
	# Give a slight preference to this team
	$score *= 1.1;
    } elsif ($coord == 1.0 && $coordinators{$team} >= 1.0) {
	# Try to save 'Yes' coordinators for teams that don't have them
	$score *= 0.9;
    }
    
    # TODO: if afternoon team and morning player or vice versa, multiply by 0.001
    return $score;
}

sub AssignPlayerToTeam {
    my $pid = shift;
    my $candidate_team = -1;
    my $best_score = -100000;
    my $num_at_best = 0;
    if (defined($pid_to_team{$pid})) { 
	# Already placed on a team
	return;
    }

    srand($pid+1);

#    printf "Placing %s : %s %s\n", Name($pid), Goalie($pid), Position($pid); 
    for (my $team = 1; $team <= $num_teams; $team++) {
	my $score = ScoreForTeam($team, $pid);
#	printf "  Score for $team ; %f (best=%f)\n", $score, $best_score;
	if ($score > $best_score) {
	    $best_score = $score;
	    $candidate_team = $team;
	    $num_at_best = 1;
	} elsif ($score == $best_score) {
	    $num_at_best++;
	    if (rand() < (1.0 / $num_at_best)) {
		$candidate_team = $team;
	    }
	}
    }

    AddPlayerToTeam($pid, $candidate_team);
    my @g = split(/;/, GroupForPlayer($pid));
#    printf "  %s : Group '%s', %s\n", Name($pid), GroupCode($pid), GroupForPlayer($pid);
    my $placed_from_group = 1;
    for (my $i = 0; $i <= $#g; $i++) {
	my $group_member_pid = $g[$i];
#	printf "  Group player : %s %s\n", Name($group_member_pid), GroupCode($group_member_pid);
	if (defined($pid_to_team{$group_member_pid})) {
	    if ($group_member_pid ne $pid) {
		printf "Weird: Player %s in group %s already placed on team\n", Name($group_member_pid), GroupCode($pid);
	    }
	} elsif (!defined($eligible{$group_member_pid})) {
	    printf "Not placing group player %s on team : not eligible for placement\n", Name($group_member_pid);
	} elsif ($placed_from_group < $max_group_size) {
	    # Also place this player in the group on the team
	    AddPlayerToTeam($group_member_pid, $candidate_team);
	    $placed_from_group++;
	}
    }
}

sub AddPlayerToTeam {
    my $pid = shift;
    my $team = shift;
    $pid_to_team{$pid} = $team;
    $teams{$team} = AddToList($teams{$team}, $pid);

    UpdateStatsForTeam($pid, $team, +1);
}

sub RemovePlayerFromTeam {
    my $pid = shift;
    my $team = shift;
    $pid_to_team{$pid} = undef;
    $teams{$team} = RemoveFromList($teams{$team}, $pid);
    UpdateStatsForTeam($pid, $team, -1);
}

sub UpdateStatsForTeam {
    my $pid = shift;
    my $team = shift;
    my $delta = shift;

    $total_players_placed += $delta;
    $player_count{$team} += $delta;
    $goalies{$team} += Goalie($pid) * $delta;
    $defenders{$team} += Defender($pid) * $delta;
    $forwards{$team} += Forward($pid) * $delta;
    $coordinators{$team} += Coordinator($pid) * $delta;
    $total_age{$team} += Age($pid) * $delta;
    $total_games{$team} += GamesPlayed($pid) * $delta;
    my $cs = CorrectedSkill($pid);
    $team_strength{$team} += $skill_weights[$cs] * $delta;
    $team_players_at_level{"$team;$cs"} = TeamPlayersAtLevel($team, $cs) + $delta;
}

sub GetEligiblePlayers {
    my @eligible = ();
    if ($pa_residents_have_priority) {
	my $pa_players = 0;
	for (my $pid = 0; $pid < $num_players; $pid++) {
	    if (IsPaloAltoResident($pid)) {
		push(@eligible, $pid);
		$pa_players++;
	    }
	}
	# Second pass to find matching number of non-PA players (in registration order)
	my $non_pa_players = 0;
	for (my $pid = 0; $pid < $num_players; $pid++) {
	    if (IsPaloAltoResident($pid)) {
		next;
	    }
	    if ($pa_percent_reqd > 0) {#Avoid divide by zero
	    	if ($non_pa_players < ((100*$pa_players)/$pa_percent_reqd) - $pa_players) {
			push(@eligible, $pid);
			$non_pa_players++;
	    	} else {
			printf "Skipping non-PA player: %d %d : %s %s\n", $pa_players, $non_pa_players, Name($pid), City($pid);
	    	}
	    }
	    else {
		#PA residency is 0 percent
		printf "PA residency is set to ZERO; please change it to 1 at the least.\n";
	    }
	}
    } else {
	my $players_to_place = $num_players;
	if ($num_teams * $players_per_team < $players_to_place) {
	    $players_to_place = $num_teams * $players_per_team;
	}
	for (my $pid = 0; $pid < $players_to_place; $pid++) {
	    push(@eligible, $pid);
	}
    }
    @eligible = sort {
	# Sort Palo Alto residents first, followed by non-PA, and within each group, by registration date
	if ($pa_residents_have_priority) {
	    my $is_pa_a = IsPaloAltoResident($a);
	    my $is_pa_b = IsPaloAltoResident($b);
	    if ($is_pa_a && !$is_pa_b) {
		return -1;
	    } elsif (!$is_pa_a && $is_pa_b) {
		return 1;
	    }
	}
	my $date_a = RegistrationPriority($a);
	my $date_b = RegistrationPriority($b);
	return $date_a cmp $date_b;
    } @eligible;

    return @eligible;
}

sub PrintPlayer {
    my $pid = shift;
    PrintPlayerToFile(STDOUT, $pid);
}

sub PrintPlayerToFile {
    my $file = shift;
    my $pid = shift;
    my $cs = SkillFromRatingsFile($pid);
    printf $file "%-25s %2d %s %s S: %d CS: %s %s %s %2s %2d %-10s %s %s %s\n", Name($pid), Age($pid), IsPaloAltoResident($pid) ? "PA" : "  ", Division($pid), ReportedSkill($pid), (defined($cs) ? $cs : "-"), CoordString($pid), PosCode($pid), GoalieString($pid), ExpectedGames($pid), GroupCode($pid), TimePrefForPlayer($pid), Email($pid), RatingsInfo($pid);
}

sub PlacementOrderForPlayer {
    my $pid = shift;
    my $cs  = CorrectedSkill($pid);
    my $goalie = Goalie($pid);
    if ($goalie > 0) {
	return 0;    # Goalies first
    } elsif ($cs <= 1) {
	return 1;    # Top rated players next
    } elsif ($cs >= 5) {
	return 2;    # Weakest players next
    } else {
	return 2 + $cs;  # Rest of players in decreasing skills order
    }
}

sub GetPlayersByPlacementOrder {
    my $num_desired = shift;
    my @elist = GetEligiblePlayers();
    my @player_list = ();
    for (my $i = 0; $i <= $#elist; $i++) {
	my $pid = $elist[$i];
	printf "Eligible #%3d %d  %s : ", $i, $pid, Name($pid);
	PrintPlayer($pid);
	if (defined($players{$pid}) && (!defined($pid_to_team{$pid}))) {
	    push(@player_list, $pid);
	    $eligible{$pid} = 1;
	}
    }
    printf "Eligible players %d\n", $#player_list+1;
    
    @player_list = sort({ 
	my $o_a = PlacementOrderForPlayer($a);
	my $o_b = PlacementOrderForPlayer($b);
	if ($o_a != $o_b) {
	    return $o_a <=> $o_b;
	} else {
	    # Break ties by larger groups first
	    my $gsize_a = GroupSizeForPlayer($a);
	    my $gsize_b = GroupSizeForPlayer($b);
	    if ($gsize_a > $gsize_b) {
		return -1;
	    } elsif ($gsize_a < $gsize_b) {
		return 1;
	    } else {
		return 0;
	    }
	}
    } @player_list);
    for ($i = 0; $i <= $#player_list; $i++) {
	my $pid = $player_list[$i];
	printf "Eligible Player %d : %s ", $pid, Name($pid);
	PrintPlayer($pid);
    }
    return @player_list;
}

sub RewriteLine {
    my $s = shift;
    my @c = split(//, $s);
    my $in_quote = 0;
    for ($i = 0; $i <= $#c; $i++) {
	my $ch = $c[$i];
	if ($ch eq "\"") {
	    $in_quote = $in_quote ? 0 : 1;
	} elsif ($ch eq "," && !$in_quote) {
	    $c[$i] = "\t";
	}
    }
    return join('', @c);
}

sub PrintTimePrefs {
    my %time_prefs = ();
    my $pa_players = 0;
    my $non_pa_players = 0;
    for (my $pid = 0; $pid < $num_players; $pid++) {
	$time_prefs{TimePref($pid)}++;
	if (IsPaloAltoResident($pid)) {
	    $pa_players++;
	} else {
	    $non_pa_players++;
	}
    }
    foreach $k (keys %time_prefs) {
	printf "%s players : %d; ", $k, $time_prefs{$k};
    }
    print "; PA players: $pa_players; Non-PA: $non_pa_players\n";
}

sub RewriteDumpFile {
    my $fname = shift;
    my $out_name = shift;
    open(IN, $fname) || die("Unable to open input file $fname");
    open(OUT, ">$out_name") || die("Unable to open temporary file $out_name\n");
    while (<IN>) {
	next if (m,<table, || m,</table,);
	s,\r,,g;
	s,\n,,g;
	s,\t,,g;
	if (m|<td>.*,.*</td>|) {
	    s|<td>|<td>"|;
	    s|</td>|"</td>|;
	}
	
	s/<tr>//g;
	s|</tr>|\n|g;
	s/^\s*<td>//g;
	s|</td>|,|g;
	s/<td>//g;
	print OUT $_;
    }
    close(IN);
    close(OUT);
}


sub ReadPlayers {
    my $fname = shift;
    my $tmp_name = $fname . ".converted_to_csv";
    if ($fname =~ m/.*csv/i){
	printf "THIS IS A CSV file\n";
	$tmp_name = $fname;
	#open(F, $fname);
    }else{
	#Jigz: Sometimes we use CSV or XLS (HTTP table formatted)
    	RewriteDumpFile($fname, $tmp_name);
    }
    open(F, $tmp_name);
    
    my $headings_line = <F>;
    chop($headings_line);
    $original_headers = $headings_line;
    @headings = split(/\t/, RewriteLine($headings_line));
    # Initialize the fields map
    
    for (my $i = 0; $i <= $#headings; $i++) {
	$fields{Trim($headings[$i])} = $i;
	printf "%3d : %-20s\n", $i, Trim($headings[$i]);
    }
    printf "Headings: %d\n", $#headings + 1;
    
    my %name_to_pids = ();
    my $pid = 0;
    while (<F>) {
#	next if (!m/ACTIVE/);
	chop;
	my $p = $_;
	my @fields = split(/\t/, RewriteLine($_));
	if (m/OZER/) {
	    for ($i = 0; $i <= $#fields; $i++) {
		printf("%-20s : %s\n", $headings[$i], $fields[$i]);
	    }
	}
#	die if (#$fields != $#headings);
	$players{$pid} = RewriteLine($p);
	$original_players{$pid} = $p;

	my $name = Lower(Name($pid));
	my $reg_id = RegistrationId($pid);
	my $keep = 1;
	foreach $id_to_ignore (@registration_ids_to_ignore) {
	    if ($reg_id == $id_to_ignore) {
		print "Ignoring registration $reg_id for $name: in list of ids to ignore\n";
		$keep = 0;
	    }
	}

	if (!$keep) {
	    next;
	}

	my $group = GroupCode($pid);
	if ($group ne "") {
	    $groups{$group} = AddToList($groups{$group}, $pid);
	}
	# groupcode
	printf "%3d : %-20s age : %3d exp : %2d skill : %d cskill: %d timepref: %s\n", $pid, 
	Name($pid), Age($pid), Experience($pid), ReportedSkill($pid), CorrectedSkill($pid), TimePref($pid);
	my $k = Email($pid) . Name($pid);
	if (defined($name_to_team{$k})) {
	    my $team = $name_to_team{$k};
	    AddPlayerToTeam($pid, $team);
	    printf "  Preassigned %s to team %d\n", Name($pid), $team;
	}

	if (defined($name_to_pids{$name})) {
	    $name_to_pids{$name} .= ";$pid";
	    my @x = split(/;/, $name_to_pids{$name});
	    print "Possible duplicate registration for $name\n";
	    foreach $dup (@x) {
		printf "Duplicate  %-20s : registration id: %d\n", Name($dup), RegistrationId($dup);
	    }
	} else {
	    $name_to_pids{$name} = "$pid";
	}
	
	$pid++;
    }

    
    $num_players = $pid;
    printf "Headings: %d\n", $#headings + 1;
    printf "Read %d players\n", $num_players;
}

sub ReadRatings {
    my $fname = shift;
    open(F, $fname);
    printf "Reading ratings from $fname\n";
    my $headings_line = <F>;
    my @headings = split(/[\t,]/, $headings_line);
    my $first_col = undef;
    my $last_col = undef;
    my $email_col = undef;
    my $clvl_col = undef;
    my $comments_col = undef;
    for ($i = 0; $i <= $#headings; $i++) {
	my $c = $headings[$i];
	if ($c =~ m/First.*Name/i) {
	    $first_col = $i;
	} elsif ($c =~ m/Last.*Name/i) {
	    $last_col = $i;
	} elsif ($c =~ m/Email/i) {
	    $email_col = $i; 
	} elsif ($c =~ m/^CLV/i) {
	    $clvl_col = $i;
	} elsif ($c =~ m/comment/i) {
	    $comments_col = $i;
	}
       #printf "Read: $first_col\n";
    }
    if (!defined($first_col) ||
	!defined($last_col) ||
	!defined($email_col) ||
	!defined($clvl_col) ||
	!defined($comments_col)) {
	die "Did not find needed columns in ratings file\n";
	exit(0);
    }
    printf "Headings: %d\n", $#headings + 1;
    my $pid = 0;
    while (<F>) {
	my $p = $_;
#	printf "Ratings: $_\n";
	chop;
	my @fields = split(/[\t]/, RewriteLine($_));
	#if ($#fields <= $clvl_col) {
#	    print "Ignoring ratings line: $_\n";
	#    next;
	#}
	my $name = $fields[$first_col] . " " . $fields[$last_col];
	my $corrected_rating = $fields[$clvl_col];
	my $email = $fields[$email_col];
	my $comments = $fields[$comments_col];
	# Insert by name and by email address
	$ratings{$name} = $corrected_rating;
	$ratings_info{$name} = $comments;
	if (defined($email)) {
	    $ratings{$email} = $corrected_rating;
	    $ratings_info{$email} = $comments;
	}
	$pid++;
    }
    printf "Read %d player ratings\n", $pid;
}

sub ReadPartialTeamAssignments {
    my $fname = shift;
    open(INF, $fname);
    my $pid = 0;
    my $assigned = 0;
    while (<INF>) {
	my $p = $_;
	next if (!m/,/);
	chop;
	my @fields = split(/[\t]/, RewriteLine($_));
	my $team = $fields[0];
	my $email = $fields[1];
	my $name = $fields[2];
	my $is_coordinator = $fields[3];
	print "$team $email\n";
	# Insert by name and by email address
	if ($team > 0) {
	    $name_to_team{$email . $name} = $team;
	    $assigned++;
	}
	if (defined($is_coordinator) && $is_coordinator eq "COORD") {
	    my $k = $email . $name;
	    printf "Read coordinator selection of %s as coordinator for $team\n", $k;
	    $preset_coordinators{$email . $name} = 1;
	}
    }
    close(INF);
    printf "Pre-assigned %d players\n", $assigned;
}


sub Trim {
    my $s = shift;
    $s =~ s/\"//g;
    return $s;
}

sub Lower {
    my $s = shift;
    $r = $s;
    $r =~ tr/A-Z/a-z/;
    return $r;
}

sub min {
    my $a = shift;
    my $b = shift;
    return ($a < $b) ? $a : $b;
}
sub max {
    my $a = shift;
    my $b = shift;
    return ($a > $b) ? $a : $b;
}

sub F {
    my $pid = shift;
    my $field = shift;
    if (!defined($fields{$field})) { printf "%s not defined for $pid\n", $field; }
    my $field_index = $fields{$field};
    my @p = split(/\t/, $players{$pid});
    if (!defined($p[$field_index])) {
	if ($field =~ m/[Cc]omments/) {
	    return "";
	} else {
	    die  "Not defined: $field $field_index: $players{$pid}\n";
	}
    } else {
	return Trim($p[$field_index]);
    }
};

sub Name {
    my $pid = shift;
    return FirstName($pid) . " " . LastName($pid);
}
sub FirstName { return F(shift, "FirstName"); }
sub LastName { return F(shift, "LastName"); }
sub RegistrationId { return F(shift, "RegistrationID"); }

sub Age { return F(shift, "age"); }
sub Experience { return F(shift, "experience"); }
sub Email { return F(shift, "EMail"); }
sub GamesPlayed { return F(shift, "games"); }

%fixup_messages = ();

sub GroupCode {
    my $pid = shift; 
    my $g = Lower(F($pid, "groupcode")); 
    $g =~ s/ //g;  # Strip spaces
    my $name = Name($pid);
    my $email = Email($pid);
    if (defined($group_fixups{$g})) {
	$g = $group_fixups{$g};
    }
    my $msg = "";
    foreach $fix (keys %group_fixups) {
	if ($name =~ m/$fix/) {
	    $g = $group_fixups{$fix};
 	    $msg = "Fixed up group for $name ($email) to $g\n";
	} elsif ($email =~ m/$fix/) {
	    $g = $group_fixups{$fix};
 	    $msg = "Fixed up group for $name ($email) to $g\n";
	}
    }
    if ($msg ne "") {
	if (!defined($fixup_messages{$msg})) {
	    # Only print a fixup message once
	    print $msg;
	    $fixup_messages{$msg} = 1;
	}
    }
    return Lower($g);
}
sub RegistrationPriority { 
    my $reg_stamp = F(shift, "RegistrationStamp");
    if ($reg_stamp =~ m/(\d+-\d+-\d+ \d+:\d+):\d+.\d+/) {
	return "$1";
    } else {
	return $reg_stamp;
    }

#    if ($reg_stamp =~ m/(\d+):(.*)/) {
#	return $1 * 60 + $2;
#    } else {
#	die "Malformed registration stamp time: $reg_stamp\n";
#    }
}
sub ReportedSkill { 
    my $pid = shift;
    my $s = F($pid, "skill"); 
    if ($s =~ m/(\d+)/) { 
	return $1;
    } else {
	return $s;
    }
}
sub City { return F(shift, "City"); }
sub IsPaloAltoResident {
    my $c = Lower(City(shift));
    if ($c =~ m/(^palo alto|stanford)/i) {
	return 1;
    } else {
	return 0;
    }
}
sub Division {
  if (!defined($fields{"division"})) { return "E"; }
    my $d = F(shift, "division");
    if ($d =~ m/^[Aa]/) {
	return "A";
    } else {
	return "B";
    }
}

sub Quantity {
    my $pid = shift;
    my $field = shift;
    my $str = F($pid, $field);
    if ($str =~ m/(\d+)/) {
	return $1;
    } else {
	return 0;
    }
}

sub ShirtStringForCode {
    my $test = shift;
    my $c = "${test}";
    if ($c eq "0" || $c eq "") { return "None"; }
    elsif ($c eq "2" || $c eq "S") { return "Small"; }
    elsif ($c eq "3" || $c eq "M") { return "Medium"; }
    elsif ($c eq "4" || $c eq "L") { return "Large"; }
    elsif ($c eq "5" || $c eq "XL") { return "XL"; }
    elsif ($c eq "6" || $c eq "XXL") { return "XXL"; }
    else { return "Unknown_shirt_code"; }
}


sub ShirtString {
    my $pid = shift;
    #Jigz: Check if it is Shirt or ShirtSize (maybe A div has ShirtSize instead of Shirt)
    my $code = F($pid, "Shirt");
    #my $code = F($pid, "ShirtSize");
    return ShirtStringForCode($code);
}

sub PrintEquipmentOrder {
    my $file = shift;
    my %order = ();
    my @keys = ();
    
    for (my $c = 2; $c <= 6; $c++) {
	my $cs = ShirtStringForCode($c);
	$order{$cs} = 0;
	push(@keys, $cs);
    }
    $order{"socks"} = 0;
    push(@keys, "socks");
    for (my $team = 1; $team <= $num_teams; $team++) {
	my @p = PlayersOnTeam($team);
	foreach $pid (@p) {
	    my $shirt = ShirtString($pid);
	    if ($shirt ne "None") {
		$order{$shirt}++;
	    }
	    $order{"socks"} += Quantity($pid, "Socks");
	}
    }
    print $file "Equipment order\n";
    foreach $k (@keys) {
	printf $file "%-20s   : %3d\n", $k, $order{$k};
    }
}
	
sub SocksString {
    my $pid = shift;
    my $s = "";
    my $n = F($pid, "Socks");
    if ($n > 0) { $s .= sprintf("%d pair%s", $n, $n > 1 ? "s" : ""); }
    return $s;
}
	

# Returns 1.0 for fulltime goalies, 0.5 for part time, and 0.0 for non-goalies
sub Goalie { 
    my $pid = shift;
    my $g = F($pid, "goalie");
    if ($g =~ m/Full/ || (Position($pid) eq "Goalie")) { return 1.0; }
    if ($g =~ m/Part/) { return 0.5; }
    if ($g ne "Prefer Not") { print "Bad goalie value: '$g'\n"; }
    return 0.0;
}
sub Position { return F(shift, "position"); }

sub TimePrefForPlayer { 
    my $pid = shift;
    my $name = Name($pid);
    my $email = Email($pid);
    foreach $fix (keys %time_fixups) {
	if ($name =~ m/$fix/) {
	    return $time_fixups{$fix};
	} elsif ($email =~ m/$fix/) {
	    return $time_fixups{$fix};
	}
    }
    if (defined($fields{"TimePreference"})) {
	my $p = F($pid, "TimePreference"); 
	if ($p == 1) {
	    return "No";
	} elsif ($p == 2) {
	    return "AM";
	} elsif ($p == 3) {
	    return "PM";
	} elsif ($p == 0) {
	    return "Night";
	} else {
	    print STDERR "Unknown preference value: $p\n";
	    return "No";
	}
    } else {
	if (!defined($fields{"timepref"})) { return "No"; }
	my $p = F($pid, "timepref"); 
	if ($p =~ m/Morning/) { return "AM"; }
	if ($p =~ m/Afternoon/) { return "PM"; }
	return "No";
    }
}

sub TimePref {
    my $pid = shift;
    my @group_players = split(/;/, GroupForPlayer($pid));
    my %prefs = ();
    $prefs{"AM"} = 0;
    $prefs{"PM"} = 0;
    $prefs{"No"} = 0;
    foreach $gpid (@group_players) {
	$prefs{TimePrefForPlayer($gpid)}++;
    }

    my $am = $prefs{"AM"};
    my $pm = $prefs{"PM"};
    my $any = $prefs{"No"};
    
    if ($am > 0 && $pm > 0) {
	if ($am > $pm) {
	    return "AM";
	} elsif ($pm > $am) {
	    return "PM";
	} else {
	    return "No";
	}
    }
    if ($am > $any) {
	return "AM";
    } elsif ($pm > $any) {
	return "PM";
    } else {
	return "No";
    }
}

sub ExpectedGames { 
  return F(shift, "games"); 
}

sub Coordinator { 
    my $s = F(shift, "WillingCoordinator");
    if ($s == 3) { return 1.0; }
    if ($s == 2) { return 0.1; }
    return 0.0;
}

sub FindRatingsKey {
    my $pid = shift;
    my $email = Email($pid);
    if (defined($ratings{$email})) {
	return $email;
    }
    my $name = Name($pid);
    if (defined($ratings{$name})) {
	return $name;
    }
    return "";
}

sub RatingsInfo { 
    my $pid = shift;
    my $ratings_key = FindRatingsKey($pid);
    if ($ratings_key ne "" && defined($ratings_info{$ratings_key})) {
	return $ratings_info{$ratings_key};
    } else {
	return "";
    }
}

sub SkillFromRatingsFile {
    my $pid = shift;
    my $name = Name($pid);

    # Try by email address first
    my $email = Email($pid);
    my $result = undef;
    # Try e-mail first, since that's likely more unique
    if (defined($email) && defined($ratings{$email})) {
	if ($v >= 1) {
	    printf "Found adjusted skill by email %s for %s: %d -> %d\n",
	    $email, $name, $s, $ratings{$email};
	}
	$result = $ratings{$email};
    } elsif (defined($ratings{$name})) {
	# Try by name
	if ($v >= 1) {
	    printf "Found adjusted skill by name for %s: %d -> %d\n",
	    $name, $s, $ratings{$name};
	}

	$result = $ratings{$name};
    }
    if (defined($result) && !($result =~ m/^\d+$/)) {
	# Correct empty ratings or non-numeric ratings to undefined
	$result = undef;
    }
    return $result;
}

sub CorrectedSkill { 
    my $pid = shift;
    
    my $name = Name($pid);
    #Jigz Checking if age
    my $age = Age($pid);
    #print "NAME: $name  AGE: $age";
    my $s = ReportedSkill($pid);

    my $cs = SkillFromRatingsFile($pid);
    if (defined($cs)) {
	return $cs;
    }
    # Give up: return their reported skill, adjusted for division
    my $adjust = 0;
    if (Division($pid) eq "B") {
	$adjust = $skill_adjustment_for_b_players;
    }
    #Jigz: Check age of player; if < 35 then rating is min 3
    if ($age < 35){
    	if ($age < 30){
    		if (ReportedSkill($pid) > 2){
    			return 2;
    		}
    	}
    	if (ReportedSkill($pid) > 3) {
       		return 3;
		}
		return min(5, max(1, ReportedSkill($pid)+$adjust));
    }
    return min(5, max(1, ReportedSkill($pid) + $adjust));
}

sub PrintTeamInfo {
    my $file = shift;
    my $team = shift;
    
    my @p = PlayersOnTeam($team);
    my %levels = ();
    for ($sk = 1; $sk <= 5; $sk++) {
	$levels{$sk} = 0;
    }
    my $under_30 = 0;
    my $under_35 = 0;
    my $under_45 = 0;
    my $under_55 = 0;
    my $over_55 = 0;
    my $over_65 = 0;
    my $a_div = 0;
    my $b_div = 0;
    my $forwards = 0;
    my $games = 0;
    my $lvl_sum = 0;
    
    for (my $i = 0; $i <= $#p; $i++) {
	 my $pid = $p[$i];
	 my $sk = CorrectedSkill($pid);
	 if ($sk < 1) { $sk = 1; }
	 my $a = Age($pid);
	 if ($a < 30) { $under_30++; }
	 elsif ($a < 35) { $under_35++; }
         elsif ($a <45) {$under_45++; }
	 elsif ($a < 55) { $under_55++; }
	 elsif ($a >65) { $over_65++; }
	 elsif ($a > 55) { $over_55++; }
	 
	 $levels{int($sk)}++;
	 $lvl_sum += int($sk);
	 if (Lower(Division($pid)) eq "a") { $a_div++; }
	 if (Lower(Division($pid)) eq "b") { $b_div++; }
	 $forwards += Forward($pid);
	 $games += GamesPlayed($pid);
    }
    
    printf $file "Team %2d %-3s : %2d players; Lvl: %0.1f [", $team, TeamType($team), $#p+1, ($lvl_sum / ($#p + 1));
    
    for ($sk = 1; $sk <= 5; $sk++) {
	printf $file "%d%s", $levels{$sk}, ($sk != 5 ? " " : "");
    }
    printf $file "] Games: %4.1f Age: %4.1f <30: %d <35: %d <45: %d <55: %d >55: %d >65: %d Goalies:%3.1f  D:%d F:%d\n", (1.0 * $games) / $player_count{$team}, (1.0 * $total_age{$team}) / $player_count{$team}, $under_30, $under_35, $under_45, $under_55, $over_55, $over_65, $goalies{$team}, $defenders{$team}, $forwards;
}


sub CoordString {
    my $pid = shift;
    my $actual = defined($pid_to_coordinator{$pid}) ? "*" : " ";
    my $c = Coordinator($pid);
    if ($c == 0.0) {
	return " $actual";
    } elsif ($c == 1.0) {
	return "C$actual";
    } else {
	return "c$actual";
    }
}

sub GoalieString {
    my $pid = shift;
    my $g = Goalie($pid);
    if ($g == 0.0) {
	return "";
    } elsif ($g == 1.0) {
	return "FT";
    } else {
	return "pt";
    }
}

sub PrintTeamRoster {
    my $file = shift;
    my $team = shift;
    
    PrintTeamInfo($file, $team);
    my @p = PlayersOnTeam($team);
    @p = sort { 
      my $cs_a = CorrectedSkill($a);
      my $cs_b = CorrectedSkill($b);
      if ($cs_a != $cs_b) {
	  return $cs_a <=> $cs_b;
      } else {
	  return (Name($a) cmp Name($b));
      }
    } @p;
    for (my $i = 0; $i <= $#p; $i++) {
	my $pid = $p[$i];
	my $sk = CorrectedSkill($pid);
	PrintPlayerToFile($file, $pid);
    }
    print $file "\n";
}

sub CSVString {
    my $s = shift;
    if ($s =~ m/,/) {
	return "\"$s\"";
    } else {
	return $s;
    }
}


sub GenerateCSVForPlayer {
    my $pid = shift;
    my @fields = split(/;/, shift);
    my $newPlayerFile = shift;
    #print $newPlayerFile "Jigz File Handle: $newPlayerFile\n";
    for (my $j = 0; $j <= $#fields; $j++) {
	if ($j != 0) {
	    print OUTF ",";
	}

	my $s = "";
	
	if ($fields[$j] eq "team") {
	    if (defined($pid_to_team{$pid})) {
		$s = "$pid_to_team{$pid}";
	    } else {
		$s = "-1";
	    }
	} elsif ($fields[$j] eq "iscoord") {
	    $s = ($pid_to_coordinator{$pid} ? "C" : "");
	} elsif ($fields[$j] eq "goalie") {
	    $s = GoalieString($pid);
	} elsif ($fields[$j] eq "shirt") {
	    $s = ShirtString($pid);
     	    #Jigz: Printing to the NEWPlayerLists file
	    if ($s ne "None") {
		my $emailID = Email($pid);
		print $newPlayerFile "$emailID,";
	    }
	} elsif ($fields[$j] eq "socks") {
	    $s = SocksString($pid);
	} else {
	    $s = F($pid, $fields[$j]);
	}
	print OUTF CSVString($s);
    }
    print OUTF "\n";
}

sub PrintWaitingList {
    my $file = shift;
    my @plist = ();
    for (my $pid = 0; $pid < $num_players; $pid++) {
	if (!defined($pid_to_team{$pid})) {
	    push(@plist, $pid);
	}
    }
    @plist = sort { RegistrationPriority($a) cmp RegistrationPriority($b) } @plist;
    printf $file "Waiting list of %d players\n", $#plist+1;
    for (my $i = 0; $i <= $#plist; $i++) {
	my $pid = $plist[$i];
	printf $file "%2d : %-8s ", $i+1, RegistrationPriority($pid);
	PrintPlayerToFile($file, $pid);
#	printf $file "%2d : %-20s %-10s\n", $i+1, Name($pid), Email($pid);
    }
}

sub GenerateCSV {
    my $fname = shift;
    my $field_list = shift;
    $field_list =~ s/ALL/$original_headers/;
    my $header_list = shift;
    if ($header_list eq "") {
	$header_list = $field_list;
    }
    my $show_unassigned = shift;
    my @fields = split(/,/, $field_list);
    my @headers = split(/,/, $header_list);
    die if ($#fields != $#headers);
    open(OUTF, ">$fname");
    #Jigz: Generate a NEW PLAYERS list to send email for photo/pass creation
    #open(OUTFNEWPLAYERS, ">NewPlayers.csv");
    #print OUTFNEWPLAYERS "JigzTest ";
    print OUTF "$field_list\n";
    
    for (my $team = 1; $team <= $num_teams; $team++) {
	my @p = PlayersOnTeam($team);
	for (my $i = 0; $i <= $#p; $i++) {
	    my $pid = $p[$i];
	    #GenerateCSVForPlayer($pid, join(';', @fields));
	    GenerateCSVForPlayer($pid, join(';', @fields),OUTFNEWPLAYERS);
	}
    }
    if ($show_unassigned) {
	# Generate unassigned players list, in registration date order
	my @plist = ();
	for (my $pid = 0; $pid < $num_players; $pid++) {
	    if (!defined($pid_to_team{$pid})) {
		push(@plist, $pid);
	    }
	}
	@plist = sort { RegistrationPriority($a) cmp RegistrationPriority($b) } @plist;
	for (my $i = 0; $i <= $#plist; $i++) {
	    GenerateCSVForPlayer($plist[$i], join(';', @fields));
	}
    }
    #close(OUTFNEWPLAYERS);
    close(OUTF);
}

sub ChooseCoordinators {
    my $team = shift;
    my @p = PlayersOnTeam($team);
    my $coord_pid = -1;
    my $best_score = -1;
    my $num_at_best = 0;
    for (my $i = 0; $i <= $#p; $i++) {
	my $pid = $p[$i];
	if (defined($coordinators_to_avoid{Email($pid)})) {
	    if (0) { printf "Avoiding %s (%s) as coordinator\n", Name($pid), Email($pid); }
	    next;
	}
	
	if (Coordinator($pid) > $best_score) {
	    $best_score = Coordinator($pid);
	    $coord_pid = $pid;
	    $num_at_best = 1;
	} elsif (Coordinator($pid) == $best_score) {
	    $num_at_best++;
	    if (rand() < (1.0 / $num_at_best)) {
		$coord_pid = $pid;
	    }
	}
	if (defined($preset_coordinators{Email($pid) . Name($pid)})) {
	    printf "Pre-selected %s as coordinator for $team\n", Name($pid);
	    $best_score = 100;
	    $coord_pid = $pid;
	}
    }
    if ($coord_pid < 0) {
	print "Could not find a coordinator for team $team\n";
    } else {
	$chosen_coordinators{$team} = $coord_pid;
	$pid_to_coordinator{$coord_pid} = $team;
    }
}

sub SortTeamByCoordinatorAndName {
    my $team = shift;
    my @p = PlayersOnTeam($team);
    my @sorted_p = sort { 
	my $a_c = 1;
	if (defined($pid_to_coordinator{$a})) {
	    $a_c = 0;
	}
	my $b_c = 1;
	if (defined($pid_to_coordinator{$b})) {
	    $b_c = 0;
	}
	my $a_key = sprintf("%d %-30s %-30s", 
			    $a_c,
			    Lower(LastName($a)),
			    Lower(FirstName($a)));
	my $b_key = sprintf("%d %-30s %-30s", 
			    $b_c,
			    Lower(LastName($b)),
			    Lower(FirstName($b)));
	return $a_key cmp $b_key;
    } @p;
    return @sorted_p;
}

sub GenerateWebTeamList {
    my $fname = shift;
    my $max_size = 0;
    for (my $team = 1; $team <= $num_teams; $team++) {
	my @p = SortTeamByCoordinatorAndName($team);
	my $N = $#p+1;
	if ($N > $max_size) { $max_size = $N; }
    }

    my %cells = ();
    my $teams_per_row = 4;
    my $max_row = 0;
    my $max_col = 0;
    for (my $team = 1; $team <= $num_teams; $team++) {
	my $tnum = $team-1;
	my @p = SortTeamByCoordinatorAndName($team);
	my $row_base = int($tnum / $teams_per_row) * ($max_size + 3);
	my $col_base = ($tnum % $teams_per_row) * 3;
	$cells{"$row_base,$col_base"} = "Team";
	my $next_col = $col_base + 1;
	$cells{"$row_base,$next_col"} = "$team";
	for (my $i = 0; $i <= $#p; $i++) {
	    my $pid = $p[$i];
	    my $r = $row_base + 1 + $i;
	    my $c0 = $col_base;
	    my $c1 = $col_base+1;
	    $cells{"$r,$c0"} = FirstName($pid);
	    $cells{"$r,$c1"} = LastName($pid);
	    if ($c1 > $max_col) { $max_col = $c1; }
	    if ($r > $max_row) {$max_row = $r; }
	}
    }
    open(OUTF, ">$fname");
    for (my $r = 0; $r <= $max_row; $r++) {
	my $s = "";
	for (my $c = 0; $c <= $max_col; $c++) {
	    if ($c > 0) {
		$s = $s . ",";
	    }
	    if (defined($cells{"$r,$c"})) {
		$s = $s . $cells{"$r,$c"};
	    }
	}
	print OUTF "$s\n";
    }
    close(OUTF);
}

sub GenerateOutput {
    my $fname = shift;
    open(OUTF, ">$fname");
    for (my $team = 1; $team <= $num_teams; $team++) {
      for (my $pid = 0; $pid < $num_players; $pid++) {
  	  my $t;
  	  if (defined($pid_to_team{$pid})) {
	      $t = $pid_to_team{$pid};
	  } else {
	      $t = -1;
	  }
	  if ($t != $team) { next; }
	  printf OUTF "%d,%s,%s,%s\n", $t, Email($pid), Name($pid),
	  ($chosen_coordinators{$team} == $pid) ? "COORD" : "";

      }
    }
    for (my $pid = 0; $pid < $num_players; $pid++) {
	next if (defined($pid_to_team{$pid}));
	printf OUTF "%d,%s,%s,%s\n", -1, Email($pid), Name($pid), "";
    }
    
    close(OUTF);
    print "Generated output to $fname\n";
}
