#!/usr/bin/perl
# Copyright (C) 2010 Joseph 'Bolts' Nosie
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


# METADATA
# Version: 0.0.1

# guzuta - A makepkg wrapper with AUR support

use strict;
use warnings;
use Bolts::Guzuta;

# Global declarations
our %repo;
our $tmpdir = '/tmp/guzuta';
my @pkgs;
my %mode;

# Default Values
our $editor = $ENV{EDITOR} ||
    $ENV{VISUAL} || (
    "/usr/bin/vi" &&
    warn "\$EDITOR and \$VISUAL are not set. Using `vi`\n"
);
my $uconf = 1;
our $pacmanbin = "/usr/bin/pacman";


# Parse global config
open CONF, "/etc/guzuta.conf" or
die "Failed to open global configuration file\n";
while(<CONF>) {
    next if /^\s*#/;
    if(/^RepoName=(.+?)(\s+#|$)/) {
        $repo{name} = $1;
        next;
    }
    if(/^RepoDir=(.+?)(\s+#|$)/) {
        $repo{dir} = $1;
        next;
    }
    if(/^BuildDir=(.+?)(\s+#|$)/) {
        $tmpdir = $1;
        next;
    }
    if(/^UserConfig=no/) {
        $uconf = 0;
        next;
    }
    if(/^PacmanBin=(.+?)(\s+#|$)/) {
        $pacmanbin = $1;
    }
}
close CONF;
if(!$repo{name} && !$repo{dir}) {
    die "RepoName and RepoDir must be set in /etc/guzuta.conf\n";
}


# Parse command line options
while($_ = shift) {
    if(/^-[^-]/) {
        $mode{S} = 1 if /S/;
        $mode{U} = 1 if /U/;
        $mode{u} = 1 if /u/;
        $mode{y} = 1 if /y/;
    }
    $mode{S} = 1 if /^--sync$/;
    $mode{u} = 1 if /^--update$/;
    push @pkgs, $_ if /^[^-]/;
}


# main()
if($mode{S}) {
    if($mode{u}) {
        @pkgs = aurcheck or
        print "Local repo is up to date with AUR\n";
    }
    exit 0 unless @pkgs;
    our $paclst = `$pacmanbin -Sqs`;
    # Match with $paclst =~ m/^<pattern>$/m
    my @deplist;
    foreach(@pkgs) { # Generate list of AUR dependencies
        getaurpkg $_;
        push @deplist, finddeps $_;
    }
#       Prepend each AUR dependency to the list of pkgs to add to the repo
#       then check its dependencies
    while($_ = pop @deplist) {
        unshift @pkgs, $_;
        getaurpkg $_;
        unshift @deplist, finddeps $_;
    } # TODO Remove duplicate entries from pkglist.
    foreach(@pkgs) {
        exttaurball $_;
        my $pkgf = makepkg $_ ||
        die "Build of $_ failed.\n";
        repoadd $pkgf ||
        die "Failed to add $_ to local repo `$repo{name}'\n";
        pacsy; # Update pacman repos for build dep resolution.
    }
    exit 0;
}

if($mode{U}) {
    my @upkgs;
    foreach(@pkgs) {
        mkdir $tmpdir;
        my $upkg = `/usr/bin/bsdtar -xOf $_ */PKGBUILD`;
        $upkg =~ /pkgname=(.+)\n/;
        $upkg = $1;
        push @upkgs, $upkg;
        system("cp $_ $tmpdir/$upkg.tar.gz");
    }
    foreach(@upkgs) {
        exttaurball $_;
        my $pkgf = makepkg $_;
        repoadd $pkgf;
    }
    pacsy if $mode{y};
    exit 0;
}
