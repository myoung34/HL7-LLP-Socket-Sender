#######################################
# Perl LLP Sender
#  Marcus Young
#  open source, just leave my name here
#  don't be a dick
#######################################
#!/usr/bin/perl -w
use strict;
use File::Slurp;
use IO::Socket;
use Getopt::Long;

##### Get option flags
my($port,$path,$help,$host,$file);
GetOptions('host:s' => \$host, 'port:s' => \$port,'path:s' => \$path, 'file:s' => \$file,'h' => \$help,'help' =>\$help);


#####   VERBOSE HELP STUFF - CHECK VALIDITY OF ARGUMENTS AND DISPLAY APROPRIATE HELP #####
my $error_str = '';
if(defined($help)) {#user passed in -h flag
  $error_str .= "
Arguments:
   port - port of the receiver
   host - hostname or IP of the receiver
   path - path of the files to send
   h or help - Help. Display this.\n\n";
  displayHelp($error_str);
}

unless (defined $port) { #user didn't pass in a -port flag
  $error_str .= "-port:\tYou must supply a port\n";
} elsif($port !~ /\d+/) { #user passed in -port, but didn't give a valid string
  $error_str .= "-port:\tInvalid port\n";
}

unless (defined $host) { #user didn't give the host argument
  $error_str .= "-host:\tYou must give the host argument\n";
} elsif($host !~ /[a-zA-Z0-9\.]/) {
  $error_str .= "-host:\tThis isn't the format of an host\n";
}

#unless (defined $path && defined $file) { #user didn't pass in -data flag
if(not(defined $path) && not(defined $file)) {
  $error_str .= "-path|file:\tYou must supply a path to read files from or a file to read from\n";
}

displayHelp($error_str) if $error_str;#display help and quit if any conditions were met.

sub displayHelp {
  print "\nUsage: perl llp_sender.pl -port portnumber -host hostname -path /path/to/files\n".
        "                                                            -file /path/to/file.txt\n";
  if(defined($_[0])) {
    print $_[0];
  }
  exit(0);
}

###################################################################
#           START DOING ACTUAL STUFF                              #
###################################################################
my $socket;
reconnect();
start();

# THIS FUNCTION RECONNECTS THE SOCKET
sub reconnect {
  $socket = IO::Socket::INET->new(
    PeerAddr => "$host",
    PeerPort => "$port",
    Proto => "tcp"  
  ) or die "Can't bind : $@\n";
}

# THE ACTUAL RUN METHOD - SET UP RECONNECT FUNCTION ($SIG{'PIPE'}) AND SEND FILES
sub start {
  local $SIG{'PIPE'} = sub {
    print "Socket connection closed in start(), attemping to reconnect...\n";
    reconnect();  
  };
  if(defined $path) {
    my @files = <$path/*>;
    foreach $file (@files) {
      my $contents = read_file($file);
      send_file($file,$contents);
    }
  } elsif (defined $file) {
    chomp(my $contents = read_file "$file");
      send_file($file,$contents);
  }
}

# SEND THE DATA WRAPPED IN HEX AND DETERMINE THE ACK
sub send_file {
  print "Sending $_[0].....";
  $socket->send(chr(hex("0x0B")));
  $socket->send($_[1]);
  $socket->send(chr(hex("0x1C")));
  $socket->send(chr(hex("0x0D")));
  sleep(1);
  my $ack;
  $socket->recv($ack,1024);
  print "Message accepted\n" if($ack =~ /...AA/);
  print "Message rejected\n" if($ack =~ /...AR/);
  print "Message errored\n" if ($ack =~ /...AE/);
}
1;
