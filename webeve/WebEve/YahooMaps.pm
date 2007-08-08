package WebEve::YahooMaps;

require 5.005_62;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our $VERSION = '0.2';

use URI::Escape;

sub stringtolink {

    my ($country, $language, $string, $swap) = @_;

    $string =~ m@^([^\;\n]+)[\;\n]+([^\;\n]+)@s;
    my ($street, $city) = ($1, $2);

    if ($swap) {
	($street, $city) = ($city, $street);
    }

    my %addr = (
		"street" => $street,
		"city" => $city,
		"country" => $country,
		"language" => $language,
		);
        
    my $url = hashreftolink(\%addr);

    return $url;
}

sub hashreftolink {

    my ($rh_addr) = @_;

    #test if the language we want exists, whether we have given at least a country and a city
    if (&testlang($rh_addr->{language}) && 
        &testcountry($rh_addr->{country}) &&
        &cleanstring($rh_addr->{city})) {

        $rh_addr->{language} = &ukcheck($rh_addr->{language});
        $rh_addr->{country} = &ukcheck($rh_addr->{country});

	#special treatment for canada and US
	if ($rh_addr->{country} eq "ca") {
	    $rh_addr->{language} = "ca";
	} elsif ($rh_addr->{country} eq "us") {
	    $rh_addr->{language} = "us";
	}

	#take care of US dot-related issues
	my $langdot = '';

	if ($rh_addr->{language} eq "us") {
	    $rh_addr->{language} = "";
	} else {
	    $langdot = '.';
	}

        my $url = "";
        $url  = "http://" . $rh_addr->{language} . $langdot . "maps.yahoo.com";

	$url .= "/py";

	if ($rh_addr->{country} ne "ca") {
	    $url .= "/lg:" . $rh_addr->{language};
	    $url .= "/lc:" . $rh_addr->{language};
	}

	$url .= "/maps.py?BFCat=&Pyt=Tmap&newFL=";    

        # street
        if ($rh_addr->{street}){
	    my $street = cleanstring($rh_addr->{street});
	    $street = uri_escape($street);  
	    $url .= "&addr=" . $street;
        }

        # city
        my $city = cleanstring($rh_addr->{city});
        $city = uri_escape($city);  
        $url .= "&csz=" . $city;

        # country
        $url .= "&country=" . $rh_addr->{country}; 
                                         
	return $url;

    } else {
	return 0;
    }

}

sub ukcheck {
    # needed because "uk" is not a ISO 3166 code
    # "gb" is the code, but Yahoo! uses uk
 
    my ($string) = @_;
    if ($string eq "gb"){
        return "uk";
    } else {
        return $string;
    }
}

sub testlang {

    my ($lang)  = @_;

    if ($lang){ 
	# list of languages in which Yahoo offers maps
	my %langs = (
		     "de" => 1,
		     "es" => 1,
		     "fr" => 1,
		     "gb" => 1,
		     "it" => 1,
		     "uk" => 1,
		     "us" => 1,
		     ); 
	return $langs{$lang} ? 1 : 0 ;
    } else {
        return 0;
    }
}

sub testcountry {

    my ($cty)  = @_;

    if ($cty){ 
	# list of countries for which Yahoo has maps
	my %ctys = (
		    "at" => 1,
		    "be" => 1,
		    "ca" => 1,
		    "ch" => 1,
		    "de" => 1,
		    "es" => 1,
		    "fr" => 1,
		    "gb" => 1,
		    "it" => 1,
		    "lu" => 1,
		    "nl" => 1,
		    "pt" => 1,
		    "uk" => 1,
		    "us" => 1,
		    ); 
	return $ctys{$cty} ? 1 : 0 ;
    } else {
        return 0;
    }
}

sub cleanstring {
    #remove unecessary whitespace
    my ($string) = @_;
    $string =~ s@\n@ @g;   
    $string =~ s@^\s+@@g;      
    $string =~ s@\s+$@@g;      
    return $string;
}



1;

__END__

#documentation starts here - README

=head1 NAME

WebEve::YahooMaps - Create links to Yahoo! Maps

