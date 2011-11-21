#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Text::Perfide::BookPairs' ) || print "Bail out!\n";
}

diag( "Testing Text::Perfide::BookPairs $Text::Perfide::BookPairs::VERSION, Perl $], $^X" );
