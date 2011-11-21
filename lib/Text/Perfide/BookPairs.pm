package Text::Perfide::BookPairs;

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Text::Perfide::WordBags;
use File::Path;
use File::Basename;
use utf8::all;

=head1 NAME

Text::Perfide::BookPairs - The great new Text::Perfide::BookPairs!

=head1 VERSION

Version 0.01_01

=cut

use base 'Exporter';
our @EXPORT = (qw/	calc_dupvers
					calc_bpairs
					calc_default 
					calcpair haspn 
					txt2bag2 rmbagfiles 
					calcbagfiles 
					bagfile 
					debug_pairs 
					print_dupvers 
					print_default 
					print_bpairs
									/);

our $VERSION = '0.01_01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Text::Perfide::BookPairs;

    my $foo = Text::Perfide::BookPairs->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS
=cut

# our($bpairs,$rv,$av,$warn,$debug,$v,$nr,$same,$dv,$recalc,$normbf);
# $nr 	//= 3;
# $rv		//= 0.2;
# $av 	//= 0.4;
# $dv		//= 0.9;

=head2 calc_dupvers

	Tries to find repeated versions in all the files passed as argument.
=cut

sub calc_dupvers {
    my ($files,$options) = @_;
    foreach my $file1 (@$files){
        my $bag1 = bagfile($file1,\&txt2bag2);
        my $list = {};
        foreach my $file2 (@$files){
            next if $file1 eq $file2;
			$list->{$file2} = calcpair($file1,$bag1,$file2);
        }
		print_dupvers($file1,$list,$options);
    }
}

=head2 print_dupvers
=cut

sub print_dupvers {
	my ($file1,$list,$options) = @_;
	my @cenas = (grep {$list->{$_}{value} >= $options->{dv}} keys %$list);
    my @tmp = sort {$list->{$b}{value} cmp $list->{$a}{value}}  @cenas;
    if (@tmp){
        print "$file1\n";
		my $nr = $options->{nr};
        $nr = $#tmp if $nr > $#tmp;
        foreach(@tmp[0..$nr]){
            print $list->{$_}{stats} if defined($options->{v});
            print "\t$_\n";
        }
        print "\n";
    }
}

=head2 calc_bpairs

	Pairs the first argument with the following arguments, and prints output compatible with Text::Perfide::BookSync

=cut

sub calc_bpairs {
	my ($files,$options) = @_;
	my $file1 = shift @$files;
	my $bag1 = bagfile($file1,\&txt2bag2);
	my $list = {};
	foreach my $file2 (@$files){
        next if $file1 eq $file2;
		$list->{$file2} = calcpair($file1,$bag1,$file2);
	}
	print_bpairs($file1,$list,$options);
}

=head2 print_bpairs
=cut

sub print_bpairs {
	my ($file1,$list,$options) = @_;
	my $f2 = (sort {$list->{$b}{value} cmp $list->{$a}{value}} keys %$list)[0];
	if($options->{warn}){
		if(defined($options->{v}) and ($list->{$f2}{value} <= $options->{av})){ print "# ",$list->{$f2}{stats},"\t";	}
		else{
			if ($list->{$f2}{value} <= $options->{rv})		{ print "# X\t"; }
			elsif ($list->{$f2}{value} <  $options->{av})	{ print "# ?\t"; }
		}
		print "$file1\t$f2\n";
	}
	else { print "$file1\t$f2\n" if $list->{$f2}{value} >= $options->{av}; }
}

=head2 calc_default

	Tries to pair the first argument with all the remaining arguments.

=cut

sub calc_default {
    my ($files,$options) = @_;
    my $file1 = shift @$files;
    my $bag1 = bagfile($file1,\&txt2bag2);
    my $list = {}; 
    foreach my $file2 (@$files){
        next if $file1 eq $file2;
		$list->{$file2} = calcpair($file1,$bag1,$file2);
    }   
	print_default($file1,$list,$options);
}

=head2 print_default
=cut

sub print_default {
	my ($file1,$list,$options) = @_;
	my $nr = $options->{nr};
    $nr = int(keys %$list) if $nr > keys %$list;
    print "$file1\n";
    foreach((sort {$list->{$b}{value} cmp $list->{$a}{value}} keys %$list)[0..$nr-1]){
        print $list->{$_}{stats},"\t";
        print "$_\n";
    }   
    print "\n";
}

=head2 calcpair
=cut

sub calcpair {
	my ($file1,$bag1,$file2,$options) = @_;
	return undef if $file1 eq $file2;

	my $bag2 = bagfile($file2,\&txt2bag2); 
	my $value = pairability($bag1,$bag2);
	my $stats = sprintf "(%0.3f) [%d,%d]",$value,bagcard($bag1),bagcard($bag2);
	debug_pairs($file1,$file2,$bag1,$bag2) if defined($options->{debug});
	return {value => $value, 
			stats => $stats,};
}

=head2 haspn 
=cut

