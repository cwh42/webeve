# ===============================================================================
# The Class 'cDate'
# ===============================================================================

package WebEve::cDate;

use strict;
use Date::Calc qw( check_date
		   Moving_Window
		   Delta_Days
		   Day_of_Week
		   Days_in_Month
		   Day_of_Week_to_Text
		   This_Year
		   Today
		   Language
		   Month_to_Text );

# --------------------------------------------------------------------------------
# The Constructor
# --------------------------------------------------------------------------------

sub new
{
    my $class = shift;

    die "Constructor has to be used as instance method!" if ref($class);

    my $self = {};

    bless( $self, $class );

    # Initialize variables
    $self->_init(@_);

    return $self;
}

sub newSQL
{
    my $class = shift;

    return  $class->new( join('-', reverse( split(/-/, $_[0]) )) );
}

# --------------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------------

sub _init
{
    my $self = shift;
    
    if( @_ == 1)
    {
	$self->{isValid} = $self->_ParseDate(@_);
    }
    elsif( @_ == 2)
    {
	$self->{isFullDate} = 0;

	$self->{Month} = $_[1];
	$self->{Year} = $_[0];

	$self->{isValid} = $self->_checkDate();	
    }
    elsif( @_ == 3)
    {
	$self->{isFullDate} = 1;

	$self->{Day} = $_[2];
	$self->{Month} = $_[1];
	$self->{Year} = $_[0];

	$self->{isValid} = $self->_checkDate();
    }
    else
    {
	$self->{isValid} = 0;
    }
}

# --------------------------------------------------------------------------------

sub _checkDate
{
    my $self = shift;

    if( $self->{isFullDate} )
    {
	return check_date( $self->{Year},
			   $self->{Month},
			   $self->{Day} );
    }
    else
    {
	return ( $self->{Month} >= 1 && $self->{Month} <= 12 );
    }
}

# --------------------------------------------------------------------------------

sub _ParseDate
{
    my $self = shift;
    my ($DateStr) = @_;

    my $Day = 0;
    my $Month = 0;
    my $Year = 0;

    $DateStr =~ s/^\s+//g; 
    $DateStr =~ s/\s+$//g; 

    if( $DateStr =~ /^(\d+)$/ )
    {
	$Day = 0;
	$Month = $DateStr;
	$Year = This_Year();

	return 0 if( $Month < 1 || $Month > 12 );

	$Year++ while( Delta_Days(Today(), $Year, $Month, Days_in_Month($Year, $Month)) < 0 );
    }
    elsif( $DateStr =~ /^(\d+)\D(\d+)$/ )
    {
	$Day = 0;
	( $Month, $Year ) = split(/\D/, $DateStr);
	$Year = Moving_Window($Year);

	return 0 if( $Month < 1 && $Month > 12 );
    }
    elsif( $DateStr =~ /^(\d+)\D(\d+)\D(\d*)$/ )
    {
	$Day = $1;
	$Month = $2;
	$Year = $3 || This_Year();
	$Year = Moving_Window($Year);
	
	if( $Month == 2 && $Day == 29 && ! $3 )
	{
	    $Year++ until( check_date( $Year, $Month, $Day ) );
	}
	elsif( ! $3 )
	{
	    return 0 unless check_date( $Year, $Month, $Day );
	    $Year++ while( Delta_Days(Today(), $Year, $Month, $Day) < 0 );
	}
	else
	{
	    return 0 unless check_date( $Year, $Month, $Day );
	}
    }
    else
    {
	return 0;
    }

    if( $Day != 0)
    {
	$self->{Day} = $Day;
	$self->{Month} = $Month;
	$self->{Year} = $Year;

	$self->{isFullDate} = 1;
    }
    else
    {
	$self->{Month} = $Month;
	$self->{Year} = $Year;

	$self->{isFullDate} = 0;
    }

    return 1;
}

# --------------------------------------------------------------------------------
# Public Methods
# --------------------------------------------------------------------------------
# Checking Methods
# --------------------------------------------------------------------------------

sub isOver
{
    my $self = shift;

    return undef unless $self->{isValid};

    my $tmp;

    unless( $self->{isFullDate} )
    {
	$tmp = Days_in_Month( $self->{'Year'}, $self->{'Month'} );
    }
    else
    {
	$tmp = $self->{'Day'};
    }
    
    return ( Delta_Days( Today(), $self->{'Year'}, $self->{'Month'}, $tmp ) < 0 )
}

# --------------------------------------------------------------------------------

sub isToday
{
    my $self = shift;

    return 0 unless $self->{isFullDate};
    return undef unless $self->{isValid};
    
    return ( Delta_Days( Today(), $self->{'Year'}, $self->{'Month'}, $self->{'Day'} ) == 0 )
}

# --------------------------------------------------------------------------------

sub isNextWeek
{
    my $self = shift;

    return 0 unless $self->{isFullDate};
    return undef unless $self->{isValid};

    $self->getDate() unless( exists( $self->{'Day'} ) );
    $self->getDate() unless( exists( $self->{'Month'} ) );
    $self->getDate() unless( exists( $self->{'Year'} ) );

    return ( Delta_Days( Today(), $self->{'Year'}, $self->{'Month'}, $self->{'Day'} ) <= 7 )
}

# --------------------------------------------------------------------------------

sub isValid
{
    my $self = shift;
    return $self->{isValid};
}

# --------------------------------------------------------------------------------
# Getting data
# --------------------------------------------------------------------------------

sub getDay
{
    my $self = shift;

    return 0 unless $self->{isFullDate};
    return undef unless $self->{isValid};
    return $self->{'Day'};
}

# --------------------------------------------------------------------------------

sub getMonth
{
    my $self = shift;

    return undef unless $self->{isValid};
    return $self->{'Month'};
}

# --------------------------------------------------------------------------------

sub getYear
{
    my $self = shift;

    return undef unless $self->{isValid};
    return $self->{'Year'};
}

# --------------------------------------------------------------------------------

sub getDate
{
    my $self = shift;

    return undef unless $self->{isValid};
    if( $self->{isFullDate} )
    {
	return $self->{Year}, $self->{Month}, $self->{Day};
    }
    else
    {
	return $self->{Year}, $self->{Month};
    }
}

# --------------------------------------------------------------------------------

sub getDateStr
{
    my $self = shift;

    return undef unless $self->{isValid};

    Language(3);

    if( $self->{isFullDate} )
    {
	return sprintf( "%.2s, %02d.%.02d.%d",
			Day_of_Week_to_Text( Day_of_Week($self->{Year},
							 $self->{Month},
							 $self->{Day}) ),
			$self->{Day},
			$self->{Month},
			$self->{Year} );
    }
    else
    {
	return Month_to_Text( $self->{Month} )." ".$self->{Year};
    }
}

# --------------------------------------------------------------------------------

1;
