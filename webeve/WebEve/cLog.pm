package WebEve::cLog;

use strict;
use FileHandle;
use Date::Calc qw( Today_and_Now );

# --------------------------------------------------------------------------------
# The Constructor
# --------------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $LogFile = shift;
    die "Constructor has to be used as instance method!" if ref($class);

    my $self = {};

    bless( $self, $class );

    $self->{LogFileHandle} = new FileHandle ">>$LogFile";
    die("Could not open Logfile <$LogFile>") unless defined( $self->{LogFileHandle} );

    return $self;
}

#-----------------------------------------------------------------------

sub logger {
    my $self = shift;
    my ($message) = @_;

    my $fh = $self->{LogFileHandle};
    my $UserName = $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'};

    printf( $fh "%4d-%02d-%02d %02d:%02d:%02d %s: %s\n",
	    Today_and_Now(), $UserName, $message );
}

#-----------------------------------------------------------------------

sub DESTROY {
    my $self = shift;
    $self->{LogFileHandle}->close if defined( $self->{LogFileHandle} );
}

1;
