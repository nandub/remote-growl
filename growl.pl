#!/usr/bin/env perl -w
#
# Copyright (C) 2009 Bruce Pennypacker
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  
# 02110-1301, USA.

#
# This is a simple irssi script to send out Growl notifications to a remote
# Mac using the scripts send-growl (client) and growl-server (server).
# Currently, it sends notifications when your name is highlighted, and
# when you receive private messages.
#

use strict;
use vars qw($VERSION %IRSSI $Notes $AppName);
use IO::Socket;
use Digest::MD5 qw(md5_base64);
use Crypt::CBCeasy;
use MIME::Base64;
use Cwd;

use Irssi;

my %option;
my %watching;

##############################################################################
# Edit the following as necessary

$option{appname} = "Remote Irssi";
$option{host} = "wildfire.usg.tufts.edu";
$option{port} = "7106";
$option{passphrase} = "cpe1704tks";
$option{image} = "microphone";
$option{blowfish_key} = "6wlKT.6vghHZsUPap0R2PjpsCPynIFSw^6lsfrY8xK5O4.5O5uISz";

##############################################################################
# Do not edit anything below here unless you know what you're doing

my $type_growl_message = "Message";
my $type_growl_notification = "Notification";

my $growl_types = join(',', ($type_growl_message, $type_growl_notification));

$VERSION = '0.01';
%IRSSI = (
	authors		=>	'Bruce Pennypacker',
	contact		=>	'bruce@pennypacker.org',
	name		=>	'growl',
	description	=>	'Sends remote Growl notifications for Irssi',
	license		=>	'GPL',
	url		=>	'http://growl.info/',
);

#############################################################################

sub cmd_growl ($$$) {

  my ($data, $server, $witem) = @_;

  unless ($data) {
    Irssi::print('%G>>%n Growl can be configured using the following settings:');
    Irssi::print('%G>>%n growl_show_privmsg : Notify about private messages.');
    Irssi::print('%G>>%n growl_show_hilight : Notify when your name is hilighted.');
    Irssi::print('%G>>%n growl_show_notify : Notify when someone on your away list joins or leaves.');  
    Irssi::print('%G>>%n growl_sticky : Make Growl pop-ups sticky so they don\'t disappear until clicked on.');  
    Irssi::print('%G>>%n Growl can also be used to notify you when user-specified');  
    Irssi::print('%G>>%n words or phrases are encountered.  To do this:');  
    Irssi::print('%G>>%n :  /growl (watch|unwatch) string');
    Irssi::print('%G>>%n :  /growl list');
    Irssi::print('%G>>%n :  The setting growl_watch can be used to enable/disable this feature.');

    return;
  }

  my ($cmd, $param) = split(/ +/, $data, 2);

  if ($cmd eq "watch") {
    unless (length($param)) {
      Irssi::print('%G>>%n : missing parameter from watch command.');
      return;
    }
    if ($param =~ m/,/) {
      Irssi::print('%G>>%n : Error - growl watch strings may not include commas');
      return;
    }
    $watching{$param} = $param; 
    Irssi::print('%G>>%n : Growl now watching for ' . $param);
    Irssi::settings_set_str('growl_watching', join(',', sort keys(%watching)));
  } elsif ($cmd eq "unwatch") {
    unless (length($param)) {
      Irssi::print('%G>>%n : missing parameter from unwatch command.');
      return;
    }
    delete ($watching{$param});
    Irssi::print('%G>>%n : Growl no longer watching for ' . $param);
    Irssi::settings_set_str('growl_watching', join(',', sort keys(%watching)));
  } elsif ($cmd eq "list") {
    Irssi::print('%G>>%n : Growl currently watching for the following:');
    for my $key (sort keys %watching) {
      Irssi::print('%G>>%n : "' . $key . '"');
    }
  } else {
    Irssi::print('%G>>%n : Syntax: /growl (watch|unwatch) value');
    Irssi::print('%G>>%n :         /growl list');
  }
  
}

#############################################################################

