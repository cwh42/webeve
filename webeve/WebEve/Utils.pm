package WebEve::Utils;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;

$VERSION = "0.1";
@ISA     = qw(Exporter);
@EXPORT  = qw(trim array_diff);
@EXPORT_OK = qw();

#---------------------------------------
# sub trim
#---------------------------------------
# Cut leading and trailing whitespce off a string
#---------------------------------------
sub trim
{
    my ($string) = @_;

    $string =~ s/^\s+//s;
    $string =~ s/\s+$//s;

    return $string;
}

#---------------------------------------
# sub array_diff($$)
# --------------------------------------
# compares 2 arrays and reports the differences
# expects 2 array-references as parameters for array A and array B
# If the optional 3rd parameter is TRUE the arrays are sorted as strings
# returns 2 array-references:
#    the first contains all elements only found in A
#    the second contains all elements only found in B
#---------------------------------------

sub array_diff
{
    my ($Aref, $Bref, $String) = @_;

    my @A;
    my @B;

    if($String)
    {
	# sort arrays as strings
	@A = sort { $a cmp $b } @$Aref;
	@B = sort { $a cmp $b } @$Bref;
    }
    else
    {
	# sort both arrays numeric ascending
	@A = sort { $a <=> $b } @$Aref;
	@B = sort { $a <=> $b } @$Bref;
    }

    my $ai = 0;
    my $bi = 0;

    my @Aonly;
    my @Bonly;

    while(defined($A[$ai]) || defined($B[$bi]))
    {
	if(!defined($A[$ai]))	# A has less elements than B
	{
	    push(@Bonly, $B[$bi]);
	    $bi++;
	}
	elsif(!defined($B[$bi])) # B has less elements than A
	{
	    push(@Aonly, $A[$ai]);
	    $ai++;
	}
	else
	{
	    if($String)
	    {
		if(($A[$ai] cmp $B[$bi]) == -1)
		{
		    push(@Aonly, $A[$ai]);
		    $ai++;
		}
		elsif(($A[$ai] cmp $B[$bi]) == +1)
		{
		    push(@Bonly, $B[$bi]);
		    $bi++;
		}
		else
		{
		    $ai++;
		    $bi++;
		}
	    }
	    else
	    {
		if($A[$ai] < $B[$bi])
		{
		    push(@Aonly, $A[$ai]);
		    $ai++;
		}
		elsif($A[$ai] > $B[$bi])
		{
		    push(@Bonly, $B[$bi]);
		    $bi++;
		}
		else
		{
		    $ai++;
		    $bi++;
		}
	    }
	}
    }

    return \@Aonly, \@Bonly;
}

1;