sub haspn {
    my $bag = shift;
    my $have = 0;
    foreach(32..52){
        $have++ if defined($bag->{$_} and $bag->{$_}==1);
    }
    return 1 if $have > 10;
    return 0;
}


=head2 txt2bag2

	Given a text, creates a bag of words containing all the words starting with caps and which do not appear also starting with small caps.

=cut

sub txt2bag2{
	my $text = shift;
	my $uru = qr{[\x{0410}-\x{042F}]};
	#my $uru = qr{[АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ]};
	my $lru = qr{[\x{0430}-\x{044F}]};
	#my $lru = qr{[абвгдеёжзийклмнопрстуфхцчшщъыьэюя]};
	#my $ul = qr{[A-Z]|$uru};
	#my $ll = qr{[a-z]|$lru};
	my $w = qr{\w|$uru|$lru};

	my $upper = {};
	my $uppat = qr{\b[A-Z]\w{3,}(?:['-]\w+)*\b};
	#my $uppat = qr{\b$ul$w{3,}(?:['-]$w+)*\b};
	$upper->{$1}++ while($text =~ /($uppat)/g);

	my $lower = {};
	my $lwpat = qr{\b[a-z]+(?:['-][a-z]+)*\b};
	#my $lwpat = qr{\b$ll+(?:['-]$ll+)*\b};
	$lower->{$1}++ while($text =~ /($lwpat)/g);

	my $ruppat =  qr/$uru$lru+/;
	#my $ruppat =  qr/(?:^|\s)$uru$w{3,}(?:['-]$w+)*(?:\s|,|\.)/;
	$upper->{$1}++ while($text =~ /($ruppat)/g);
	
	my $rlwpat = qr/$lru+/;
	#my $rlwpat = qr{(?:^|\s)$lru+(?:['-]$lru+)*(?:\s|,|\.)};
	$lower->{$1}++ while($text =~ /($rlwpat)/g);
	
	foreach my $k (keys %$upper){
		if($lower->{lc $k}){
			my $ratio = $upper->{$k}/$lower->{lc $k};
			delete $upper->{$k} if $ratio < 10;
		}
	}
	return $upper;
}

# sub txt2bag{
# 	my $text = shift;
# 	my $bag = {};
# 	my $pecul = qr{\d+};
# 	$bag->{$1}++ while($text =~ /($pecul)/g);
# 	if(haspn($bag)){
# 		foreach(1..300){
# 			$bag->{$_}-- if $bag->{$_};
# 			delete $bag->{$_} unless $bag->{$_};
# 		}
# 	}
# 	return $bag;
# }

=head2 rmbagfiles
=cut

sub rmbagfiles {
	my $list = shift;
	#print STDERR "Removing '__bags' directories:\n";
	foreach my $path (@$list){
		$path = dirname($path) unless -d $path;
		$path.='/__bags' unless $path =~ /__bags$/;
		if ($path =~ m{__bags/?$}){
			#print STDERR "\t'$path'\n";
			rmtree($path);
		}
		else {
			print STDERR "Directory '$path' does not end with'__bags'. Won't remove.\n";
		}
	}
	print STDERR "\n";
}

=head2 calcbagfiles
	
	Given a list of files, calculates the bag files unless they already exist.

=cut

sub calcbagfiles {
	my ($list,$options) = @_;
	map { bagfile($_,\&txt2bag2,$options) } @$list;
}

=head2 bagfile

	Uses a given function to calculate the wordbag of a given file. Dumps the results to a folder '__bags' in the same folder where the file is located.

=cut

sub bagfile {
	my ($txtfile,$func,$options) = @_;
	my $dir = dirname($txtfile);
	my $base = basename($txtfile);
	mkdir "$dir/__bags" unless -e "$dir/__bags";
	return do "$dir/__bags/$base.bag" if (-e "$dir/__bags/$base.bag" and !defined($options->{recalc}));

	my $bag = file2bag($func,$txtfile);
	open my $bagfile,'>',"$dir/__bags/$base.bag";
	print $bagfile Dumper($bag);
	close $bagfile;
	return $bag;
}

=head2 debug_pairs
=cut

sub debug_pairs{
    my ($f1,$f2,$bag1,$bag2) = @_; 
    $f1 =~ s{^.*/}{};
    $f2 =~ s{^.*/}{};
    open DEBUG,'>',"$f1"."_$f2.debug_pair";
    print DEBUG Dumper(bagint($bag1,$bag2));
    close DEBUG;
    open DEBUG,'>',"$f1.debug";
    print DEBUG Dumper($bag1);
    close DEBUG;
    open DEBUG,'>',"$f2.debug";
    print DEBUG Dumper($bag2);
}


=head1 AUTHOR

Andre Santos, C<< <andrefs at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-text-perfide-bookpairs at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Text-Perfide-BookPairs>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Text::Perfide::BookPairs


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-Perfide-BookPairs>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Text-Perfide-BookPairs>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Text-Perfide-BookPairs>

=item * Search CPAN

L<http://search.cpan.org/dist/Text-Perfide-BookPairs/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Andre Santos.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Text::Perfide::BookPairs
