# $Id$
# ===============================================================================
# The Base-Class 'WebEve'
# ===============================================================================

package WebEve::cBase;

use strict;
use Date::Calc qw( Today_and_Now );
use WebEve::Config;

sub getConfig
{
    my $self = shift;

    my $Param = shift;

    if( $Param eq 'BaseURL' )
    {
	return $BaseURL;
    }
    elsif( $Param eq 'BasePath' )
    {
	return $BasePath;
    }
    elsif( $Param eq 'TemplatePath' )
    {
	return $TemplatePath;
    }
    elsif( $Param eq 'LogFile' )
    {
	return $LogFile;
    }
    elsif( $Param eq 'LogPath' )
    {
	return $LogPath;
    }
    elsif( $Param eq 'DB' )
    {
	return \%DB;
    }
}

sub logger($)
{
    my $self = shift;
    my ($message) = @_;
    my $UserName = $self->{'UserName'} || $self->{'REMOTE_HOST'};

    open( LOG, ">>". $self->getConfig('LogFile') );

    printf( LOG "%4d-%02d-%02d %02d:%02d:%02d %s: %s\n", Today_and_Now(), $UserName, $message );

    close( LOG );
}

1;