sub send_growl ($$$) {
  my ($header, $msg, $type) = @_;

  my $sock = new IO::Socket::INET (
                      PeerAddr => $option{host},
                      PeerPort => $option{port},
                      Proto => 'tcp',
                      );   

  unless ($sock) {
    Irssi::print('%G>>%n '.$IRSSI{name}.' : Unable to connect to ' . $option{host});
    return;
  }

  # Figure out if this is a sticky message or regular notification
  my $cmd = (Irssi::settings_get_bool('growl_sticky')) ? "sticky" : "notify";
 
  # Pack up the payload we'll be sending
  my $data = $option{appname} . "|" . $growl_types . "|" . $type . "|" .
             $header . "|" . $msg . "|" . $cmd . "|" . $option{image} ;

  # Calculate a checksum & add it to what we're sending
  my $cksum = md5_base64($data, $option{passphrase});

  # Add it to the front - easier to process in the server that way
  $data = "$cksum|$data";

  # Encrypt if necessary
  if (defined($option{blowfish_key})) {
    $data = Blowfish::encipher($option{blowfish_key}, $data);
    $data = encode_base64($data);
    $data =~ s/\n//g;
  }

  print $sock "$data\n";

  close ($sock);
}

#############################################################################

sub signal_message_private ($$$$) {
  return unless Irssi::settings_get_bool('growl_show_privmsg');

  my ($server, $data, $nick, $address) = @_;

  send_growl($nick, $data, $type_growl_message);
}

#############################################################################

sub signal_print_text ($$$) {

  my ($dest, $text, $stripped) = @_;

  if ($dest->{level} & MSGLEVEL_HILIGHT) {
    return unless Irssi::settings_get_bool('growl_show_hilight');
    send_growl($dest->{target}, $stripped, $type_growl_message);
    return;
  }

  return unless Irssi::settings_get_bool('growl_watch');
  return unless ($dest->{level} & MSGLEVEL_PUBLIC);
  my $search_text = $stripped;
  $search_text =~ s/^<[^>]+>\s*//;
  for my $key (keys %watching) {
    if ($search_text =~ m/$key/i) {
      send_growl($dest->{target}, $stripped, $type_growl_message);
      return;
    }
  }
}

#############################################################################

sub signal_notify_joined ($$$$$$) {
  return unless Irssi::settings_get_bool('growl_show_notify');
  my ($server, $nick, $user, $host, $realname, $away) = @_;
   
  my $msg = "<$nick!$user\@$host>\nHas joined $server->{chatnet}";
  my $header = $realname || $nick;

  send_growl($header, $msg, $type_growl_notification);
}

#############################################################################

sub signal_notify_left ($$$$$$) {
  return unless Irssi::settings_get_bool('growl_show_notify');
  my ($server, $nick, $user, $host, $realname, $away) = @_;
	
  my $msg = "<$nick!$user\@$host>\nHas left $server->{chatnet}";
  my $header = $realname || $nick;
	
  send_growl($header, $msg, $type_growl_notification);
}


#############################################################################
# Main program (initialization)

  unless (defined($option{host})) {
    Irssi::print('%G>>%n '.$IRSSI{name}.': host not defined.');
  }

  unless (defined($option{port})) {
    Irssi::print('%G>>%n '.$IRSSI{name}.': port not defined.');
  }

  unless (defined($option{passphrase})) {
    Irssi::print('%G>>%n '.$IRSSI{name}.': passphrase not defined.');
  }

  if (defined($option{blowfish_key})) {
    Irssi::print('%G>>%n '.$IRSSI{name}.': set to send notifications to ' . $option{host} . ':' . $option{port} . ' using Blowfish encryption.');
  } else {
    Irssi::print('%G>>%n '.$IRSSI{name}.': set to send unencrypted notifications to ' . $option{host} . ':' . $option{port});
  }

  Irssi::command_bind('growl', 'cmd_growl');

  Irssi::signal_add_last('notifylist joined', \&signal_notify_joined);
  Irssi::signal_add_last('notifylist left', \&signal_notify_left);
  Irssi::signal_add_last('message private', \&signal_message_private);
  Irssi::signal_add_last('print text', \&signal_print_text);

  Irssi::settings_add_bool($IRSSI{'name'}, 'growl_show_notify', 1);
  Irssi::settings_add_bool($IRSSI{'name'}, 'growl_show_privmsg', 1);
  Irssi::settings_add_bool($IRSSI{'name'}, 'growl_show_hilight', 1);
  Irssi::settings_add_bool($IRSSI{'name'}, 'growl_watch', 1);
  Irssi::settings_add_bool($IRSSI{'name'}, 'growl_sticky', 0);
  Irssi::settings_add_str($IRSSI{'name'}, 'growl_watching', "");

  %watching = map { $_ => $_ } split(',', Irssi::settings_get_str('growl_watching')); 

  Irssi::print('%G>>%n '.$IRSSI{name}.' '.$VERSION.' loaded (/growl for help)');