=head1 SYNOPSIS

 use WebEve::YahooMaps;

 #first method: PASSING ADDRESS BIT-BY-BIT
 my %addr = (
  "street" => "Rämistrasse 5",
  "city" => "8006 Zuerich",
  "country" => "ch",
  "language" => "de",
 );

 if (my $url = WWW:YahooMaps::hashreftolink(\%addr)){
      print "url1 $url\n";
 }

 #second method: ADDRESS INFO IN STRING
 #separators can be ";" or newline "\n"
 #street should come before city
 #pass an additional 1 at the end if you want to pass city first
 if (my $url = WebEve::YahooMaps::stringtolink("us","us","101 Morris Street; Sebastopol, CA 95472")){
      print "url2 $url\n";
 }


 if (my $url = WebEve::YahooMaps::stringtolink("fr","fr","75017 Paris; 11 bis, rue Torricelli", 1)){
      print "url3 $url\n";
 }

Code above will print:

url1 http://de.maps.yahoo.com/py/lg:de/lc:de/maps.py?BFCat=&Pyt=Tmap&newFL=&addr=R%E4mistrasse%205&csz=8006%20Zuerich&country=ch

url2 http://maps.yahoo.com/py/lg:/lc:/maps.py?BFCat=&Pyt=Tmap&newFL=&addr=101%20Morris%20Street&csz=Sebastopol,%20CA%2095472&country=us

url3 http://fr.maps.yahoo.com/py/lg:fr/lc:fr/maps.py?BFCat=&Pyt=Tmap&newFL=&addr=11%20bis,%20rue%20Torricelli&csz=75017%20Paris&country=fr



=head1 DESCRIPTION

=head2 Methods

=head3 hashreftolink()

Pass a reference to a hash to hashreftolink() and get a link to the corresponding Yahoo! map.

The keys of the hash are I<street> (optional), I<city>, I<country> and I<language>. The values of the keys country and language must be valid ISO 3166 two letter codes, and can be tested by the functions B<testcountry()> and B<testlanguage()> respectively.

The key, value pair I<street> is optional, however adding it leads to a much more accurate map.

The value of city can be either a postal code or a city name, however adding both produces much more accurate map links. If a city name is ambiguous, for example there are multiple cities with that name, the link will lead to a page with links to the various cities of that name.

=head3 stringtolink()

Or, if you have a ready-made string with the adress info, pass it to stringtolink().

The parameters are I<country>, I<language>, I<string> and I<swap>. In string, street and city should be separated by a semicolon ";" or a newline "\n". Since street is optional, you can also pass "; Paris" or "\n Zurich". Pass swap = 1 if you have a string where the city comes first, address second, e.g.: "New York, NY; Wall Street".

=head2 Countries

Yahoo offers maps for several countries - use the domain name (ISO 3166 2-letter code) for the {country} key. Currently available countries are: 

 - Austria (at)
 - Belgium (be)
 - Canada (ca) - only in combination with language = "us"
 - France (fr)
 - Germany (de)
 - Italy (it)
 - Luxembourg (lu)
 - Netherlands (nl)
 - Portugal (pt)
 - Spain (es)
 - Switzerland (ch)
 - U.S.A. (us) - only in combination with language = "us"
 - United Kingdom (gb/uk)

=head3 testcountry()

Use testcountry() to determine which countries are available, e.g.: testcountry("it") => returns 1, testcountry("tv") => returns 0.

=head2 Languages

Note that you can display maps for Germany in French, by passing "fr" as {language} and "de" as {country}.
Supported languages are (again, use ISO 3166 codes for language): 

 - American English (us) - only in combination with country = "us"
 - British English (uk)
 - French (fr) 
 - German (de)
 - Italian (it)
 - Spanish (es)

=head3 testlang()

Use testlang() to determine which languages are available, e.g.: testlang("es") => returns 1, testlang("dk") => returns 0.

The language also determines which Yahoo server is used - the servers for language="us" are in the US, while servers for all others are in Europe.

If Yahoo can't find the exact address you pass, it will show the user its best guess with some alternative links.

=head1 REQUIREMENTS

uses URI::Escape.

=head1 AUTHOR

Gabor Cselle, gaborcselle@yahoo.de

=head1 THANKS TO

Ed Freyfogle, who wrote the original version.

=head1 REVISIONS

0.1 : first version

0.2 : added Canada to countries, forces language="us" for US/CA, added docs for testcountry() and testlang()


=head1 SEE ALSO

Find lists of ISO 3166 country codes here:
http://dir.yahoo.com/Reference/Standards/International_and_Regional_Standards_Bodies/International_Organization_for_Standardization__ISO_/ISO_Country_Codes/

=cut
