# -*- mode: Perl -*-
###############################################################################
#
#    genConfig::File module
#
#    Copyright (C) 2004 Mike Fisher
#    Copyright (C) 2005-2014 Francois Mikus
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###############################################################################

package genConfig::File;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(set_file_header subdir);

my ($gInstallRoot);
BEGIN {
    $gInstallRoot = (($0 =~ m:^(.*/):)[0] || "./") . "..";
}

use Common::Log;
use genConfig::Utils;

my $VERSION = '0.92';
my $header = '';

###############################################################################
# set_file_header - Used to set the header at the top of all opened files.
#                   Should probably only be called once from the main script
#                   with script name, arg, and date info. This is a class 
#                   method.  It can be called as either 'set_file_header' or 
#                   'genConfig::File->set_file_header'.
###############################################################################

sub set_file_header {
    shift if ($_[0] eq 'genConfig::File');
    $Header = $_[0];
}

###############################################################################
# new - Create a new file object.  If a filename is given, the file is opened.
#
################################################################################

sub new {
    my($class, $filename) = @_;

    my $self = {};
    bless $self;

    $self->open($filename) if ($filename);

    return $self;
}

###############################################################################
# open - Open the file given.  See 'new'.
###############################################################################

sub open {
    my($self, $filename) = @_;

    $self->{'file'} = $filename;

    open($self->{'file'}, ">$filename") || die "Can't open $filename";

    print({$self->{'file'}} $Header) if ($Header);
}

###############################################################################
# writepair - Write out a name/value pair for a target, quoting as needed.
###############################################################################

sub writepair {
    no strict 'refs';
    my($self, $name, $value, $comment) = @_;

    $comment = '' if (!defined $comment);

    my $quote = '';
    my $tabs = int(((32 - length($name))/8) + 0.5);

    if (defined($value)) {
        # quote empty (or white-space only) lines, or lines which
        # will have embedded spaces or dots.
        if ($value =~ /^\s*$/ || $value =~ /\s/ || $value =~ /\./) {
            # Escape existing quotes...
            $value =~ s/"/\\"/g;
	    # $quote = '"';
	    $quote = ''; # Unquoted for Nagios
        }
        print({$self->{'file'}} "$comment   $name", 
              "\t" . $tabs, "$quote$value$quote\n");
    }
}

###############################################################################
# writetarget - Write a target definition to the file.
#
################################################################################

sub writetarget {
    no strict 'refs';
    my($self, $name, $comment, %value) = @_;

    my $f = $self->{'file'};
    print $f "${comment}define $name\n";

    # Apply triggergroups based on dstemplate name or user input
    # applyMonitoringThresholds(\%value);
    my @keyorder = ('host_name', 'service_description', 'display_name');

    # Apply the mandatory configuration items in the correct order
    foreach my $k (@keyorder) {
        next unless exists($value{$k});
	$self->writepair($k, $value{$k}, $comment);
	if (($k eq 'service_description') && ($value{$k} ne 'chassis')) {
	    $self->writepair("service_dependencies", ",chassis", $comment);    
	}

	delete $value {$k};
    }

    # foreach my $key (sort keys %value) {
    foreach my $key (sort keys %value) {
        $self->writepair($key, $value{$key}, $comment);
    }
    # Add the global variable statement as these are not templates
    foreach my $key (keys %Common::global::service_vars) {
    	next unless exists($Common::global::service_vars{$key});
    	$self->writepair($key, $Common::global::service_vars{$key}, $comment);
    }
    # Add the register statement as these are not templates
    $self->writepair('register', 1, $comment);
    print $f "${comment}}\n";    
    print $f "\n";
}

###############################################################################
# write - Write the given string to the file.
###############################################################################

sub write {
    my($self, @data) = @_;

    print {$self->{'file'}} @data;
}

###############################################################################
# close - Close the file.
###############################################################################

sub close {
    my($self) = @_;

    close($self->{'file'});
}

###############################################################################
# subdir - Create a sub-directory. Convert the given name to lowercase if the
#          lc flag is set.  This is a class method.
###############################################################################

sub subdir {
    my($dir, $lc) = @_;

    $dir = lc($dir) if ($lc);

    if (! -d $dir) {
        mkdir($dir, 0755) || die "Can't mkdir $dir";
    }
    return($dir);
}

###############################################################################

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 4
# perl-indent-level: 4
# End:
